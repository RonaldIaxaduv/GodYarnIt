## A class representing a dictionary of functions that can be accessed using a string ID.
##
## A subclass of this exists with the core/libraries/standard.gd script.
extends Object

const FunctionInfo = preload("res://addons/godyarnit/core/libraries/function_info.gd")

var functions: Dictionary = {}  ## type [String, FunctionInfo]. 


func get_function(name: String) -> FunctionInfo:
	if functions.has(name):
		return functions[name]
	else:
		printerr("Invalid Function: %s" % name)
		return null


## Copies all key-value pairs from given other library's function dictionary
## and copies them to this library's function dictionary.
func import_library(other) -> void:
	YarnGlobals.get_script().copy_directory(functions, other.functions)


## Adds a new FunctionInfo value to the functions array using the given args.
func register_function(
	name: String, param_count: int, function: Callable, returns_value: bool
) -> void:
	var function_info: FunctionInfo = FunctionInfo.new(name, param_count, function, returns_value)
	functions[name] = function_info


## Removes the function registered under the given name from the functions array.
func deregister_function(name: String) -> void:
	if !functions.erase(name):
		pass
