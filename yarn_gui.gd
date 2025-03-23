## A UI control for displaying yarn dialogues.
##
## Uses the signals of a YarnRunner to display yarn dialogues in the way they are meant
## to be used.
## This is the default yarn display implementation that comes bundled out of the box
## for GDYarn and GodYarnIt. You are able to create your own if you need to, but for
## general game development and prototyping purposes it should be enough.
## TODO: Add interpolation to different aspects of this ui
##        * when ui is shown
##        * when ui is hidden
##        * when options are shown
##        * when options are hidden
@icon("res://addons/godyarnit/assets/display.PNG")
class_name YarnDisplay
extends Control


signal text_changed ## A signal emitted every time the text of the GUI's text display changes, including when the portion of the visible part of the text changes.
signal line_started ## A signal emitted whenever a new line is starting to be displayed.
signal line_finished ## A signal emitted whenever a new line has finished displaying.
signal options_shown ## A signal emitted when options are being shown.
signal option_selected ## A signal emitted once an option has been selected.
signal gui_shown ## A signal emitted when `show_gui` has been called.
signal gui_hidden ## A signal emitted when `hide_gui` has been called.


@export var _yarn_runner_path : NodePath ## Path to the YarnRunner used to handle the execution of yarn files.
#	set = set_yarn_runner_path
@export var _text_display_path : NodePath ## Used for displaying dialogue text. Path to any node used for displaying text, especially RichTextLabel or Label. (More specifically: must point to a node that has a `set_text` method.)
#	set = set_text_display_path
@export var _name_plate_display_path : NodePath ## Used for displaying speakers' names. Path to any node used for displaying text. (More specifically: must point to a node that has a `set_text` method.)
#	set = set_name_plate_display_path
@export var _option_display_paths : Array[NodePath] ## Used for displaying shortcut options and options with displayed text. Paths to any nodes used for displaying text. (More specifically: must point to nodes that have a `set_text` method.) If using buttons, they are automatically assigned a Callable.
#	set = set_option_display_paths

@export var _text_speed : int = 1 ## Controls the rate at which the text is displayed.

@export var restart_dialogue_after_finished: bool = false


const YarnRunner = preload("res://addons/godyarnit/yarn_runner.gd")

const NAME_TAG_PATTERN: String = "^(?:.*(?=:))" ## regex pattern looking for any text followed by a colon (:) -> marks the name tag of the speaker
var name_plate_regex: RegEx

var config: Configuration = Configuration.new() ## Holds some variables that shouldn't be exposed to the outside.

var yarn_runner: YarnRunner ## The yarn runner that this GUI communicates with.
var text_display ## Any node that has a set_text method, especially RichTextBox and Label. Used for displaying dialogue text.
var name_plate_display ## Any node that has a set_text method. Used for displaying the speaker's name.
var option_displays: Array ## Array of any nodes that have a set_text method. Used for displaying shortcut options and dialog options with displayed text. If they're buttons, they're automatically bound to a Callable.

var next_line: String = "" ## holds the next line queued up to be displayed.

var line_has_finished: bool = true ## true if the current line has finished being displayed
var full_line_time: float = 1 ## Time it will take to display the current line as the given [member _text_speed].
var elapsed_line_time: float = 0 ## Time that this line has been displaying. Used for gradually displaying the text using visible_ratio of (RichText)Labels.
var should_update_total_line_time: bool = false ## If set to true, [member full_line_time] will be recalculated the next time [method _process] is called.
var last_visible_chars: int = 0 ## Number of characters that were visible the last time [method _process] was called.

var should_display_immediately: bool = true ## If set to true, the next line set by [method _on_next_line_prepared] will start displaying immediately without any further user action.

var is_showing_options: bool = false ## True if the GUI is currently showing shortcut options or a dialog option with text.
var dialogue_has_finished: bool = false ## True if the dialog has finished.


## Prepares the yarn runner, text display, name plate display and options display.
func _ready():
	name_plate_regex = RegEx.new()
	name_plate_regex.compile(NAME_TAG_PATTERN) # used to search for speaker's name tag

	# connect the yarn runner's signals to this GUI's methods
	if _yarn_runner_path:
		yarn_runner = get_node(_yarn_runner_path)
		if yarn_runner:
			yarn_runner.next_line_prepared.connect(Callable(self, "_on_next_line_prepared"))
			yarn_runner.node_started.connect(Callable(self, "_on_node_started"))
			yarn_runner.options_prepared.connect(Callable(self, "_on_options_prepared"))
			yarn_runner.dialogue_finished.connect(Callable(self, "_on_dialogue_finished"))
			yarn_runner.command_triggered.connect(Callable(self, "_on_command_triggered"))
		else:
			printerr("Yarn GUI: %s does not point to a yarn runner!" % _yarn_runner_path)
	else:
		printerr("_yarn_runner_path for the Yarn GUI hasn't been set. This means that yarn dialogues cannot be run.")

	# prepare the text UI for displaying the dialogue text
	if _text_display_path:
		text_display = get_node(_text_display_path)
		if text_display:
			if text_display is RichTextLabel:
				config.is_rich_text_label = true
			elif text_display is Label:
				pass
			elif not text_display.has_method("set_text"):
				printerr("_text_display_path for the Yarn GUI did not point to a node with a set_text method. No text will be displayed.")
				config.has_unknown_output_type = true
		else: # text == null
			printerr("Yarn GUI: %s does not point to a text display. No text will be displayed." % _text_display_path)
			config.has_unknown_output_type = true
	else:
		printerr("_text_display_path for the Yarn GUI hasn't been set. No text will be displayed.")
		config.has_unknown_output_type = true
	
	# prepare the text UI for displaying the speaker's name
	if _name_plate_display_path:
		name_plate_display = get_node(_name_plate_display_path)
		if name_plate_display != null:
			if !name_plate_display.has_method("set_text"):
				printerr("Yarn GUI's name plate couldn't be set: _name_plate_display_path must point to a node with a set_text method!")
				name_plate_display = null
		else:
			printerr("Yarn GUI: %s does not point to a text display. No name plates will be displayed." % _name_plate_display_path)
	else:
		printerr("_name_plate_display_path for the Yarn GUI hasn't been set. If the dialogues contain speakers' names, they won't be displayed.")
	
	# prepare the text UIs for displaying options
	if _option_display_paths.size() == 0:
		printerr("_option_display_paths for the Yarn GUI hasn't been populated. This will cause faulty behaviour if the dialogue uses any shortcut options or options with displayed text!")
	else:
		option_displays.clear()
		for option_display_path in _option_display_paths:
			option_displays.push_back(get_node(option_display_path))
			
			if option_displays.back():
				if not option_displays.back().has_method("set_text"):
					printerr("%s in the Yarn GUI's option path does not point to a node with a set_text method! This node will not be added to the options array.")
					option_displays.pop_back()
					continue
				
				if option_displays.back().has_signal("pressed"):
					option_displays.back().pressed.connect(Callable(self, "select_option").bindv([option_displays.size() - 1]))
			else:
				printerr("Yarn GUI: %s does not point to a text display. This option display will not be displayed." % option_display_path)
		
		print("Yarn GUI's options array has been populated with %d elements.\n
			Please ensure that there are no shortcut options with more branches than there
			are elements in the array as this would cause faulty behaviour!" % [option_displays.size()])

	hide_options()


## Displays the dialogue at the given text speed.
## TODO FIXME: there might be code order issues here (see second paragraph for more details).
func _process(delta: float) -> void:
	if yarn_runner.is_waiting:
		# don't change the text during waiting times!
		return
	
	# recalculate full_line_time if necessary (i.e. when a new line has been prepared)
	if should_update_total_line_time:
		full_line_time = float(text_display.get_total_character_count()) / float(_text_speed)
		elapsed_line_time = 0
		should_update_total_line_time = false

	# prepare next line if this one has been finished
	if not line_has_finished and not config.has_unknown_output_type:
		if _text_speed <= 0 or elapsed_line_time >= full_line_time:
			line_has_finished = true
			elapsed_line_time += full_line_time
			line_finished.emit()
			await yarn_runner.advance_dialogue() # TODO FIXME: i believe if _text_speed <= 0, all dialogue would be skipped because this would already load the next line without resetting elapsed_line_time or full_line_time (?)
				#							   imo there should either be a return after this line or this paragraph should come AFTER the paragraph for displaying lines

	# display text (either a fraction or full text)
	if not line_has_finished and full_line_time > 0 and _text_speed > 0:
		text_display.set_visible_ratio(elapsed_line_time / full_line_time)
		if last_visible_chars != text_display.visible_characters:
			text_changed.emit()
		last_visible_chars = text_display.visible_characters
	else:
		text_display.set_visible_ratio(1.0)

	elapsed_line_time += delta


## Shows the yarn GUI.
## Emits [signal gui_shown].
func show_gui():
	self.visible = true
	dialogue_has_finished = false
	line_has_finished = false
	gui_shown.emit()


## Hides the yarn GUI.
## Emits [signal gui_hidden].
## NOTE: Not calling this can break certain things if they
## 		 are dependent on the gui_hidden signal.
func hide_gui():
	self.visible = false
	gui_hidden.emit()


## Hides all UI elements in [member option_displays].
func hide_options():
	for option_display in option_displays:
		option_display.visible = false
	is_showing_options = false


## If the GUI is currently showing options,
## the option given by option_index is chosen.
## The next line will be displayed immediately.
## Emits [signal option_selected].
func select_option(option_index: int):
	if is_showing_options:
		yarn_runner.choose(option_index)
		hide_options()
		#clear_text()
		line_has_finished = true
		should_display_immediately = true
		await finish_line()
		option_selected.emit()


## If the current line hasn't been finished yet,
## calling this method will make it display in full.
## If the current line has already been finished,
## it will display the next non-empty line.
func finish_line():
	if is_showing_options:
		print("line cannot be finished: currently showing options.")
		return

	if dialogue_has_finished:
		if restart_dialogue_after_finished:
			yarn_runner.start()
		else:
			hide_gui()
			print("line cannot be finished: dialogue has already finished")
			return

	if line_has_finished:
		print("line has already finished displaying.")
		
		if next_line.is_empty():
			print("next line is empty or hasn't been prepared yet. skipping to next non-empty line.")
			should_display_immediately = true
			await yarn_runner.advance_dialogue()
		elif not next_line.is_empty():
			#print("displaying next line.")
			_display_next_line()
		
	else:
		print("finishing displaying next line.")
		line_has_finished = true
		elapsed_line_time += full_line_time
		await yarn_runner.advance_dialogue()


## Hides the name plate display and clears the
## text display. Note that this will leave [member elapsed_time]
## unaffected, so [method _process] will still
## display the next line after a while under normal
## circumstances.
func clear_text():
	# hide name plate display
	if name_plate_display != null:
		name_plate_display.visible = false
	
	# clear text display
	if text_display:
		if text_display is RichTextLabel:
			text_display.clear()
		else:
			text_display.set_text("")
		text_display.queue_redraw()


## Begins executing the current node.
## Called by [signal yarn_runner.node_started].
func _on_node_started(node_name: String):
	await yarn_runner.advance_dialogue()


## Sets [member dialogue_has_finished] to true.
## Called by [signal yarn_runner.dialogue_finished].
func _on_dialogue_finished():
	dialogue_has_finished = true


## Handles special GUI behaviour for certain commands
## like wait.
## Called by [signal yarn_runner.command_triggered]
func _on_command_triggered(command_name: String, arguments: Array):
	if command_name == "wait":
		print("GUI is waiting now...")
		await yarn_runner.wait_timer.timeout
		print("GUI's wait ended.")
		_display_next_line()


## Displays a number of shortcut options or a dialogue options
## using the option displays.
## If there are more prepared options than there are option
## displays, the additional prepared options will be ignored
## and an error is displayed.
## Emits [signal options_shown].
## Called by [signal yarn_runner.options_prepared].
func _on_options_prepared(prepared_options: Array[String]):
	if option_displays.size() < prepared_options.size():
		printerr(
			(
				"Received %d options, but the yarn GUI only has %d option nodes! Only %d options will be displayed."
				% [prepared_options.size(), option_displays.size(), option_displays.size()]
			)
		)

	# show all affected option displays
	for i in range(min(option_displays.size(), prepared_options.size())):
		option_displays[i].set_text(prepared_options[i])
		option_displays[i].visible = true

	is_showing_options = true
	options_shown.emit()


## Sets next_line and prepares name plate display using
## the given string.
## Immediately displays the next line if the current line
## is empty. (TODO FIXME: this is not clear from the code here -> check again.)
## Called by [signal yarn_runner.next_line_prepared].
func _on_next_line_prepared(line: String):
	if config.has_unknown_output_type:
		return
	
	print("setting next line...")
	
	next_line = line
	if should_display_immediately:
		should_display_immediately = false
		_display_next_line()

func update_name_plate_text() -> void:
	if name_plate_display == null:
		return
	
	var name_plate_result: RegExMatch = name_plate_regex.search(next_line)
	if name_plate_result == null:
		# no name label on this line
		name_plate_display.visible = false
		return
	
	# line contains a name label -> display
	var name_plate_text: String = name_plate_result.get_string()
	next_line = next_line.replace(name_plate_text + ":", "") # remove name label from the string
	next_line.strip_edges(true, false) # remove space after the name plate if there was one
	name_plate_display.set_text(name_plate_text)
	name_plate_display.visible = true

## Sets the text of the text display to next_line and
## resets its ratio of visible characters.
## Emits [signal text_changed] and [signal line_started].
## Note: Some pre-processing of next_line takes place in
## [method _on_next_line_prepared] beforehand.
func _display_next_line():
	if yarn_runner.is_waiting:
		print("waiting for runner to resume before displaying line...")
		#await yarn_runner.resumed
		await yarn_runner.wait_timer.timeout
		#return
	
	line_has_finished = false
	
	print("displaying next line...")
	
	if not (config.has_unknown_output_type or next_line.is_empty()):
		update_name_plate_text()
		if config.is_rich_text_label:
			text_display.parse_bbcode(next_line)
		else:
			# other text displays: display raw bbcode without formatting
			text_display.set_text(next_line)

		last_visible_chars = 0
		text_display.visible_ratio = 0.0
		should_update_total_line_time = true # tells [method _process] to reset the portion of shown text on the display
		
		text_changed.emit()
		line_started.emit()

		next_line = ""


### Setter method of [member _yarn_runner_path].
### Checks whether the path contains a valid yarn runner.
#func set_yarn_runner_path(node_path: NodePath):
#	print("yarn runner path: %s" % node_path)
#	_yarn_runner_path = node_path.get_as_property_path()
#
#	if get_node(node_path):
#		if get_node(_yarn_runner_path) is YarnRunner:
#			yarn_runner = get_node(_yarn_runner_path)
#		else:
#			printerr("The passed node is not a yarn runner node.")
#			yarn_runner = null
#	else:
#		yarn_runner = null
#
#
### Setter method of [member _text_display_path].
### Checks whether the path contains a valid display
#func set_text_display_path(node_path: NodePath):
#	print("text display path: %s" % node_path)
#	_text_display_path = node_path.get_as_property_path()
#
#	if _text_display_path:
#		text_display = get_node(_text_display_path)
#		if text_display:
#			if text_display is RichTextLabel:
#				config.is_rich_text_label = true
#			elif text_display is Label:
#				pass
#			elif not text_display.has_method("set_text"):
#				printerr("_text_display_path for the Yarn GUI did not point to a node with a set_text method. No text will be displayed.")
#				config.has_unknown_output_type = true
#		else: # text_display == null
#			printerr("_text_display_path for the Yarn GUI did not point to a node. No text will be displayed.")
#			config.has_unknown_output_type = true
#	else:
#		config.has_unknown_output_type = true
#
#
### Setter method of [member _name_plate_display_path].
### Checks whether the path contains a valid display.
#func set_name_plate_display_path(node_path: NodePath):
#	print("name plate path: %s" % node_path)
#	_name_plate_display_path = node_path.get_as_property_path()
#
#	if _name_plate_display_path:
#		name_plate_display = get_node(_name_plate_display_path)
#		if name_plate_display == null:
#			printerr("Yarn GUI's name plate path does not point to a node")
#		if not name_plate_display.has_method("set_text"):
#			printerr("Yarn GUI's name plate couldn't be set: _name_plate_display_path must point to a node with a set_text method!")
#			name_plate_display = null
#
#
### Setter method of [member _option_display_paths].
### Checks whether all paths contain a valid display.
#func set_option_display_paths(node_paths: Array[NodePath]):
#	_option_display_paths = node_paths
#
#	if _option_display_paths.size() > 0:
#		option_displays.clear()
#		for option_display_path in _option_display_paths:
#			print("option display path: %s" % [option_display_path])
#			option_displays.push_back(get_node(option_display_path.get_as_property_path()))
#
#			if not option_displays.back().has_method("set_text"):
#				printerr("%s in the Yarn GUI's option path does not point to a node with a set_text method! This node will not be added to the options array.")
#				option_displays.pop_back()
#				continue


## A class holding some variables that should be publically visible.
##
##
class Configuration:
	## If the text display is a rich text label then we are going to use
	## bb text by default. If we change this again at runtime,
	## we will no longer use bb text
	var is_rich_text_label: bool = false

	## If an output display is unknown we will expect it to contain
	## a set_text(text) function. If it does not, we
	## want to print out an error to the console instead, letting the user
	## know that the display is invalid.
	var has_unknown_output_type: bool = false
