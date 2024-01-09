## Dialogue element used for handlung options.
##
## Handles both shortcut options as well as dialogue options (links to other dialogues) with text.
## Dialogue options without text are handled using jumps and so don't need this class.
## note: has been renamed from option.gd to differentiate it from shortcut options and dialogue options
extends Object

const DisplayedLine = preload("res://addons/godyarnit/core/dialogue/displayed_line.gd")

var displayed_line: DisplayedLine
var id: int
var destination: String


func _init(displayed_line: DisplayedLine, id: int, destination: String):
	self.displayed_line = displayed_line
	self.id = id
	self.destination = destination
