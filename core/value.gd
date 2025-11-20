## A class representing a value and operations on that value.
##
## An object of this class holds a value accessible through [method get_value].
## All common unary and binary operators on values are provided
## through further methods.

const Value = preload("uid://dtwoppax6efli") # value.gd


const NULL_STRING: String = "null"
const FALSE_STRING: String = "false"
const TRUE_STRING: String = "true"
const NANI: String = "NaN"

var type: int = YarnGlobals.ValueType.Nullean
var number: float = 0
var string: String = ""
var variable: String = ""
var boolean: bool = false


## Create a new Value object from an arbitrary object.
func _init(value = NANI):
	if typeof(value) == TYPE_OBJECT && value.has_method("as_number"):
		# value is an object of this class
		if value.type == YarnGlobals.ValueType.Variable:
			self.type = value.type
			self.variable = value.variable
		else:
			set_value(value.get_value())
	else:
		set_value(value)


## Returns the value of the instance of this class.
func get_value():
	match type:
		YarnGlobals.ValueType.Number:
			return number
		YarnGlobals.ValueType.Str:
			return string
		YarnGlobals.ValueType.Boolean:
			return boolean
		YarnGlobals.ValueType.Variable:
			return variable
	return null


## Returns the value of this class instance converted to bool.
## Number: value != 0
## String: value != ""
## Boolean: value
func as_bool() -> bool:
	match type:
		YarnGlobals.ValueType.Number:
			return number != 0
		YarnGlobals.ValueType.Str:
			return !string.is_empty()
		YarnGlobals.ValueType.Boolean:
			return boolean
	return false


## Returns the value of this class instance converted to a string.
func as_string() -> String:
	if type == YarnGlobals.ValueType.Number:
		if number == int(number):
			return "%d" % number # avoids displaying unneeded decimal places
		else:
			return "%f" % number
	else:
		return "%s" % get_value()


## Returns the value of this class instance converted to a float.
## Number: value
## String: float(value)
## Boolean: 0.0 if !value else 1.0
func as_number() -> float:
	match type:
		YarnGlobals.ValueType.Number:
			return number
		YarnGlobals.ValueType.Str:
			return float(string)
		YarnGlobals.ValueType.Boolean:
			return 0.0 if !boolean else 1.0
	return 0.0


## Takes an arbitraty object and assigns its value to the most fitting
## member of this class. Also adjusts the type member to reflect the
## type of object that this class currently holds.
func set_value(value):
	if value == null || (typeof(value) == TYPE_STRING && value == NANI):
		type = YarnGlobals.ValueType.Nullean
		#printerr("NULLEAN VALUE ",value)
		return

	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			type = YarnGlobals.ValueType.Number
			number = value

			#printerr("NUMBER VALUE ",value)
		TYPE_STRING:
			type = YarnGlobals.ValueType.Str
			string = value
			#printerr("String VALUE ",value)
		TYPE_BOOL:
			type = YarnGlobals.ValueType.Boolean
			boolean = value
			#printerr("bool VALUE ",value)


# operations >>


func add(other: Value):
	if self.type == YarnGlobals.ValueType.Str:
		return get_script().new("%s%s" % [self.get_value(), other.get_value()])
	if self.type == YarnGlobals.ValueType.Number:
		return get_script().new(self.number + other.as_number())

	return get_script().new(other.as_number() + self.as_number())


func equals(other: Value) -> bool:
	if other.get_script() != self.get_script():
		return false
	if other.get_value() != self.get_value():
		return false
	
	return true


func xor(other: Value):
	if self.type == YarnGlobals.ValueType.Number:
		return get_script().new(pow(self.as_number(), other.as_number()))
	
	return get_script().new(self.as_bool() != other.as_bool())


## A method for subtracting another value from this value.
## TODO: add a distinction when subtracting numbers from a string, maybe remove x amount of characters?
##       so   ("hello world!" - 5 ) -> "hello w"
func sub(other: Value):
	if self.type == YarnGlobals.ValueType.Str:
		return get_script().new(str(get_value()).replace(str(other.get_value()), ""))
	if self.type == YarnGlobals.ValueType.Number:
		return get_script().new(self.number - other.as_number())
	
	return get_script().new(self.as_number() - other.as_number())


func mult(other: Value):
	if self.type == YarnGlobals.ValueType.Number:
		return get_script().new(self.number * other.as_number())
	
	return get_script().new(self.as_number() * other.as_number())


func div(other: Value):
	if self.type == YarnGlobals.ValueType.Number:
		return get_script().new(self.number / other.as_number())
	
	return get_script().new(self.as_number() / other.as_number())


func mod(other: Value):
	if self.type == YarnGlobals.ValueType.Number && other.type == YarnGlobals.ValueType.Number:
		return get_script().new(fmod(self.number, other.number))
	
	return get_script().new(fmod(self.as_number(), other.as_number()))


## Unary negation.
func negative():
	if self.type == YarnGlobals.ValueType.Number:
		return get_script().new(-self.number)
	if self.type == YarnGlobals.ValueType.Boolean:
		return get_script().new(!self.as_bool())
	
	return null


## greater than other value
func greater(other: Value) -> bool:
	if self.type == YarnGlobals.ValueType.Number && other.type == YarnGlobals.ValueType.Number:
		return self.number > other.number
	
	return false


## less than other value
func less(other: Value) -> bool:
	if self.type == YarnGlobals.ValueType.Number && other.type == YarnGlobals.ValueType.Number:
		return self.number < other.number
	
	return false


## greater than or equal to other value
func geq(other: Value) -> bool:
	if self.type == YarnGlobals.ValueType.Number && other.type == YarnGlobals.ValueType.Number:
		return self.number > other.number || self.equals(other)
	
	return false


## lesser than or equal to other value
func leq(other: Value) -> bool:
	if self.type == YarnGlobals.ValueType.Number && other.type == YarnGlobals.ValueType.Number:
		return self.number < other.number || self.equals(other)
	
	return false


## Returns a string representing this Value object.
func _to_string() -> String:
	return "value(type[%s]: %s)" % [type, get_value()]
