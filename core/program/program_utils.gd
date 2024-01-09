## A helper script for saving and loading a yarn program to and from storage.
##
## To save a program (and its strings) to storage, use [method export_program].
## To load a program (and its strings) from storage, use [method import_program].
## All other methods are used for the import/export process.
## Note that the strings of a program are stored in a separate file in the same
## directory as the program file. It uses the name [program name]-strings.tsv.
extends Object

# TODO: make code naming conventions more consistent
const PROGRAM_NAME: String = "program_name"
const PROGRAM_LINE_INFO: String = "program_line_info"
const PROGRAM_NODES: String = "program_nodes"

const NODE_NAME: String = "node_name"
const NODE_INSTRUCTIONS: String = "node_instructions"
const NODE_LABELS: String = "node_labels"
const NODE_TAGS: String = "node_tags"
const NODE_SOURCE_ID: String = "node_source_id"

const INSTRUCTION_OP: String = "instruction_op" ## instruction operation
const INSTRUCTION_OPERANDS: String = "instruction_operands"

const OPERAND_TYPE: String = "operand_type"
const OPERAND_VALUE: String = "operand_value"

const STRINGS_DELIMITER: String = "\t"

# const YarnGlobals = preload("res://addons/godyarnit/autoloads/execution_states.gd")
const Operand = preload("res://addons/godyarnit/core/program/operand.gd")
const YarnProgram = preload("res://addons/godyarnit/core/program/program.gd")
const Instruction = preload("res://addons/godyarnit/core/program/instruction.gd")
const CompiledYarnNode = preload("res://addons/godyarnit/core/program/compiled_yarn_node.gd")
const LineInfo = preload("res://addons/godyarnit/core/program/yarn_string_container.gd")

const STRINGS_EXTENSION := "tsv"
const DEFAULT_STRINGS_FORMAT = "%s-strings.%s"
const LOCALISED_STRINGS_FORMAT = "%s-%s-strings.%s"


func _init():
	pass


## Serialises the program and its stored strings.
## The program is saved to the disk at the given file path.
## The strings are saved to the disk in the same directory as
## the program, but in a different file ([filename]-strings.tsv).
static func export_program(program: YarnProgram, file_path: String) -> void:
	var file : FileAccess

	var strings_path = DEFAULT_STRINGS_FORMAT % [file_path.get_basename(), STRINGS_EXTENSION] # basename: full filepath without extension
	var line_infos: Dictionary = program.yarn_strings
	var result: PackedStringArray = _serialize_lines(line_infos)
	var strings: String = String("\n").join(result)

	file = FileAccess.open(strings_path, FileAccess.WRITE)
	file.store_line(strings)
	file.close()

	var otherfile = FileAccess.open(file_path, FileAccess.WRITE)
	var prog = YarnProgram.new() if program == null else program
	var serialized_program: Dictionary = _serialize_program(prog)
	otherfile.store_line(var_to_str(serialized_program))
	otherfile.close()

	pass


## Creates a TSV (tab-separated values) array of stored strings.
## The first line contains headers of the columns, all
## following lines contain yarn_string_container objects
## converted to a TSV row.
static func _serialize_lines(lines: Dictionary) -> PackedStringArray:
	# lines has the types [String, LineInfo] -> (ID, string+metadata)
	var line_texts: PackedStringArray = []
	var headers := PackedStringArray(["id", "text", "file", "node", "lineNumber", "implicit", "tags"])
	line_texts.append(String(STRINGS_DELIMITER).join(headers))
	for line_id in lines.keys():
		var line: LineInfo = lines[line_id]
		var line_info: PackedStringArray = []
		line_info.append(line_id)
		line_info.append(line.text)
		line_info.append(line.file_name)
		line_info.append(line.node_name)
		line_info.append(String.num_int64(line.line_number, 10))
		line_info.append("implicit" if line.is_implicit else "")
		line_info.append(String(" ").join(line.meta))

		line_texts.append(String(STRINGS_DELIMITER).join(line_info))

	return line_texts


## Creates a Dictionary object from the given program.
## The dictionary is of the form [String, /] -> (id, object)
static func _serialize_program(program: YarnProgram) -> Dictionary:
	var result: Dictionary = {} # type [String, /] -> (id, object)
	result[PROGRAM_NAME] = program.program_name
	# result[PROGRAM_LINE_INFO] = program._line_infos
	result[PROGRAM_NODES] = _serialize_all_nodes(program.yarn_nodes)

	return result


## Combine all the programs in the provided array into a new yarn program.
## Returns null of there are any duplicate node names.
static func combine_programs(programs: Array[YarnProgram] = []) -> YarnProgram:
	if programs.is_empty():
		printerr("No programs to combine.")
		return null

	var p: YarnProgram = YarnProgram.new()
	for program in programs:
		for node_key in program.yarn_nodes.keys():
			if p.has_yarn_node(node_key):
				printerr("Program with duplicate node names %s " % node_key)
				return null
			p.yarn_nodes[node_key] = program.yarn_nodes[node_key]

			YarnGlobals.get_script().copy_directory(p.yarn_strings, program.yarn_strings)

	return p


## Creates a Dictionary object from all of the given compiled nodes.
## The dictionary is of the form [String, /] -> (id, object)
static func _serialize_all_nodes(nodes: Dictionary) -> Array[Dictionary]:
	# type of nodes is [String, CompiledYarnNode] -> (id, compiled yarn node)
	var result: Array[Dictionary] = []

	for node in nodes.values():
		var node_data: Dictionary = {}
		# node_name : String
		# instructions : Array = []
		# labels : Dictionary
		# tags: Array[String]
		# source_id : String

		node_data[NODE_NAME] = (node as CompiledYarnNode).node_name
		node_data[NODE_INSTRUCTIONS] = _serialize_all_instructions((node as CompiledYarnNode).instructions as Array[Instruction])
		node_data[NODE_LABELS] = (node as CompiledYarnNode).labels
		node_data[NODE_TAGS] = (node as CompiledYarnNode).tags
		node_data[NODE_SOURCE_ID] = (node as CompiledYarnNode).source_id

		result.append(node_data)

	return result


## Creates a dictionary for each of the instruction objects in the
## array and accumulates them in an array. Returns that array.
static func _serialize_all_instructions(instructions: Array[Instruction]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instruction in instructions:
		var instruction_data: Dictionary = {}

		# var operation : int #bytcode
		# var operands : Array #Operands
		instruction_data[INSTRUCTION_OP] = (instruction as Instruction).operation
		instruction_data[INSTRUCTION_OPERANDS] = _serialize_all_operands((instruction as Instruction).operands)
		result.append(instruction_data)
	return result


## Creates a dictionary for each of the operand objects in the
## array and accumulates them in an array. Returns that array.
static func _serialize_all_operands(operands: Array[Operand]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for operand in operands:
		var operand_data: Dictionary = {}

		operand_data[OPERAND_TYPE] = operand.value_type
		operand_data[OPERAND_VALUE] = operand.value

		result.append(operand_data)

	return result


## Imports the program at the given file path.
## Returns null if no file exists. Prints errors if the
## associated string file isn't found.
static func _import_program(file_path: String) -> YarnProgram:
	var file : FileAccess # FileAccess used to open various files

	# get file path for the program's string file
	var strings_path = DEFAULT_STRINGS_FORMAT % [file_path.get_basename(), STRINGS_EXTENSION] # basename: full filepath without extension
	var localized_strings_path = (
		"%s-strings-%s.ots"
		% [file_path.get_basename(), TranslationServer.get_locale()]
	)
	
	# open strings file of this program
	if FileAccess.file_exists(localized_strings_path):
		file = FileAccess.open(localized_strings_path, FileAccess.READ)
	elif FileAccess.file_exists(strings_path):
		file = FileAccess.open(strings_path, FileAccess.READ)
	else:
		printerr(
			"No %s file found for the program [%s]! Either create one or recompile the program."
				% [strings_path, file_path.get_basename()]
		)
	
	# get stored strings (compiled line info data) from string file
	var line_info_data: PackedStringArray = file.get_as_text().split("\n")
	if file != null:
		file.close()
	line_info_data.remove_at(0) # remove header line
	
	# open program file
	file = FileAccess.open(file_path, FileAccess.READ)
	var program_data: Dictionary = str_to_var(file.get_as_text()) as Dictionary
	var strings_table: Dictionary = _load_line_infos(line_info_data)
	file.close()

	var program: YarnProgram = _load_program(program_data)
	program.yarn_strings = strings_table

	return program


## Deserialises a yarn program's yarn_string dictionary
## using the given TSV data.
static func _load_line_infos(line_info_data: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for line in line_info_data:
		if line.is_empty():
			continue
		var proccessedLine = line.split(STRINGS_DELIMITER)
		
		var line_id = proccessedLine[0]
		var text = proccessedLine[1].strip_escapes()
		var file_name = proccessedLine[2]
		var node_name = proccessedLine[3]
		var line_number = int(proccessedLine[4])
		var is_implicit = (proccessedLine[5] != '') #bool(proccessedLine[5])
		var meta = proccessedLine[6].split(" ")

		var info: LineInfo = LineInfo.new(text, node_name, line_number, file_name, is_implicit, meta)
		result[line_id] = info

	return result


## Deserialises a yarn program using the given data dictionary.
static func _load_program(program_data: Dictionary) -> YarnProgram:
	var program: YarnProgram = YarnProgram.new()

	program.program_name = program_data[PROGRAM_NAME]
	# program.yarnStrings = data[PROGRAM_LINE_INFO]
	program.yarn_nodes = _load_nodes(program_data[PROGRAM_NODES])

	return program


## Deserialises a yarn program's yarn_nodes dictionary
## using the given array of compiled nodes.
static func _load_nodes(serialised_nodes_data: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for node_data in serialised_nodes_data:
		var compiled_yarn_node: CompiledYarnNode = _load_node(node_data)
		result[compiled_yarn_node.node_name] = compiled_yarn_node
	return result


## Deserialises a serialised yarn node.
static func _load_node(node_data: Dictionary) -> CompiledYarnNode:
	var compiled_yarn_node: CompiledYarnNode = CompiledYarnNode.new()

	compiled_yarn_node.node_name = node_data[NODE_NAME]
	compiled_yarn_node.labels = node_data[NODE_LABELS]
	compiled_yarn_node.tags = node_data[NODE_TAGS]
	compiled_yarn_node.source_id = node_data[NODE_SOURCE_ID]
	compiled_yarn_node.instructions = _load_instructions(node_data[NODE_INSTRUCTIONS])

	return compiled_yarn_node


## Deserialises a compiled yarn node's stack of instructions.
static func _load_instructions(instructions_data: Array[Dictionary]) -> Array[Instruction]:
	var result: Array[Instruction] = []

	for instruction_data in instructions_data:
		result.append(_load_instruction(instruction_data))

	return result


## Deserialises a compiled instruction from a dictionary.
static func _load_instruction(instruction_data: Dictionary) -> Instruction:
	var operation: int = instruction_data[INSTRUCTION_OP]
	var operands: Array[Operand] = _load_operands(instruction_data[INSTRUCTION_OPERANDS])

	var loaded_instruction: Instruction = Instruction.new()

	loaded_instruction.operation = operation
	loaded_instruction.operands = operands

	return loaded_instruction


## Deserialises an instruction's operands array from a data array.
static func _load_operands(operands_data: Array[Dictionary]) -> Array[Operand]:
	var result: Array[Operand] = []
	for operand_data in operands_data:
		result.append(_load_operand(operand_data))

	return result


## Deserialises an instruction's operand.
static func _load_operand(operand_data: Dictionary) -> Operand:
	var value = operand_data[OPERAND_VALUE]

	var value_type: int = operand_data[OPERAND_TYPE]
	match value_type:
		Operand.ValueType.StringValue, Operand.ValueType.None:
			pass
		Operand.ValueType.FloatValue:
			value = float(value)
		Operand.ValueType.BooleanValue:
			value = bool(value)

	var op: Operand = Operand.new(value)

	return op
