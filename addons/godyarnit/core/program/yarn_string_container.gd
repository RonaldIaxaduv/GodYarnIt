## A simple container class for a stored string.
##
## Contains the string and some information about which node, line etc. it belongs to.
## Its main use is to store the lines of displayed text in a yarn program.

var text: String ## the text stored in this object
var node_name: String ## name of the node that this text belongs to
var line_number: int ## line number in which the text occurs
var file_name: String ## name of the file in which the line is situation
var is_implicit: bool ## true the text doesn't have an ID in the yarn code (that ID would be used to access this object, so a temporary ID will be generated at compilation time)
var meta: PackedStringArray = [] ## contains tags, for instance


func _init(
	text: String,
	node_name: String,
	line_number: int,
	file_name: String,
	is_implicit: bool,
	meta: PackedStringArray
):
	self.text = text
	self.node_name = node_name
	self.line_number = line_number
	self.file_name = file_name
	self.is_implicit = is_implicit
	self.meta = meta
