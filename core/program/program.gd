## A simple container holding data of a yarn program.
## 
## Contains the program's name, yarn strings and compiled yarn nodes.
extends Resource


const YarnStringContainer = preload("res://addons/godyarnit/core/program/yarn_string_container.gd")


var program_name: String
var yarn_strings: Dictionary = {} # type [String, yarn_string_container.gd] -> (id: string+metadata), copied over from compiler._registered_string_table 
var yarn_nodes: Dictionary = {} # type [String, compiled_yarn_node.gd] -> (node name, compiled yarn node)

## an array of line Info data that gets exported to file
## stripped of the text information that is saved to another file
var _line_infos: Array = [] # TODO FIXME: type? yarn_string_container.gd?


func _init():
	yarn_nodes = {}
	yarn_strings = {}
	program_name = ""


func get_node_tags(name: String) -> Array:
	return yarn_nodes[name].tags


func resolve_yarn_string(string_id: String) -> String:
	var string_container: YarnStringContainer = yarn_strings.get(string_id, null) as YarnStringContainer
	return string_container.text if string_container != null else ""


func get_node_text(name: String) -> String:
	var node = yarn_nodes.get(name, null)
	if node == null:
		return ""
	
	var string_id: String = node.source_id
	return resolve_yarn_string(string_id)


func has_yarn_node(name: String) -> bool:
	return yarn_nodes.has(name)


## possible support for line tags (NOT IMPLEMENTED)
func get_untagged_strings() -> Dictionary:
	return {}


## merge this program with the other (NOT IMPLEMENTED)
func merge(other):
	pass


# include the other program in this one (NOT IMPLEMENTED)
func include(other):
	# same as merge
	# TODO: Remove merge and just keep include as it makes more semantic sense
	#       since we are not returning a new program containing the other one.
	pass


# dump all the instructions into a readable format (NOT IMPLEMENTED)
func dump(library):
	print("not yet implemented")
	pass
