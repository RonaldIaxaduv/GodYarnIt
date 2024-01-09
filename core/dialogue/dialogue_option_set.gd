## A simple container class holding a list of DialogueOption objects.
##
## Previously called option.gd
extends Object

var options: Array = []  # type: DialogueOption


func _init(options: Array = []):
	self.options = options
