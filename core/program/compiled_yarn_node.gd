## A simple container class for data from a compiled yarn node.
##
## Contains the node's name, a stack of instructions to execute it,
## a dictionary of label positions, tags and source ID.
extends Object


const Instruction = preload("uid://ccfk7selnh8tb") # instruction.gd


var node_name: String ## will be set to YarnParser.YarnDialogueNode.dialogue_section_name
var instructions: Array[Instruction] = [] ## stack containing objects of instruction.gd. The code of the node is executed using these instructions.
var labels: Dictionary[String, int] ## (label name, index on instructions stack)
var tags: Array[String] ## will be set to YarnParser.ParseNode.tags
var source_id: String ## if the node provided a source, this is where it will be stored


## Initialises this container with the values of another container.
func _init(other = null):
	if other != null && other.get_script() == self.get_script():
		node_name = other.node_name
		instructions.append_array(other.instructions)
		for key in other.labels.keys():
			labels[key] = other.labels[key]
		tags.append_array(other.tags)
		source_id = other.source_id


## Compares this container with another, returning true if they
## contain the same values
func equals(other) -> bool:
	if other.get_script() != self.get_script():
		return false
	if other.node_name != self.node_name:
		return false
	if other.instructions != self.instructions:
		return false
	if other.label != self.label:
		return false
	if other.source_id != self.source_id:
		return false
	
	return true


## Returns a string representing this container.
func _to_string() -> String:
	return "Node[%s:%s]" % [source_id, source_id]
