## A container class for a built-in command and its arguments.
##
## Used in the virtual machine.
extends Object


const Value = preload("res://addons/godyarnit/core/value.gd")


var command_name: String
var args: Array[Value]


func _init(command_name: String):
	self.command_name = command_name
