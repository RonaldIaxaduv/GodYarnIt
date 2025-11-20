## A dialogue element for holding any number of arbitrary values.
##
## Contains a dictionary where the keys are the IDs of variables
## and the value the referenced variable.
## TODO: Implement methods to make these variables persistent across
##		 different scenes. ([method convert_to_string_data] and [method populate_from_string_data]
##		 provided for this purpose.)
@icon("uid://c2b3c1dlwg3wq") # storage.png
class_name YarnVariableStorage
extends Node


const Value = preload("uid://dtwoppax6efli") # value.gd


# emitted when a call to set_value has been made
# will also pass in the name of the set value
signal value_set(val_name: String)

var variables: Dictionary[String, Value] = {}: ## (object ID, object value)
	set = _set_vars


func _ready():
	pass


## Registers a new variable in the dictionary or overwrites an existing one.
## Emits [signal value_set].
func set_value(name: String, value):
	if !(value is Value):
		variables[name] = Value.new(value)
	else:
		variables[name] = value
	value_set.emit(name)


## Returns the variable from the storage that's registered
## under the given name. It's returned as its original type.
func get_value(name: String):
	return get_value_raw(name).value()


## Returns the variable from the storage that's registered
## under the given name. It's returned as a Value object.
func get_value_raw(name: String) -> Value:
	return variables[name] if variables.has(name) else null


## Clears the dictionary storing the variables.
func clear_values():
	variables.clear()


## Returns the IDs of all variables that are currently stored.
func var_names() -> Array[String]:
	return variables.keys()


## NOT IMPLEMENTED
## This should provide a way to help storage perist between scenes
## TODO:
##      convert the data contained in this storage into a string
func convert_to_string_data() -> String:
	return ""


## NOT IMPLEMENTED
## TODO:
##     populate the storage using data from [method convert_to_string_data]
func populate_from_string_data(data: String):
	pass


## Internal function to set the value in the storage.
## To be used by the dialogue virtual machine.
func _set_value_(name: String, value):
	set_value(name.trim_prefix("$"), value)


## Gets a value internally. from the dialogue virtual machine.
## Removes the '$' prefix.
func _get_value_(name: String) -> Value:
	return get_value_raw(name.trim_prefix("$"))


## NOT SUPPORTED
func _get_vars() -> Dictionary[String, Value]:
	printerr("Do not access variables in variable store directly - Use `get_value` function")
	return variables


## NOT SUPPORTED
func _set_vars(value: Dictionary[String, Value]):
	printerr("Do not access variables in variable store directly - Use `set_value` function")
