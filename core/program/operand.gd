## A simple container holding an arbitrary value.
##
## Contains the value as well as its type.
## Used for instructions which, in turn, are used for executing compiled nodes.
extends Object

enum ValueType { None, StringValue, BooleanValue, FloatValue }

var value ## arbitrary value
var value_type: int ## item of ValueType; indicates the type of value


func _init(value: Variant):
	if typeof(value) == TYPE_OBJECT && value.get_script() == self.get_script():
		# value is another operand object
		self.set_value(value.value)
	else:
		set_value(value)


func set_value(value) -> void:
	match typeof(value):
		TYPE_FLOAT, TYPE_INT:
			set_number(value)
		TYPE_BOOL:
			set_boolean(value)
		TYPE_STRING:
			set_string(value)
		_:
			pass


func set_boolean(value: bool):
	_set_value(value)
	value_type = ValueType.BooleanValue
	return self


func set_string(value: String):
	_set_value(value)
	value_type = ValueType.StringValue
	return self


func set_number(value: float):
	_set_value(value)
	value_type = ValueType.FloatValue
	return self


func clear_value():
	value_type = ValueType.None
	value = null


func clone():
	return get_script().new(self)


## Returns a string representing this operand.
func _to_string() -> String:
	return "Operand[%s:%s]" % [value_type, value]


## Private method for directly setting the value member to the given value.
func _set_value(value):
	self.value = value
