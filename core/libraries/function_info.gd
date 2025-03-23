## A container class for an arbitrary function. The function can be called with any arguments.
##
## Contains the function's name (as a string), the number of parameters it takes, a Callable
## for invoking it, and a bool for whether it returns any values.
## Use [method invoke] to call the function. Pass any args in an untyped array to that method.
extends Object


const Value = preload("res://addons/godyarnit/core/value.gd")

var name: String ## name of the function
var param_count: int = 0 ## number of parameters that this function takes. Set to -1 to indicate a variable number of parameters.
var function: Callable ## object for calling the function
var returns_value: bool = false


func _init(name: String, param_count: int, function: Callable, returns_value: bool = false): # function used be be null by default, but Callable isn't nullable (unlike FuncRef)
	self.name = name
	self.param_count = param_count
	self.function = function
	self.returns_value = returns_value


## Invoke the callable of this function info with the given parameters as argument.
func invoke(params: Array = []):
	var length = 0
	if params != null:
		length = params.size()
	if check_param_count_valid(length):
		if returns_value:
			if length > 0:
				var result = await function.callv(params)
				# printerr("function is returning null when it shouldnt, ", result," type of ", typeof(result))
				return Value.new(result)
			else:
				return Value.new(await function.call())
		else:
			if length > 0:
				await function.callv(params)
			else:
				await function.call()
	return null


## Checks whether the given number of parameters can be applied to the contained function.
func check_param_count_valid(param_count_to_check: int) -> bool:
	return self.param_count == param_count_to_check || self.param_count == -1
