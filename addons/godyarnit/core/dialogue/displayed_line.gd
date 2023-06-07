## A simple container class for holding a line of displayed dialogue and its expressions.
##
## Used in the virtual machine.
## note: renamed from line.gd for more clarity
extends Object

var id: String
var substitutions: Array[String] = []


func _init(id: String):
	self.id = id
