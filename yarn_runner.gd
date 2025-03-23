## A node which executes a yarn dialogue and translates them into signals for UI elements to use.
##
## Uses the Dialogue class which, in turn, the virtual machine (the Dialogue class only adds a few
## program and node handling methods). So this class basically translates the VM's behaviour
## into signals useful for UI implementations.
@tool
extends Node


signal dialogue_started ## A signal emitted when a dialogue has started.
signal next_line_prepared(prepared_line: String) ## A signal emitted when a new line of displayed dialogue has been loaded and formatted.
signal command_triggered(command: String, arguments: Array[String]) ## A signal emitted when a yarn command (<<>>) has been triggered.
signal options_prepared(prepared_options: Array[String]) ## A signal emitted when a set of options (shortcut options / link to node) has been prepared for displaying.
signal dialogue_finished ## A signal emitted when a dialogue (and some clean-up procedures) has been finished.
signal advance_dialogue_triggered ## A signal emitted when [method advance_dialogue] has been called, regardless of whether the dialogue actually advances.
signal dialogue_advanced ## A signal emitted when [method advance_dialogue] has been called and the dialogue successfully advanced.
signal node_started(node_name: String) ## A signal emitted when preparations after the start of a new node have been finished.
signal node_complete(node_name: String) ## A signal emitted when clean-up procedures after the completion of a node have been finished.


const LineInfo = preload("res://addons/godyarnit/core/program/yarn_string_container.gd")
const DisplayedLine = preload("res://addons/godyarnit/core/dialogue/displayed_line.gd")
const YarnDialogue = preload("res://addons/godyarnit/core/dialogue.gd")
const ProgramUtils = preload("res://addons/godyarnit/core/program/program_utils.gd")
const YarnProgram = ProgramUtils.YarnProgram

@export var _start_node_title : String = "Start" ## Title of the node which should be executed first in the program.
@export var _should_auto_start : bool = false ## Value indicating whether the yarn dialogue should start immediately after the YarnRunner has entered the scene tree (end of [method _ready]).
@export var _variable_storage_path : NodePath ## Path to a YarnVariableStorage node used for storing various values during the execution of the dialogues.
@export var _function_library_storage_path: NodePath ## Path to a FunctionLibraryStorage node used for storing subclasses of the library class containing custom functions to use in the yarn dialogues.
@export var _compiled_yarn_program : CompiledYarnProgram: ## TODO FIXME: String is a path to a PNG(!?) file in the global filesystem.
	set = set_compiled_program
@export var locale_to_use: NumberPlurals.SupportedLocale = NumberPlurals.SupportedLocale.EN:
	get:
		return locale_to_use
	set(value):
		locale_to_use = value
		_current_locale_string = NumberPlurals.SupportedLocale.find_key(value)
@export var enable_logs: bool = false:
	get:
		return enable_logs
	set(value):
		enable_logs = value
		if _dialogue != null:
			_dialogue.enable_logs = enable_logs


# dialogue flow control
var next_line: String = "" # extra line will be empty when there is no next line
var is_waiting: bool = false
var wait_timer: Timer
var _string_table: Dictionary = {}  # localization support to come

# dialogue
var _dialogue: YarnDialogue
var _dialogue_has_started: bool = false
var _current_locale_string: String = "EN"


func _enter_tree() -> void:
	# initialise wait timer and add it to the scene tree
	wait_timer = Timer.new()
	wait_timer.one_shot = true
	wait_timer.autostart = false
	add_child(wait_timer)
	wait_timer.timeout.connect(Callable(self, "_on_wait_timeout"))


func _exit_tree() -> void:
	# destroy wait timer
	remove_child(wait_timer)
	wait_timer.queue_free()


func _ready():
	if Engine.is_editor_hint():
		# currently shown in the editor
		pass
	else:
		_dialogue = YarnDialogue.new(
			get_node(_variable_storage_path) as YarnVariableStorage,
			get_node(_function_library_storage_path) as FunctionLibraryStorage,
			enable_logs
		)
		_dialogue.get_vm().line_handler = Callable(self, "_handle_line")
		_dialogue.get_vm().options_handler = Callable(self, "_handle_options")
		_dialogue.get_vm().command_handler = Callable(self, "_handle_command")
		_dialogue.get_vm().node_complete_handler = Callable(self, "_handle_node_complete")
		_dialogue.get_vm().dialogue_complete_handler = Callable(self, "_handle_dialogue_complete")
		_dialogue.get_vm().node_start_handler = Callable(self, "_handle_node_start")
		
		# try to load the compiled program, if it already exists
		var program: YarnProgram = _compiled_yarn_program._load_compiled_program(_current_locale_string)
		
		if program == null:
			# compiled program doesn't exist yet -> compile it now
			program = _compile_programs(enable_logs, enable_logs) # default: only print tokens and tree when logs are also enabled
		
		if program:
			_string_table = program.yarn_strings
			_dialogue.set_program(program)

			if _should_auto_start:
				start(_start_node_title)


## Currently not in use.
func _process(delta: float) -> void:
	if !Engine.is_editor_hint():
		pass
		# var state = _dialogue.get_exec_state()

		# if (_dialogue_has_started &&
		# 	state!=YarnGlobals.ExecutionState.WaitingForOption &&
		# 	state!=YarnGlobals.ExecutionState.Suspended):
		# 	await _dialogue.resume()
		# else:
		# 	print(state)


## Makes an option selection and pass it to the dialogue
## if it is currently waiting for an option.
func choose(option_index: int) -> void:
	match _dialogue.get_exec_state():
		YarnGlobals.ExecutionState.WaitingForOption:
			_dialogue.set_selected_option(option_index)
		_:
			printerr("_dialogue was not currently waiting for option to be selected")


## Resumes the dialogue to the next line / option group / ...
func advance_dialogue() -> void:
	advance_dialogue_triggered.emit()
	if _dialogue_has_started and not is_waiting:
		if enable_logs: print("runner: advancing dialogue")
		await _dialogue.resume() # executes next instruction(s)
		dialogue_advanced.emit()


## Returns the YarnDialogue member of this class.
func get_dialogue() -> YarnDialogue:
	return _dialogue


## Checks whether the given resource is a CompiledYarnProgram
## and, if so, stores it in [member _compiled_yarn_program].
## Used as a setter for [member _compiled_yarn_program].
func set_compiled_program(compiled_program: CompiledYarnProgram) -> void:
	if compiled_program and not compiled_program.has_method("_load_compiled_program"):
		# wrong type of resource! -> dont load
		_compiled_yarn_program = null
	else:
		_compiled_yarn_program = (compiled_program as CompiledYarnProgram)
	
	if _compiled_yarn_program == null:
		printerr("compiled_program Resource must be of type CompiledYarnProgram!")


## Starts the yarn runner at the given node.
## Emits [signal dialogue_started] if not already running.
func start(start_node_title: String = _start_node_title) -> void:
	if _dialogue_has_started:
		return
	_dialogue_has_started = true
	dialogue_started.emit()
	_dialogue.set_node(start_node_title)


## Stops the yarn runner.
## Emits [signal dialogue_finished] if not already stopped.
func stop():
	if _dialogue_has_started:
		_dialogue_has_started = false
		_dialogue.stop()
		dialogue_finished.emit()


## Compiles the yarn programs stored in [member _compiled_yarn_program],
## saves them to the disk and returns the compiled program.
func _compile_programs(show_tokens: bool, print_tree: bool) -> YarnProgram:
	if _compiled_yarn_program == null:
		printerr("Unable to compile programs. Missing CompiledYarnProgram resource in YarnRunner.")
		return null
	var program: YarnProgram = _compiled_yarn_program._compile_programs(show_tokens, print_tree, enable_logs)
	
	if program != null:
		_compiled_yarn_program._save_compiled_program(program)
		print_rich("[color=green][b]Your Yarn program has been compiled and saved: %s[/b][/color]" % [_compiled_yarn_program.get_full_file_path()])
	
	return program


## Prepares a string to display from a DisplayedLine object.
## Applies formatting using its substitutions with [method String.format],
## bracket-style formatting as well as adjustments for locales.
## Emits [signal next_line_prepared] when done.
## Returns YarnGlobals.HandlerState.PauseExecution.
func _handle_line(line: DisplayedLine) -> int:
	var text: String = (_string_table.get(line.id) as LineInfo).text
	text = text.format(line.substitutions)
	
	if enable_logs: print("formatted line: %s" % text)

	next_line_prepared.emit(YarnGlobals.expand_format_functions(text, _current_locale_string, enable_logs))

	return YarnGlobals.HandlerState.PauseExecution


## Handles the given yarn command. May run asyncronously.
## Emits [signal command_triggered].
## Returns YarnGlobals.HandlerState.ContinueExecution
## TODO : add a way to add commands that suspend the run state.
func _handle_command(command) -> int:
	# type of command: command.gd
	if enable_logs: print("handling command: <%s>. args: %s" % [command.command_name, command.args])

	# If this command is the wait command, we have already verified that it
	# has a valid argument in the virtual machine, so all that's left do to is
	# to begin waiting only after the user has attempted to resume. We also emit
	# command once it is resumed in order to notify any other interfaces
	# that make use of the wait command
	if command.command_name == "wait":
		var time: float = command.args.back().as_number() #float(command.args[0])
		is_waiting = true
		command_triggered.emit(command.command_name, command.args)
		if wait_timer.paused or not wait_timer.is_stopped():
			wait_timer.stop()
		wait_timer.wait_time = time
		#await self.advance_dialogue_triggered
		wait_timer.start()
		if enable_logs: print("runner is waiting now...")
	else:
		command_triggered.emit(command.command_name, command.args)

	return YarnGlobals.HandlerState.ContinueExecution


## Prepares a list of strings to display as options
## from a list of dialogue option objects.
## Emits [signal options_prepared] when done.
func _handle_options(dialogue_option_set) -> void:
	# type of dialogue_option_set: dialogue_option_set.gd
	
	if enable_logs:
		# print all options
		print("handling %d options:" % dialogue_option_set.options.size())
		for option in dialogue_option_set.options:
			print(
				(
					"id[%s](%s) -> destination [%s]"
					% [option.id, (_string_table[option.displayed_line.id] as LineInfo).text, option.destination]
				)
			)

	# prepare the strings that are displayed as the options
	var line_options: Array[String] = []
	for option_index in range(dialogue_option_set.options.size()):
		line_options.append(
			YarnGlobals.expand_format_functions(
				_string_table[dialogue_option_set.options[option_index].displayed_line.id].text.format(
					dialogue_option_set.options[option_index].displayed_line.substitutions
				),
				_current_locale_string,
				enable_logs
			)
		)
	options_prepared.emit(line_options)
	
	#_dialogue.set_selected_option(0)
	# if display != null:
	# 	display.feed_options(line_options)


## Handles clean-ups when a dialogue has finished.
## Emits [signal dialogue_finished] when done.
func _handle_dialogue_complete() -> void:
	if enable_logs: print("dialogue finished")
	
	# if display != null:
	# 	display.dialogue_finished()
	
	_dialogue_has_started = false
	dialogue_finished.emit()


## Handles preparations when a dialogue is started.
## Emits [signal node_started] when done.
func _handle_node_start(node_name: String) -> void:
	if not _dialogue._visited_node_counts.has(node_name):
		_dialogue._visited_node_counts[node_name] = 1
	else:
		_dialogue._visited_node_counts[node_name] += 1

	node_started.emit(node_name)


## Handles clean-ups when a node has been completed.
## Emits [signal node_complete].
## Returns YarnGlobals.HandlerState.ContinueExecution.
func _handle_node_complete(node: String) -> int:
	node_complete.emit(node)

	return YarnGlobals.HandlerState.ContinueExecution


## Called by [member wait_timer]'s [signal wait_timer.timeout] signal
func _on_wait_timeout():
	if enable_logs: print("runner's wait ended.")
	is_waiting = false
	#await advance_dialogue() # dialogue has already resumed after _handle_command has finished, so the next line has already been prepared
