## Software component which converts a string of yarn code into a yarn program.
##
## The compiler uses the lexer to turn the string of yarn code into tokens,
## the parser to turn the tokens into yarn nodes, and finally converts these
## nodes into a series of instructions that define the execution of these
## nodes.
## The compiled yarn program consists mainly of a set of compiled nodes (containing
## the stack of their respective instructions among a few other things) and a
## dictionary of stored strings (mainly the displayed text).

# const YarnGlobals = preload("res://addons/godyarnit/autoloads/execution_states.gd")

const Parser = preload("res://addons/godyarnit/core/compiler/parser.gd")
const Lexer = preload("res://addons/godyarnit/core/compiler/lexer.gd")
const LineInfo = preload("res://addons/godyarnit/core/program/yarn_string_container.gd")
const CompiledYarnNode = preload("res://addons/godyarnit/core/program/compiled_yarn_node.gd")
const Instruction = preload("res://addons/godyarnit/core/program/instruction.gd")
const YarnProgram = preload("res://addons/godyarnit/core/program/program.gd")
const Operand = preload("res://addons/godyarnit/core/program/operand.gd")

# patterns
const INVALID_TITLE_PATTERN = "[\\[<>\\]{}\\|:\\s#\\$]"

# ERROR Codes
const NO_ERROR: int = 0x00
const LEXER_FAILURE: int = 0x01
const PARSER_FAILURE: int = 0x02
const INVALID_HEADER: int = 0x04
const DUPLICATE_NODES_IN_PROGRAM: int = 0x08
const ERR_COMPILATION_FAILED: int = 0x10

var error = OK

var _errors: int
var _last_error: int

var _print_logs: bool

var _current_node: CompiledYarnNode
var _is_raw_text: bool
var _program: YarnProgram
var _source_code_path: String
var _contains_implicit_string_tags: bool
var _label_count: int = 0

var _registered_string_table: Dictionary = {} # type [string, LineInfo] -> (id: string+metadata) -> contains strings required for running the yarn program, e.g. all the displayed text
var _implicit_string_count: int = 0 # number of stored strings with an ID generated at compilation time

var _tokens: Dictionary = {} # type [int, YarnGlobals.TokenType]


## Takes a yarn source code string and
## converts each of its dialogues into lexical tokens (using the lexer script),
## then converts these tokens into Parser.YarnDialogueNode objects (using the parser script),
## and finally converts the yarn nodes into a compiled program (using this compiler script),
## i.e. a sequence of instructions and values on a stack.
## Returns OK or an error code.
func compile_string(
	source_code: String,
	source_code_path: String,
	show_tokens: bool = false,
	print_tree: bool = false,
	print_logs: bool = false
) -> Error:
	_source_code_path = source_code_path
	_print_logs = print_logs

	# parse header
	var header_separator: RegEx = RegEx.new()
	header_separator.compile("---(\r\n|\r|\n)")
	var header_property: RegEx = RegEx.new()
	header_property.compile("(?<field>.*): *(?<value>.*)")

	if !header_separator.search(source_code):
		printerr("Compiler.compile_string: no headers found in file %s -> aborted." % source_code_path)
		return ERR_FILE_UNRECOGNIZED

	# prepare source code: separate into lines and remove unneeded whitespace
	var source_lines: PackedStringArray = source_code.split("\n", true)
	for i in range(source_lines.size()):
		source_lines[i] = source_lines[i].strip_edges(false, true) # keep indents on left, remove whitespace on right

	# convert source code into YarnParser.YarnDialogueNode objects
	# each dialogue in the source code will be converted into
	# a separate tree of yarn nodes
	var dialogue_root_nodes: Array[YarnParser.YarnDialogueNode] = []
	var line_number: int = 0
	var body_start_line: int
	while line_number < source_lines.size():
		var dialogue_title: String
		var dialogue_body: String

		# get title: in the header, search for a property called "title".
		# it will be of the form "title: [value]"
		var headers_parsed: bool = false
		var title_found: bool = false
		while line_number < source_lines.size():
			var current_line: String = source_lines[line_number]
			line_number += 1

			if !current_line.is_empty():
				var header_result = header_property.search(current_line)
				if header_result != null:
					var field: String = header_result.get_string("field")
					var value: String = header_result.get_string("value")

					if field == "title":
						# title property found!
						dialogue_title = value
						title_found = true
						if print_logs: print("Compiler: title found in line %d: %s" % [line_number, dialogue_title])
						# no not break here; read the rest of the header to correctly update line_number

			if line_number >= source_lines.size() || source_lines[line_number] == "---":
				headers_parsed = true
				if print_logs: print("Compiler: end of headers found in line %d" % [line_number])
				break

		if not headers_parsed:
			printerr("Compiler.compile_string: no headers found in file %s -> aborted." % source_code_path)
			return ERR_FILE_UNRECOGNIZED
		if not title_found:
			printerr("Compiler.compile_string: no title found in file %s -> aborted." % source_code_path)
			return ERR_FILE_UNRECOGNIZED

		# past header

		line_number += 1 # skip the "---" line
		body_start_line = line_number

		# get lines in body
		var body_lines: PackedStringArray = []
		while line_number < source_lines.size() && source_lines[line_number] != "===":
			body_lines.append(source_lines[line_number])
			line_number += 1
		dialogue_body = String("\n").join(body_lines)

		line_number += 1

		# run lexer on the body to convert it into Lexer.Token objects (lexical tokens)
		var lexer = Lexer.new()
		var tokens: Array = lexer.tokenize(dialogue_body, 0)
		if lexer.error != OK:
			printerr("Compiler.compile_string: failed to tokenize dialogue node [%s] in file: %s." % [dialogue_title, source_code_path])
			return lexer.error

		if show_tokens:
			print_tokens(dialogue_title, tokens)

		#print("TOKENS OF DIALOGUE %d CREATED SUCCESSFULLY" % [dialogue_root_nodes.size()])
		#return ERR_UNAVAILABLE

		# run parser on the tokens to convert them into YarnParser.YarnDialogueNode objects
		var parser = Parser.new(tokens, print_logs)
		var root_node: YarnParser.YarnDialogueNode = parser.parse_node(dialogue_title, body_start_line) # automatically creates tree of yarn nodes using the tokens
		if parser.error != OK:
			printerr("Failed to parse dialogue node [%s] in file: %s." % [dialogue_title, source_code_path])
			return parser.error

		if print_tree:
			print(root_node.get_tree_string(0))

		dialogue_root_nodes.append(root_node)
		while line_number < source_lines.size() and source_lines[line_number].is_empty():
			line_number += 1

		# -> parse next dialogue

	# finished parsing nodes
	#print("Finished parsing: %d nodes parsed." % [dialogue_root_nodes.size()])

	# compile nodes into a program (set of instructions and values on a stack)
	_program = YarnProgram.new()
	for node in dialogue_root_nodes:
		compile_node(node)
		if error != OK:
			printerr("Compiler.compile_string: failed to compile dialogue node %s in file: %s %s" % [
				node.dialogue_section_name,
				source_code_path,
				node.get_location_string()
			])
			return error
		elif print_logs:
			print("Compiler: compiled dialogue %s. Final number of instructions: %d" % [
				node.dialogue_section_name,
				(_program.yarn_nodes[node.dialogue_section_name] as CompiledYarnNode).instructions.size()
			])

	copy_registered_strings(_program.yarn_strings, _registered_string_table)
	
	return OK


## Copies the strings stored in the registered string table
## to the target dictionary (in a yarn program).
static func copy_registered_strings(target: Dictionary, patch: Dictionary):
	for key in patch.keys():
		target[key] = patch[key]


## Compiles the instructions for a yarn node by compiling
## all statements within and options (other linked dialogues).
## This will first be called on each dialogue root node.
func compile_node(parsed_node: YarnParser.YarnDialogueNode) -> void:
	if _print_logs: print("Compiler: compiling dialogue node %s (%d statements)" % [
		parsed_node.dialogue_section_name,
		parsed_node.statements.size()
	])

	if _program.yarn_nodes.has(parsed_node.dialogue_section_name):
		# emit_error(DUPLICATE_NODES_IN_PROGRAM)
		error = ERR_ALREADY_EXISTS
		printerr("Duplicate node in program: %s" % parsed_node.dialogue_section_name)
		return
	
	var compiled_node: CompiledYarnNode = CompiledYarnNode.new()

	compiled_node.node_name = parsed_node.dialogue_section_name
	compiled_node.tags = parsed_node.tags

	# raw text
	if parsed_node.source != null and not parsed_node.source.is_empty():
		# node provides a source -> store as string under the ID "line:[dialogue name]"
		#print("\tNode provides a source (%s) -> storing string under line:%s" % [
			#parsed_node.source,
			#parsed_node.dialogue_section_name
		#])
		compiled_node.source_id = register_string(
			parsed_node.source,
			parsed_node.dialogue_section_name,
			"line:" + parsed_node.dialogue_section_name,
			0,
			[]
		)
	else:
		# compile node
		var start_label: String = register_label()
		add_instruction(YarnGlobals.ByteCode.Label, compiled_node, [Operand.new(start_label)])

		for statement in parsed_node.statements:
			compile_statement(compiled_node, statement) # automatically parses the entire node tree belonging to this statement
			if error != OK:
				printerr("Compiler.compile_node: failed to compile statement for dialogue %s %s" % [
					parsed_node.dialogue_section_name,
					statement.get_location_string()
				])
				return
			#else:
				#print("\tCompiled statement. Current number of instructions: %d" % [compiled_node.instructions.size()])
		
		# add options
		# TODO: add parser flag

		# var hasOptions : bool = false

		# for instruction in nodeCompiled.instructions :
		# 	if instruction.operation == YarnGlobals.ByteCode.AddOption:
		# 		hasOptions = true
		# 	if instruction.operation == YarnGlobals.ByteCode.ShowOptions:
		# 		hasOptions = false

		# dialogue has finished
		if !parsed_node.has_options:
			# no options (= other dialogues that are linked in this one) -> stop
			add_instruction(YarnGlobals.ByteCode.Stop, compiled_node)
		else:
			# options found -> show option text, then jump to selected
			add_instruction(YarnGlobals.ByteCode.ShowOptions, compiled_node)
			add_instruction(YarnGlobals.ByteCode.RunNode, compiled_node)

	_program.yarn_nodes[parsed_node.dialogue_section_name] = compiled_node


## Stores a provided string (along with some other info) in the
## _registered_string_table member.
## If an ID is provided, that ID will be the key in the string table,
## otherwise an ID is generated.
## Returns the ID that will be used as the key.
## The strings in the string table will be made available to the
## compiled yarn program for use during runtime.
## For example, this method is used to store all the displayed text.
func register_string(
	text_to_store: String,
	node_name: String,
	id: String = "",
	line_number: int = -1,
	tags: PackedStringArray = []
) -> String:
	var used_line_id: String

	var is_implicit: bool

	if id.is_empty():
		# generate an implicit tag
		# they are not saved and are generated
		# aka dummy tags that change on each compilation

		used_line_id = "%s-%s-%d" % [_source_code_path.get_file(), node_name, _implicit_string_count]
		_implicit_string_count += 1
		_contains_implicit_string_tags = true
		is_implicit = true
	else:
		used_line_id = id
		is_implicit = false

	var stored_string_info: LineInfo = LineInfo.new(
		text_to_store, node_name, line_number, _source_code_path.get_file(), is_implicit, tags
	)
	_registered_string_table[used_line_id] = stored_string_info

	return used_line_id


## Increments the number of registered labels.
## Returns a string of the form "L[label index][comment]"
func register_label(comment: String = "") -> String:
	_label_count += 1
	return "L%d%s" % [_label_count, comment]


## Appends an instruction, consisting of an operation (bytecode)
## on the given operands, to the given node's instruction list.
## If the operation is YarnGlobals.ByteCode.Label, the label is
## also added to the node's label table.
func add_instruction(op_bytecode: int, compiled_node: CompiledYarnNode = _current_node, operands: Array[Operand] = []):
	var instruction: Instruction = Instruction.new(null)
	instruction.operation = op_bytecode
	instruction.operands = operands
	# print("emitting instruction to %s" % node.node_name)

	if compiled_node == null:
		printerr("trying to emit to null node with byte code: %s" % op_bytecode)
		error = ERR_INVALID_PARAMETER
		return
	compiled_node.instructions.append(instruction)
	if op_bytecode == YarnGlobals.ByteCode.Label:
		# add to label table (use label name as key, output label position in instruction set)
		compiled_node.labels[instruction.operands[0].value] = compiled_node.instructions.size() - 1
	pass


# NOT IMPLEMENTED
func get_string_tokens() -> Array:
	return []


# compile header (NOT IMPLEMENTED)
func compile_header():
	pass


## Compiles the instructions for a statement (if statement, assignment, line,...).
## This will walk through all child branches
## of the parse tree.
func compile_statement(node: CompiledYarnNode, statement: YarnParser.Statement) -> void:
	#print("compiling statement")
	match statement.statement_type:
		YarnGlobals.StatementTypes.Command:
			compile_command(node, statement.command)
		YarnGlobals.StatementTypes.ShortcutOptionGroup:
			compile_shortcut_group(node, statement.shortcut_option_group)
		YarnGlobals.StatementTypes.Block:
			compile_block(node, statement.block.statements)
		YarnGlobals.StatementTypes.IfStatement:
			compile_if(node, statement.if_statement)
		YarnGlobals.StatementTypes.OptionStatement:
			compile_option(node, statement.option_statement)
		YarnGlobals.StatementTypes.AssignmentStatement:
			compile_assignment(node, statement.assignment)
		YarnGlobals.StatementTypes.Line:
			compile_line(node, statement, statement.line)
		_:
			error = ERR_COMPILATION_FAILED
			printerr("Compiler.compile_statement: illegal statement type [%s] - could not generate code" % statement.type)

## Compiles the instructions for a block.
## Blocks are a group of statements.
func compile_block(node: CompiledYarnNode, statements: Array[YarnParser.Statement] = []):
	#print("compiling block")
	if not statements.is_empty():
		for statement in statements:
			compile_statement(node, statement)


## Compiles the instructions for an if statement.
func compile_if(node: CompiledYarnNode, if_statement: YarnParser.IfStatement):
	#print("compiling if")

	# jump to label at the end of every clause
	var endif_label: String = register_label("endif")

	for clause in if_statement.clauses:
		var end_of_clause_label: String = register_label("end_of_clause")

		if clause.expression != null:
			# compile condition evaluation
			compile_expression(node, clause.expression)
			add_instruction(YarnGlobals.ByteCode.JumpIfFalse, node, [Operand.new(end_of_clause_label)])

		# For when the condition is fulfilled, compile block of follow-up statements.
		# Afterwards, jump to the end of the if statement.
		compile_block(node, clause.statements)
		add_instruction(YarnGlobals.ByteCode.JumpTo, node, [Operand.new(endif_label)])

		if clause.expression != null:
			# if there was a condition evaluation, this is where the instruction pointer
			# will jump to -> evaluate next clause
			add_instruction(YarnGlobals.ByteCode.Label, node, [Operand.new(end_of_clause_label)])
			add_instruction(YarnGlobals.ByteCode.Pop, node)

	add_instruction(YarnGlobals.ByteCode.Label, node, [Operand.new(endif_label)])


## Compiles the instructions for a shortcut option group.
func compile_shortcut_group(node: CompiledYarnNode, shortcut_group: YarnParser.ShortcutOptionGroup):
	# print("compiling shortcutoptopn group")
	var group_end_label: String = register_label("group_end")

	var labels: Array[String] = []

	var option_count: int = 0

	for option in shortcut_group.options:
		var option_index_label: String = register_label("option_%s" % [option_count + 1]) # used for finding the correct sub-block later
		labels.append(option_index_label)

		var end_of_clause_label: String = ""

		if option.option_condition != null:
			# compile this shortcut option's condition
			end_of_clause_label = register_label("conditional_%s" % option_count)
			compile_expression(node, option.option_condition)
			add_instruction(YarnGlobals.ByteCode.JumpIfFalse, node, [Operand.new(end_of_clause_label)])

		var expression_count: int = option.option_line.substitutions.size()

		while !option.option_line.substitutions.is_empty():
			# compile any expressions within the shortcut option's text line
			var inline_format_expression: Parser.ParseNode = option.option_line.substitutions.pop_back() # can be InlineExpression or FormatExpression
			# TODO FIXME: ^ this might cause problems, because if this is a FormatExpression, expression_value is an InlineExpression, not an ExpressionNode!
			compile_expression(node, inline_format_expression.expression_value)

		# register the line of text for this option
		var line_id: String = option.option_line.line_id
		var registered_line_id_string: String = register_string(
			option.option_line.line_text, node.node_name, line_id, option.node_line_number, node.tags
		)

		add_instruction(
			YarnGlobals.ByteCode.AddOption,
			node,
			[Operand.new(registered_line_id_string), Operand.new(option_index_label), Operand.new(expression_count)]
		)

		if option.option_condition != null:
			# this is where the instruction pointer should jump to if the option's condition isn't met
			# -> next shortcut option
			add_instruction(YarnGlobals.ByteCode.Label, node, [Operand.new(end_of_clause_label)])
			add_instruction(YarnGlobals.ByteCode.Pop, node)

		option_count += 1

	# at this point, all options whose conditions are met should be displayed
	add_instruction(YarnGlobals.ByteCode.ShowOptions, node)
	add_instruction(YarnGlobals.ByteCode.Jump, node)

	option_count = 0

	# compile the (optional) sub-block belonging to each option
	for option in shortcut_group.options:
		add_instruction(YarnGlobals.ByteCode.Label, node, [Operand.new(labels[option_count])]) # push option_index_label

		if option.sub_node != null:
			# compile sub-block of this shortcut option
			compile_block(node, option.sub_node.statements)

		# after the sub-block has been executed (or if there is no sub-block),
		# jump to the end of the shortcut option group
		add_instruction(YarnGlobals.ByteCode.JumpTo, node, [Operand.new(group_end_label)])
		option_count += 1

	# this is the end of option group
	add_instruction(YarnGlobals.ByteCode.Label, node, [Operand.new(group_end_label)])
	# clean up
	add_instruction(YarnGlobals.ByteCode.Pop, node)


## Compiles instructions for a line node.
func compile_line(node: CompiledYarnNode, statement: YarnParser.Statement, line: YarnParser.LineNode):
	# giving me a LineNoda
	#              - line_text : String
	#              - substitutions : Array[ParseNode]  (can be either InlineExpression or FormatFunction)

	var expression_count: int = line.substitutions.size()
	while !line.substitutions.is_empty():
		# compile any inline or format expressions
		var inline_format_expression = line.substitutions.pop_back() # can be either InlineExpression or FormatFunction
		# TODO FIXME: ^ this might cause problems because if it's a FormatFunction, expression_value is an InlineExpression, not an ExpressionNode
		compile_expression(node, inline_format_expression.expression_value)

	var registered_line_id: String = register_string(
		line.line_text, node.node_name, line.line_id, statement.node_line_number, line.tags
	)
	add_instruction(YarnGlobals.ByteCode.RunLine, node, [Operand.new(registered_line_id), Operand.new(expression_count)])


## Compiles instructions for an option (link to another dialogue).
func compile_option(node: CompiledYarnNode, option: YarnParser.OptionStatement):
	#print("compiling option")
	var destination_node_name: String = option.destination_node_name

	if !option.displayed_line:
		# directly jump to destination node
		add_instruction(YarnGlobals.ByteCode.RunNode, node, [Operand.new(destination_node_name)])
	else:
		# display option text, link destination node
		var line_id: String = option.displayed_line.line_id
		var registered_line_id = register_string(
			option.displayed_line.line_text, node.node_name, line_id, option.node_line_number, option.displayed_line.tags
		)

		var expression_count: int = option.displayed_line.substitutions.size()

		while !option.displayed_line.substitutions.is_empty():
			# compile expressions contained in the line
			var inline_format_expression = option.displayed_line.substitutions.pop_back() # can be InlineExpression or FormatExpression
			# TODO FIXME: ^ this may cause problems because if this is a FormatExpression, expression_value is an InlineExpression, not an ExpressionNode!
			compile_expression(node, inline_format_expression.expression_value)

		add_instruction(
			YarnGlobals.ByteCode.AddOption,
			node,
			[Operand.new(registered_line_id), Operand.new(destination_node_name), Operand.new(expression_count)]
		)


## Compiles instructions for a command.
func compile_command(node: CompiledYarnNode, command: YarnParser.Command):
	#print("compiling command")

	if command.command_type == Parser.Command.Type.ExpressionCommand:
		# compile custom command (function) call
		compile_expression(node, command.expression_command)
	else:
		# compile built-in command call
		
		if command.built_in_command_args.is_empty():
			# put the number of (lack of) args to stack
			add_instruction(YarnGlobals.ByteCode.PushNumber, node, [Operand.new(0)])
		else:
			# evaluate all parameters
			for arg in command.built_in_command_args:
				if arg is Parser.ExpressionNode:
					compile_expression(node, arg as Parser.ExpressionNode)
				elif arg is Parser.ValueNode:
					compile_value(node, arg as Parser.ValueNode)
				else:
					printerr("Compiler.compile_command: unrecognised type for build-in command arg in node %s %s" % [
						node.node_name,
						arg.get_location_string()
					])

			# put the number of of args to stack
			add_instruction(YarnGlobals.ByteCode.PushNumber, node, [Operand.new(command.built_in_command_args.size())])
		
		# call command
		var command_name = command.built_in_command
		add_instruction(YarnGlobals.ByteCode.RunCommand, node, [Operand.new(command_name)])


## Compiles instructions for assigning values.
func compile_assignment(node: CompiledYarnNode, assignment: YarnParser.Assignment):
	#print("compiling assignment")

	if assignment.operation_type == YarnGlobals.TokenType.EqualToOrAssign:
		# evaluate the expression to a value for the stack
		compile_expression(node, assignment.value)
	else:
		# this is combined operation
		# get value of var
		add_instruction(YarnGlobals.ByteCode.PushVariable, node, [Operand.new(assignment.variable_name)])

		# evaluate the expression and push value to stack
		compile_expression(node, assignment.value)

		# stack contains old value and result

		match assignment.operation_type:
			YarnGlobals.TokenType.AddAssign:
				add_instruction(
					YarnGlobals.ByteCode.CallFunc,
					node,
					[Operand.new(YarnGlobals.token_name(YarnGlobals.TokenType.Add))]
				)
			YarnGlobals.TokenType.MinusAssign:
				add_instruction(
					YarnGlobals.ByteCode.CallFunc,
					node,
					[Operand.new(YarnGlobals.token_name(YarnGlobals.TokenType.Minus))]
				)
			YarnGlobals.TokenType.MultiplyAssign:
				add_instruction(
					YarnGlobals.ByteCode.CallFunc,
					node,
					[Operand.new(YarnGlobals.token_name(YarnGlobals.TokenType.MultiplyAssign))]
				)
			YarnGlobals.TokenType.DivideAssign:
				add_instruction(
					YarnGlobals.ByteCode.CallFunc,
					node,
					[Operand.new(YarnGlobals.token_name(YarnGlobals.TokenType.DivideAssign))]
				)
			_:
				printerr("Compiler.compile_assignment: invalid assignment operator detected while compiling assignment: %d (node %s)" % [
					assignment.operation_type,
					node.node_name
				])
				error = ERR_INVALID_DATA

	# stack contains destination value
	# store the top of the stack in variable
	add_instruction(YarnGlobals.ByteCode.StoreVariable, node, [Operand.new(assignment.variable_name)])

	#clean stack
	add_instruction(YarnGlobals.ByteCode.Pop, node)


## Compiles instructions for an expression.
func compile_expression(node: CompiledYarnNode, expression: YarnParser.ExpressionNode):
	#print("compiling expression")

	match expression.expression_type:
		YarnGlobals.ExpressionType.Value:
			compile_value(node, expression.value)
		YarnGlobals.ExpressionType.FunctionCall:
			# evaluate all parameters
			for param in expression.function_params:
				compile_expression(node, param)

			# put the number of of params to stack
			add_instruction(YarnGlobals.ByteCode.PushNumber, node, [Operand.new(expression.function_params.size())])

			# call function
			add_instruction(YarnGlobals.ByteCode.CallFunc, node, [Operand.new(expression.function_name)])
		_:
			printerr("Compiler.compile_expression: invalid expression type %d (node %s)" % [
				expression.expression_type,
				node.node_name
			])
			error = ERR_INVALID_DATA

	pass


## Compiles instructions for a value.
func compile_value(node: CompiledYarnNode, value_node: YarnParser.ValueNode):
	#print("compiling value")

	# push value to stack
	match value_node.value.type:
		YarnGlobals.ValueType.Number:
			add_instruction(YarnGlobals.ByteCode.PushNumber, node, [Operand.new(value_node.value.as_number())])
		YarnGlobals.ValueType.Str:
			var id: String = register_string(
				value_node.value.as_string(), node.node_name, "", value_node.node_line_number, []
			)
			add_instruction(YarnGlobals.ByteCode.PushString, node, [Operand.new(id)])
		YarnGlobals.ValueType.Boolean:
			add_instruction(YarnGlobals.ByteCode.PushBool, node, [Operand.new(value_node.value.as_bool())])
		YarnGlobals.ValueType.Variable:
			add_instruction(YarnGlobals.ByteCode.PushVariable, node, [Operand.new(value_node.value.variable)])
		YarnGlobals.ValueType.Nullean:
			add_instruction(YarnGlobals.ByteCode.PushNull, node)
		_:
			printerr("Compiler.compile_value: unrecognized value node type: %s (node %s)" % [
				value_node.value.type,
				node.node_name
			])
			error = ERR_INVALID_DATA


## Gets the error flags.
func get_errors() -> int:
	return _errors


## Gets the last error code reported.
func get_last_error() -> int:
	return _last_error


func clear_errors() -> void:
	_errors = NO_ERROR
	_last_error = NO_ERROR


#func emit_error(error : int)->void:
#	_lastError = error
#	_errors |= _lastError


## Prints the tokens in the given token array.
static func print_tokens(node_name: String, tokens: Array[Lexer.Token] = []):
	var list: PackedStringArray = []
	for token in tokens:
		list.append(
			(
				"\t [%14s] %s (%s|line %s)\n" % [
					token.lexer_state,
					YarnGlobals.get_script().get_token_type_name(token.token_type),
					token.value,
					token.line_number
				]
			)
		)
	print("Node [%s] Tokens:" % node_name)
	print(String("").join(list))
