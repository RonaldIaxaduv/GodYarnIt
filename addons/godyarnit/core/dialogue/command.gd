## A container class for a built-in command and its arguments.
##
## Used in the virtual machine.
extends Object

var command: String
var args: Array[String]


func _init(command_and_args: String):
	var result : PackedStringArray = command_and_args.strip_edges().split(" ")
	self.command = result[0]

	if result.size() > 1:
		result.remove_at(0)
		args = result
