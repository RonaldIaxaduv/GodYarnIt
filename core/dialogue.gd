## Class with methods used for executing yarn dialogues through a virtual machine.
##
## This class essentially translates the state and behaviour of the virtual
## machine into slightly higher-level language. Most importantly, it's used to
## get/set the VM's current program or node.
## Keeps track of how often every node (dialogue) has been visited.
## This is where any function libraries are accessed.
## (To be honest, I find this class kiiiind of redundant at the moment; in my
## opinion, it could just as well be merged into virtual_machine.gd or yarn_runner.gd.)
extends Node

const DEFAULT_START: String = "Start"

# const StandardLibrary = preload("res://addons/godyarnit/core/libraries/standard.gd")
const YarnProgram = preload("res://addons/godyarnit/core/program/program.gd")
const VirtualMachine = preload("res://addons/godyarnit/core/virtual_machine.gd")
const YarnLibrary = preload("res://addons/godyarnit/core/libraries/library.gd")

var library: YarnLibrary
var execution_complete: bool

var _variable_storage: YarnVariableStorage

var _debug_log: Callable ## calls [method dlog]
var _err_log: Callable ## calls [method elog]

var _program: YarnProgram

var _vm: VirtualMachine

var _visited_node_counts: Dictionary = {} ## type [String, int] -> (node name, number of times the node has been visited)


func _init(variable_storage: YarnVariableStorage):
	_variable_storage = variable_storage
	if !_variable_storage:
		printerr("Passed variable storage during dialogue initialisation was null!")
	_vm = VirtualMachine.new(self)
	var YarnLibrary = load("res://addons/godyarnit/core/libraries/library.gd")
	#var _variable_storage
	library = YarnLibrary.new()
	_debug_log = Callable(self, "dlog")
	_err_log = Callable(self, "elog")
	execution_complete = false

	# import the standard library
	# this contains math constants, operations and checks
	var StandardLibrary = load("res://addons/godyarnit/core/libraries/standard.gd")
	library.import_library(StandardLibrary.new())

	#add a function to lib that checks if node is visited
	library.register_function("check_visited", -1, Callable(self, "check_node_visited"), true)

	#add function to lib that gets the node visit count
	library.register_function("visit_count", -1, Callable(self, "get_node_visit_count"), true)

## Prints a message. Used for [member _debug_log].
func dlog(message: String):
	print("YARN_DEBUG : %s" % message)


## Prints an error message. Used for [member _err_log].
func elog(message: String):
	printerr("YARN_ERROR : %s" % message)


## Returns true if the virtual machine hasn't stopped yet.
func is_active() -> bool:
	return get_exec_state() != YarnGlobals.ExecutionState.Stopped


## Gets the current execution state of the virtual machine.
func get_exec_state():
	return _vm.execution_state


## Selects a dialogue option (link to other node) or shortcut option.
## For dialogue options, this should always be 0.
func set_selected_option(option: int):
	_vm.set_selected_option(option)


## Sets the node currently executed in the virtual machine.
func set_node(node_name: String = DEFAULT_START):
	_vm.set_current_node(node_name)


## If the virtual machine currently isn't running (i.e. executing
## instructions), it's resumed (i.e. it executes the next instructions
## until a line has been prepared or options have been prepared etc.).
func resume():
	if _vm.execution_state == YarnGlobals.ExecutionState.Running:
		return
	await _vm.resume()


## Stops the execution of the virtual machine.
func stop():
	_vm.stop()
	pass


## Returns a list of all node names contained in the current program.
func get_all_nodes() -> Array[String]:
	return _program.yarn_nodes.keys()


## Gets the name of the node currently executed in the virtual machine.
func get_current_node() -> String:
	return _vm.get_current_node()


## If a node registered under the given name exists in the yarn program,
## an ID string for that node is returned.
## Returns an empty string otherwise.
func get_node_id(node_name: String) -> String:
	if _program.yarn_nodes.size() == 0:
		_err_log.call("No nodes loaded")
		return ""
	if _program.yarn_nodes.has(node_name):
		return "id:" + node_name
	else:
		_err_log.call("No node named [%s] exists" % node_name)
		return ""


## Gets the dictionary of stored string of the current program.
func get_program_strings() -> Dictionary:
	return _program.yarn_strings


## Clears the current program and, optionally, the number of visited nodes.
func unload_all(clear_visited_count: bool = true):
	if clear_visited_count:
		_visited_node_counts.clear()
	_program = null


## NOT IMPLEMENTED (in program.gd). Dumps the currently used library.
func dump() -> String:
	return _program.dump(library)


## Checks wheher a node registered under the given name exists in the current program.
func check_node_exists(node_name: String) -> bool:
	return _program.yarn_nodes.has(node_name)


## Sets the currently executed program.
func set_program(program: YarnProgram):
	_program = program
	_vm.set_program(_program)
	_vm.reset_state()


## Gets the current program.
func get_program() -> YarnProgram:
	return _program


## Combines the given program with the one currently running.
## If no program is running, simply runs the given program.
func add_program(program: YarnProgram):
	if _program == null:
		set_program(program)
	else:
		_program = YarnGlobals.combine_programs([_program, program])


## NOT IMPlEMENTED
func analyze(context):
	print(": not implemented")
	pass


## Returns the virtual machine that this dialogue uses.
func get_vm() -> VirtualMachine:
	return _vm


## Checks whether the given node has been visited before.
func check_node_visited(node_name: String = _vm.get_current_node_name()) -> bool:
	return get_node_visit_count(node_name) > 0


## Gets how often the given node has been visited.
func get_node_visit_count(node_name: String = _vm.get_current_node_name()) -> int:
	var visit_count: int = 0
	if _visited_node_counts.has(node_name):
		visit_count = _visited_node_counts[node_name]
	return visit_count


## Gets a list with the names of all nodes that have been visited at least once.
func get_visited_nodes() -> Array[String]:
	return _visited_node_counts.keys()


## Sets the names in the list of visited nodes to the ones in the given list.
## Considers each node to have been visited once.
func set_visited_nodes(visited_list: Array[String]):
	_visited_node_counts.clear()
	for node_name in visited_list:
		_visited_node_counts[node_name] = 1
