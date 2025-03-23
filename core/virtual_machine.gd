## A class for executing compiled yarn programs with a yarn dialogue.
##
## This is basically the back-end behind the dialogue.gd script.
## Among other things, it contains the method [method run_instruction] which
## executes the instructions which are contained in compiled yarn nodes,
## and [method set_selected_option] which sets the selected dialogue option.
## TODO FIXME: In [method run_instruction], the check for is_waiting takes place after the signal is emitted atm. This might be wrong!
extends Object

signal resumed
# var YarnGlobals = load("res://addons/godyarnit/autoloads/execution_states.gd")

const EXECUTION_COMPLETE: String = "execution_complete_command"
const YarnDialogue = preload("res://addons/godyarnit/core/dialogue.gd")
const FunctionInfo = preload("res://addons/godyarnit/core/libraries/function_info.gd")
const Value = preload("res://addons/godyarnit/core/value.gd")
const YarnProgram = preload("res://addons/godyarnit/core/program/program.gd")
const CompiledYarnNode = preload("res://addons/godyarnit/core/program/compiled_yarn_node.gd")
const Instruction = preload("res://addons/godyarnit/core/program/instruction.gd")
const DisplayedLine = preload("res://addons/godyarnit/core/dialogue/displayed_line.gd")
const Command = preload("res://addons/godyarnit/core/dialogue/command.gd")
const DialogueOption = preload("res://addons/godyarnit/core/dialogue/dialogue_option.gd")
const OptionSet = preload("res://addons/godyarnit/core/dialogue/dialogue_option_set.gd")

var NULL_VALUE: Value = Value.new(null)

var line_handler: Callable
var options_handler: Callable
var command_handler: Callable
var node_start_handler: Callable
var node_complete_handler: Callable
var dialogue_complete_handler: Callable

var is_waiting: bool = false

var execution_state: int = YarnGlobals.ExecutionState.Stopped

var _dialogue: YarnDialogue
var _program: YarnProgram
var _state: VmState

var _current_node: CompiledYarnNode


func _init(dialogue: YarnDialogue):
	self._dialogue = dialogue
	_state = VmState.new()


## Sets the executed YarnProgram.
func set_program(program: YarnProgram):
	_program = program


## Sets the node to run.
## Returns true if successful, or false if there is no node.
## with that name is found.
func set_current_node(node_name: String) -> bool:
	if _program == null || _program.yarn_nodes.size() == 0:
		printerr("Could not load node %s : no nodes contained in the program" % node_name)
		return false

	if !_program.yarn_nodes.has(node_name):
		execution_state = YarnGlobals.ExecutionState.Stopped
		reset_state()
		printerr("No node named %s exists in the program" % node_name)
		return false

	_dialogue.dlog("VirtualMachine.set_current_node", "Running node %s" % node_name)

	_current_node = _program.yarn_nodes[node_name]
	reset_state()
	_state.current_node_name = node_name
	node_start_handler.call(node_name)
	return true


## Returns the currently running node.
func get_current_node():
	return _current_node


## Gets the name of the currently running node.
func get_current_node_name() -> String:
	return _current_node.node_name


## Stops the execution of the virtual machine.
## Affects the current state, execution state
## and currently executed node.
func stop():
	execution_state = YarnGlobals.ExecutionState.Stopped
	reset_state()
	_current_node = null


## Sets the currently selected option and
## resume execution if is_waiting for result.
## This is used both for dialogue options (links to other nodes)
## as well as shortcut options.
## Returns false if error
func set_selected_option(option_id: int) -> bool:
	if execution_state != YarnGlobals.ExecutionState.WaitingForOption:
		printerr("Unable to select an option when dialogue not is_waiting for an option.")
		return false

	if option_id < 0 || option_id >= _state.current_options.size():
		printerr("%d is not a valid option index!" % option_id)
		return false

	# set destionation using the newly selected option and
	# push the value onto the state stack
	var destination: String = _state.current_options[option_id].value
	_state.push_value(destination)
	_state.current_options.clear()

	#no longer is_waiting for option
	execution_state = YarnGlobals.ExecutionState.Suspended

	return true


## Check whether there are any options that require resolution at the moment.
func has_options() -> bool:
	return _state.current_options.size() > 0


## Resets the virtual machine by settings its state to the default state.
func reset_state():
	_state = VmState.new()


## Executes the next instructions of the current node (indicated by _state.program_instruction_index)
## until the execution state isn't running anymore, i.e. until a line or options have been prepared etc.
## TODO FIXME: The check for is_waiting takes place after the signal is emitted atm. This might be wrong!
func resume() -> bool:
	# check various conditions for resuming the VM
	if _current_node == null:
		printerr("Cannot resume virtual machine dialogue with no node selected.")
		return false
	if execution_state == YarnGlobals.ExecutionState.WaitingForOption:
		printerr("Cannot resume virtual machine while is_waiting for option.")
		return false

	if line_handler == null:
		printerr("Cannot resume virtual machine without a line_handler.")
		return false
	if options_handler == null:
		printerr("Cannot resume virtual machine withour an options_handler.")
		return false
	if command_handler == null:
		printerr("Cannot resume virtual machine withour an command_handler.")
		return false
	if node_start_handler == null:
		printerr("Cannot resume virtual machine withour a node_start_handler.")
		return false
	if node_complete_handler == null:
		printerr("Cannot resume virtual machine withour an node_complete_handler.")
		return false

	resumed.emit()
	if is_waiting:
		return false ## TODO FIXME: should this be returned BEFORE the resumed signal is emitted?

	execution_state = YarnGlobals.ExecutionState.Running

	# execute instructions until execution state changes (e.g. when input is needed)
	while execution_state == YarnGlobals.ExecutionState.Running:
		# run next instruction and increment pointer
		var current_instruction: Instruction = _current_node.instructions[_state.program_instruction_index]
		await run_instruction(current_instruction)
		_state.program_instruction_index += 1

		if _state.program_instruction_index >= _current_node.instructions.size():
			# last instruction has been run -> node (dialogue) done -> stop and clean up
			node_complete_handler.call(_current_node.node_name)
			execution_state = YarnGlobals.ExecutionState.Stopped
			reset_state()
			dialogue_complete_handler.call()
			_dialogue.dlog("VirtualMachine.resume", "Run Complete")

	return true


## Returns the index of the given label on the instruction stack of the current node.
## Returns -1 if the label doesn't exist.
func find_label_instruction_index(label: String) -> int:
	if !_current_node.labels.has(label):
		printerr("Unknown label: " + label)
		return -1
	return _current_node.labels[label]

func peek_next_instruction_type() -> YarnGlobals.ByteCode:
	if not _current_node.instructions.has(_state.program_instruction_index + 1):
		return -1
	return (_current_node.instructions[_state.program_instruction_index + 1] as Instruction).operation


## Executes the given instruction object (instruction.gd).
## TODO: add format function support
## TODO: allow for inline expressions and format functions in commands
func run_instruction(instruction: Instruction) -> bool:
	match instruction.operation:
		YarnGlobals.ByteCode.Label:
			# nothing to do, only a marker
			pass
			
		YarnGlobals.ByteCode.JumpTo:
			# jump to named label
			_state.program_instruction_index = find_label_instruction_index(instruction.operands[0].value) - 1
			
		YarnGlobals.ByteCode.RunLine: # displays a line of text
			# look up string from string table
			# pass it to client as line
			var key: String = instruction.operands[0].value
			var line: DisplayedLine = DisplayedLine.new(key)

			if instruction.operands.size() > 1:
				# DisplayedLine contains one or more expressions.
				# The second operand is the expression count
				# of the format function.
				var expression_count: int = int(instruction.operands[1].value)
				
				# copy over format function substitutions
				while expression_count > 0:
					var value: Value = _state.pop_value()
					if value != null and value.type != YarnGlobals.ValueType.Nullean:
						line.substitutions.append(value.as_string())
					else:
						# expression functions containing calls to a function
						# without a return value should be substituted to an empty string
						line.substitutions.append("")
					expression_count -= 1

				pass  # TODO: add format function support

			var resulting_state: int = line_handler.call(line)

			if resulting_state == YarnGlobals.HandlerState.PauseExecution:
				execution_state = YarnGlobals.ExecutionState.Suspended

		YarnGlobals.ByteCode.RunCommand: # handles built-in commands like wait
			var success: bool = await _handle_command(instruction)
			if not success:
				return false

		YarnGlobals.ByteCode.PushString: # pushes a String variable to the state stack
			_state.push_value(instruction.operands[0].value)
			
		YarnGlobals.ByteCode.PushNumber: # pushes a number to the state stack
			_state.push_value(instruction.operands[0].value)
			
		YarnGlobals.ByteCode.PushBool: # pushes a boolean to the state stack
			_state.push_value(instruction.operands[0].value)

		YarnGlobals.ByteCode.PushNull: # pushes a null value to the state stack
			_state.push_value(NULL_VALUE)

		YarnGlobals.ByteCode.JumpIfFalse: # jumps to the label (given in the instruction) if value of state stack top is false
			if !_state.peek_value().as_bool():
				_state.program_instruction_index = find_label_instruction_index(instruction.operands[0].value) - 1

		YarnGlobals.ByteCode.Jump: # jumps to the label whose name is on the stack
			var dest: String = _state.peek_value().as_string()
			_state.program_instruction_index = find_label_instruction_index(dest) - 1
			
		YarnGlobals.ByteCode.Pop: # pops value from state stack
			_state.pop_value()
			
		YarnGlobals.ByteCode.CallFunc: # calls function with params on the state stack. any return values are pushed to the stack
			var success: bool = await _handle_function_call(instruction)
			if not success:
				return false
			
		YarnGlobals.ByteCode.PushVariable: # state stack contains a variable name. get that variable from the dialogue's variable storage and pushes it onto the state stack
			var name: String = instruction.operands[0].value
			var loaded: Value = _dialogue._variable_storage._get_value_(name)
			_state.push_value(loaded)
			
		YarnGlobals.ByteCode.StoreVariable: # stores the top state stack value to a variable in the dialogue's variable storage. the ID is given as the first instruction arg
			var top: Value = _state.peek_value()
			var destination: String = instruction.operands[0].value
			_dialogue._variable_storage._set_value_(destination, top)

		YarnGlobals.ByteCode.Stop: # stops execution and resets the virtual machine
			node_complete_handler.call(_current_node.node_name)
			dialogue_complete_handler.call()
			execution_state = YarnGlobals.ExecutionState.Stopped
			reset_state()

		YarnGlobals.ByteCode.RunNode: # runs a node. designates the previous node as completed.
			var name: String

			if instruction.operands.size() == 0 || instruction.operands[0].value.is_empty():
				# get node name from state stack and jump to node with that name
				name = _state.peek_value().get_value()
			else:
				# get node name through instruction args
				name = instruction.operands[0].value

			var resulting_state: int = node_complete_handler.call(_current_node.node_name)
			set_current_node(name)
			_state.program_instruction_index -= 1
			if resulting_state == YarnGlobals.HandlerState.PauseExecution:
				execution_state = YarnGlobals.ExecutionState.Suspended

		YarnGlobals.ByteCode.AddOption: # adds an option to the current state. this can be either a dialogue option (link to other dialogue) with text or a shortcut option.
			var line: DisplayedLine = DisplayedLine.new(instruction.operands[0].value)

			# options always contain at least 2 values: the ID of the displayed text and a destination ID
			if instruction.operands.size() > 2:
				# displayed text additionally contains expressions -> evaluate
				var expression_count: int = int(instruction.operands[2].value)

				while expression_count > 0:
					line.substitutions.append(_state.pop_value().as_string())
					expression_count -= 1

			# store line to show and node name in state
			_state.current_options.append(OptionEntry.new(line, instruction.operands[1].value))

		YarnGlobals.ByteCode.ShowOptions: # show option(s). stop if none are given. these can be shortcut options or a dialogue option (link to other dialogue) with text.
			if _state.current_options.size() == 0:
				# no options to show -> end of node -> stop
				execution_state = YarnGlobals.ExecutionState.Stopped
				reset_state()
				dialogue_complete_handler.call()
				return false

			# present list of options
			var choices: Array[DialogueOption] = []
			for option_index in range(_state.current_options.size()):
				var option: OptionEntry = _state.current_options[option_index]
				choices.append(DialogueOption.new(option.key, option_index, option.value))

			# we cant continue until an option is chosen
			execution_state = YarnGlobals.ExecutionState.WaitingForOption

			# pass the options to the client to show them
			# delegate for them to call when the user
			# makes selection
			options_handler.call(OptionSet.new(choices))
			pass
			
		_:
			# unknown instruction bytecode -> stop
			execution_state = YarnGlobals.ExecutionState.Stopped
			reset_state()
			printerr("VirtualMachine.run_instruction: unknown instruction bytecode: %s " % instruction.operation)
			return false

	return true

func _handle_command(command_instruction: Instruction) -> bool:
	var command_name: String = command_instruction.operands[0].value
	
	# TODO: allow for inline expressions and format functions in commands
	if command_instruction.operands.size() > 1:
		pass  #add format function
	
	var command: Command = Command.new(command_name)
	var arg_count: int = _state.pop_value().as_number()
	var args: Array[Value] = [] as Array[Value]
	for i in range(arg_count):
		args.push_front(_pop_resolved_value())
	command.args = args
	
	var was_successful: bool
	match command.command_name:
		"wait":
			was_successful = await _handle_wait(command)
		"jump":
			was_successful = _handle_jump(command)
		_:
			was_successful = await _handle_custom_command(command)
	
	return was_successful

func _handle_wait(command: Command) -> bool:
	if command.args.size() < 1:
		printerr("VirtualMachine._handle_wait: tried to execute a wait command without time argument. Command skipped.")
		return false
	if (command.args.back() as Value).type != YarnGlobals.ValueType.Number:
		printerr("VirtualMachine._handle_wait: wait command wasn't followed by an expression evaluating to a number. Command skipped.")
		return false
	
	var wait_time: float = (command.args.back() as Value).as_number()
	if wait_time <= 0.0:
		return true
	
	is_waiting = true
	
	var prev_execution_state: int = execution_state
	execution_state = YarnGlobals.ExecutionState.Suspended # always assume suspension
	
	var resulting_state: int = await command_handler.call(command) # calls runner's _handle_command. await is obligatory, otherwise this line causes a break
	if resulting_state != YarnGlobals.HandlerState.PauseExecution: # TODO FIXME: DEADLOCK! for the previous call to end, runner.resume is called, which calls dialogue.resume, which calls vm.resume - but the vm is still waiting here!
		execution_state = prev_execution_state # return to prior execution state (if call was synchronous, this should be executed seemlessly hopefully...)
	
	if execution_state == YarnGlobals.ExecutionState.Suspended:
		await self.resumed
	
	is_waiting = false
	return true

func _handle_jump(command: Command) -> bool:
	if command.args.size() < 1:
		printerr("VirtualMachine._handle_jump: tried to execute a jump command without dialogue_name argument. Command skipped.")
		return false
	if (command.args.back() as Value).type != YarnGlobals.ValueType.Str:
		printerr("VirtualMachine._handle_jump: jump command wasn't followed by an expression evaluating to a string. Command skipped.")
		return false
	_dialogue.dlog("VirtualMachine._handle_jump", "%d args detected" % command.args.size())
	for arg in command.args:
		_dialogue.dlog("", "\t%s" % arg.as_string())
	
	var dialogue_node_name: String = (command.args.back() as Value).as_string()
	_dialogue.dlog("VirtualMachine._handle_jump", "trying to jump to dialogue %s" % dialogue_node_name)
	if not _program.has_yarn_node(dialogue_node_name):
		printerr("VirtualMachine._handle_jump: can't jump to dialogue node %s because it wasn't found in the program. Command skipped." % [dialogue_node_name])
		return false
	
	#var prev_execution_state: int = execution_state
	#execution_state = YarnGlobals.ExecutionState.Suspended
	#
	#var resulting_state: int = command_handler.call(command)
	#if (resulting_state != YarnGlobals.HandlerState.PauseExecution):
		#execution_state = prev_execution_state
	
	var resulting_state: int = node_complete_handler.call(_current_node.node_name)
	set_current_node(dialogue_node_name)
	_state.program_instruction_index -= 1
	if resulting_state == YarnGlobals.HandlerState.PauseExecution:
		execution_state = YarnGlobals.ExecutionState.Suspended
	
	return true

func _handle_custom_command(command: Command) -> bool:
	#var pause = command_handler.call(command)
	#if (
		#pause is GDScriptFunctionState
		#|| pause == YarnGlobals.HandlerState.PauseExecution
	#):
		#execution_state = YarnGlobals.ExecutionState.Suspended
	
	var prev_execution_state: int = execution_state
	execution_state = YarnGlobals.ExecutionState.Suspended
	
	var resulting_state: int = command_handler.call(command)
	if (resulting_state != YarnGlobals.HandlerState.PauseExecution):
		execution_state = prev_execution_state
	
	return true

func _handle_function_call(instruction: Instruction) -> bool:
	var function_name: String = instruction.operands[0].value
	var function: FunctionInfo = _dialogue.library.get_function(function_name)
	
	var expected_param_count: int = function.param_count
	var actual_param_count: int = _state.pop_value().as_number()

	if not function.check_param_count_valid(actual_param_count):
		printerr("VirtualMachine.run_instruction: function %s expected %d parameters but got %d instead" % [
			function_name, expected_param_count, actual_param_count
		])
		return false

	var result

	if actual_param_count == 0:
		result = await function.invoke()
	else:
		var params: Array[Value] = []
		for i in range(actual_param_count):
			params.push_front(_pop_resolved_value())

		result = await function.invoke(params)
		# print("function[%s] result[%s]" %[functionName, result._to_string()])

	if function.returns_value:
		_state.push_value(result)
	
	return true

## Pops value from _state. Strings (which are stored using their ID) will be resolved
## to their value.
func _pop_resolved_value() -> Value:
	var value: Value = _state.pop_value()
	if value.type == YarnGlobals.ValueType.Str:
		var string_id: String = value.as_string()
		var registered_string: String = _program.resolve_yarn_string(string_id)
		_dialogue.dlog("VirtualMachine._pop_resolved_value", "resolved string_id %s to string %s" % [string_id, registered_string])
		value.set_value(registered_string)
	return value

## Class representing the state of the virtual machine.
##
## Contains the name of the current node, the number of programs,
## a list of current options and a stack of values.
class VmState:
	#var Value = load("res://addons/godyarnit/core/value.gd")

	var current_node_name: String
	var program_instruction_index: int = 0 ## index of the instruction which will be executed next
	var current_options: Array[OptionEntry] = []
	var stack: Array[Value] = []

	func push_value(value) -> void:
		if value is Value:
			stack.push_back(value)
		else:
			stack.push_back(Value.new(value))

	func pop_value() -> Value:
		return stack.pop_back()

	func peek_value() -> Value:
		return stack.back()

	func clear_stack() -> void:
		stack.clear()


## A simple container holding an option's parameters.
## 
## This is used both for shortcut options as well as dialogue options
## (links to other dialogues) with text.
class OptionEntry:
	var key: DisplayedLine
	var value: String

	func _init(key: DisplayedLine, value: String):
		self.key = key
		self.value = value
