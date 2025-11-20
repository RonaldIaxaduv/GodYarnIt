## Software component which converts the lexical tokens (produced by the lexer) into a data structure.
##
## Sets up higher-level Yarn Script objects, e.g. for If blocks, Options etc.
class_name YarnParser # gave this a class name for better typing in the subclasses of this script

# const YarnGlobals = preload("uid://cmp2ukbwmdp12") # execution_states.gd
const Lexer = preload("uid://chwwhyiwk8nxm") # lexer.gd


var error = OK
var current_node_name: String = "Start"
var enable_logs: bool

var _tokens: Array[Lexer.Token] = []


func _init(tokens: Array[Lexer.Token], enable_logs: bool):
	self._tokens = tokens
	self.enable_logs = enable_logs


## Create a tree of yarn nodes using the currently available
## tokens. The root node will have the given name.
## This will first be called in the compiler.gd script after the
## tokens have been set to the tokens created from the body of a
## dialogue. The name of the root note will be set to the title
## of that dialogue (stated in the header).
func parse_node(root_name: String = "Start", starting_line_number: int = 0) -> YarnDialogueNode:
	current_node_name = root_name
	return YarnDialogueNode.new(root_name, starting_line_number, self) # this automatically creates sub nodes using the tokens!


## Checks whether the next token in the _tokens array is of the same type
## as any of the types passed in the valid_types array.
## The line number can be checked for as well. (Set it to -1 to ignore it.)
func next_token_is(valid_types: Array[int], line_number: int = -1) -> bool:
	var type: int = self._tokens.front().token_type
	for valid_type in valid_types:
		if type == valid_type && (line_number == -1 || line_number == self._tokens.front().line_number):
			return true
	return false


## Provides an array of valid token types and checks whether the upcoming
## tokens in the _tokens array are of the exact same types in the same order
## as in the passed array.
## Used to look ahead for `<<` and `else`.
func next_tokens_are(target_types: Array[int], line_number: int = -1) -> bool:
	assert(target_types.size() > 0) # target token types were unexpectedly empty!
	assert(_tokens.size() > 0) # if this breaks: Token stack was unexpectedly empty!
	assert(_tokens.size() >= target_types.size()) # if this breaks: Token stack was smaller than the given target token types!

	var temp_tokens: Array[Lexer.Token] = []
	temp_tokens.append_array(_tokens)

	for type in target_types:
		if temp_tokens.pop_front().token_type != type:
			return false
	return line_number == -1 or line_number == self._tokens.front().line_number


## Pops the token at the top of the _tokens array.
## If the token type matches any in the given array, it outputs the popped token.
## If there are no matches, an error is printed and null returned.
func pop_token(origin_node_name: String = "") -> Lexer.Token:
	var front_token: Lexer.Token = _tokens.pop_front()

	if front_token.token_type != YarnGlobals.TokenType.EndOfInput:
		# simply output front token
		return front_token
	else:
		# no front token remaining -> unexpected error!
		printerr("Parser.pop_token: unexpected end of input%s" % [" for " + origin_node_name if origin_node_name != "" else ""])
		if origin_node_name == "":
			print_stack()
		error = ERR_INVALID_DATA
		return null

func try_pop_token_type(expected_token_types: Array[int] = [], origin_node_name: String = "") -> Lexer.Token:
	if expected_token_types.size() == 0:
		return pop_token()

	var front_token: Lexer.Token = self._tokens.pop_front() as Lexer.Token

	for expected_token_type in expected_token_types:
		if front_token.token_type == expected_token_type:
			return front_token

	# failed to pop given token type -> print error

	var expected_types: String = ""
	for i in range(0, expected_token_types.size()):
		expected_types += YarnGlobals.get_script().get_token_type_name(expected_token_types[i])
		if i < expected_token_types.size() -1:
			expected_types += " | "

	printerr(
		(
			"Parser.try_pop_token_type: expected [%s] but got [%s] @(%s,%s)%s"
			% [
				expected_types,
				YarnGlobals.get_script().get_token_type_name(front_token.token_type),
				front_token.line_number,
				front_token.offset,
				" for " + origin_node_name if origin_node_name != "" else ""
			]
		)
	)
	print_stack()
	error = ERR_INVALID_DATA
	return null


# static func tab(indentLevel : int , input : String,newLine : bool = true)->String:
# 	return ("%*s| %s%s"% [indentLevel*2,"",input,("" if !newLine else "\n")])


## Gets the current list of lexical tokens in the parser.
func get_tokens() -> Array[Lexer.Token]:
	return _tokens


## A (tree) node containing a line number and tags as well as some useful methods.
##
## A (tree) node containing a line number and tags as well as some useful methods.
@abstract
class ParseNode:
	var parent: ParseNode
	var node_line_number: int ## equal to the line number of the frontmost token when this node was created
	var source_code_line_number: int
	var tags: Array[String]

	func _init(parent: ParseNode, parser: YarnParser):
		self.parent = parent

		var tokens: Array = parser.get_tokens() as Array
		if tokens.size() > 0:
			node_line_number = tokens.front().line_number
		else:
			node_line_number = -1

		if parent == null:
			source_code_line_number = node_line_number
		else:
			source_code_line_number = parent.source_code_line_number + node_line_number

		tags = []

	@abstract
	func get_tree_string(indentLevel: int) -> String

	func get_location_string() -> String:
		return "@[line:%d]" % [source_code_line_number + 1] # source line numbers should begin with 1

	## If this node is a DialogueSectionNode, this returns the node itself.
	## If this node isn't a DialogueSectionNode, it will return the first parent that is a DialogueSectionNode.
	## If no parent is a DialogueSectionNode, it returns null.
	func get_closest_dialogue_section_parent() -> YarnParser.DialogueSectionNode:
		var node = self
		while node != null:
			if node is YarnParser.DialogueSectionNode:
				return node as YarnParser.DialogueSectionNode
			node = node.parent
		return null

	## Returns the given string with the given indentation depth applied to it.
	## Optionally appends a line break.
	func apply_tab(indent_level: int, input: String, append_line_break: bool = true) -> String:
		var tab_precursor = ""
		var indent_spacing = 3
		for i in range(indent_level):
			tab_precursor += "|%*s" % [indent_spacing, ""]

		return "%*s %s%s" % [indent_level, tab_precursor, input, "\n" if append_line_break else ""]

	func set_parent(parent: ParseNode):
		self.parent = parent


## A class for handling header info.
##
## Subclass of ParseNode.
## TODO UNIMPLEMENTED.
## might be worth handling this through the parser instead as a pre-process step
## we handle header information before we begin parsing content
@abstract
class Header:
	extends ParseNode
	pass


## Root node of a Yarn dialogue.
class YarnDialogueNode:
	extends DialogueSectionNode

	func _init(dialogue_name: String, source_code_line_number: int, parser: YarnParser) -> void:
		super(dialogue_name, parent, parser, source_code_line_number)


## Represents a Yarn dialogue section at a fixed indent level.
## (I.e. an indented section of an if clause is another DialogueSectionNode.)
##
## Subclass of ParseNode.
class DialogueSectionNode:
	extends ParseNode

	var dialogue_section_name: String
	var source: String

	var editor_node_tags: Array[String] = []  ## tags defined in node header
	var statements: Array[Statement] = []
	var has_options: bool = false ## true if options ( [[text|dest_node]] ) are contained within this node

	## Initialises the node and its statements.
	func _init(dialogue_section_name: String, parent: ParseNode, parser: YarnParser, source_code_line_number: int = -1):
		super(parent, parser) # only copies some info, mainly first line number

		if source_code_line_number > -1:
			self.source_code_line_number = source_code_line_number

		self.dialogue_section_name = dialogue_section_name

		if parser.error != OK:
			printerr("DialogueSectionNode._init: detected error in dialogue %s %s -> aborted." % [
				dialogue_section_name,
				get_location_string()
			])
			return

		while parser.get_tokens().size() > 0 and parser.error == OK:
			# ignore any whitespace tokens
			while parser.next_token_is([ YarnGlobals.TokenType.Whitespace ] as Array[int]):
				parser.pop_token()

			# check if end of input has been reached
			if parser.next_token_is( [YarnGlobals.TokenType.Dedent, YarnGlobals.TokenType.EndOfInput] ):
				break

			# create next statement
			statements.append(Statement.new(self, parser))
			if parser.enable_logs: print("DialogueSectionNode: %s statement count: %d" % [dialogue_section_name, statements.size()])

		if parser.error != OK:
			printerr("DialogueSectionNode._init: detected error in dialogue %s %s -> aborted." % [
				dialogue_section_name,
				get_location_string()
			])

	## Returns all statements of this node as strings (multiline and with indents).
	func get_tree_string(indent_level: int) -> String:
		var info: PackedStringArray = []

		for statement in statements:
			info.append(statement.get_tree_string(indent_level + 1))

		return String("").join(info)


## A node representing one of a variety of statement classes.
##
## Subclass of ParseNode. Can represent a Block, if statement, option statement
## assignment, a shortcut option group, a custom command or a simple code line.
class Statement:
	extends ParseNode
	var Type = YarnGlobals.StatementTypes
	var statement_type: int

	# The class will try to instantiate exactly one of the following (or throw an error):
	var block: Block
	var if_statement: IfStatement
	var option_statement: OptionStatement
	var assignment: Assignment
	var shortcut_option_group: ShortcutOptionGroup
	var command: Command
	var line: LineNode

	## Initialises the statement and its type depending on the upcoming token(s).
	## Sets statement_type as well as one of the above variables.
	func _init(parent: ParseNode, parser: YarnParser):
		super(parent, parser)

		if parser.error != OK:
			printerr("Statement._init: detected error %s -> aborted." % [get_location_string()])
			return

		if Block.can_parse(parser):
			if parser.enable_logs: print("Statement: parsing a new block")
			block = Block.new(self, parser)
			statement_type = Type.Block
		elif IfStatement.can_parse(parser):
			if parser.enable_logs: print("Statement: parsing if statement")
			if_statement = IfStatement.new(self, parser)
			statement_type = Type.IfStatement
		elif OptionStatement.can_parse(parser):
			if parser.enable_logs: print("Statement: parsing an option statement")
			option_statement = OptionStatement.new(self, parser)
			statement_type = Type.OptionStatement
		elif Assignment.can_parse(parser):
			if parser.enable_logs: print("Statement: parsing an assignment statement")
			assignment = Assignment.new(self, parser)
			statement_type = Type.AssignmentStatement
		elif ShortcutOptionGroup.can_parse(parser):
			if parser.enable_logs: print("Statement: parsing a shortcut option group")
			shortcut_option_group = ShortcutOptionGroup.new(self, parser)
			statement_type = Type.ShortcutOptionGroup
		elif Command.can_parse(parser):
			if parser.enable_logs: print("Statement: parsing a command")
			command = Command.new(self, parser)
			statement_type = Type.Command
		elif LineNode.can_parse(parser):
			if parser.enable_logs: print("Statement: parsing text")
			#line = parser.try_pop_token_type([YarnGlobals.TokenType.Text]).value
			#statement_type = Type.Line
			line = LineNode.new(self, parser)
			statement_type = Type.Line
			#parser.try_pop_token_type([YarnGlobals.TokenType.EndOfLine])
		else:
			printerr("Statement._init: expected a statement but got %s instead. (Is there an incomplete if statement perhaps?) %s" % [
				parser.get_tokens().front()._to_string(),
				get_location_string()
			])
			parser.error = ERR_PARSE_ERROR
			return

		var tags: Array[String] = []

		# while parser.next_token_is([YarnGlobals.TokenType.TagMarker]):
		# 	parser.try_pop_token_type([YarnGlobals.TokenType.TagMarker])
		# 	var tag : String = parser.try_pop_token_type([YarnGlobals.TokenType.Identifier]).value
		# 	tags.append(tag)

		# if(tags.size()>0):
		# 	self.tags = tags

	## Returns a string representing this statement. Depends on the statement type.
	func get_tree_string(indent_level: int) -> String:
		var info: PackedStringArray = []

		match statement_type:
			Type.Block:
				info.append(block.get_tree_string(indent_level))
			Type.IfStatement:
				info.append(if_statement.get_tree_string(indent_level))
			Type.AssignmentStatement:
				info.append(assignment.get_tree_string(indent_level))
			Type.OptionStatement:
				info.append(option_statement.get_tree_string(indent_level))
			Type.ShortcutOptionGroup:
				info.append(shortcut_option_group.get_tree_string(indent_level))
			Type.Command:
				info.append(command.get_tree_string(indent_level))
			Type.Line:
				info.append(apply_tab(indent_level, line.get_tree_string(indent_level)))
			_:
				printerr("unable to create string of statement %s" % [get_location_string()])
				return ""

		#if parser.enable_logs: print("statement --")

		return String("").join(info)


## A node representing a group of statements with the same indent level.
##
## Subclass of ParseNode. Contains a set of statements on the same indent level.
class Block:
	extends ParseNode

	var statements: Array[Statement] = []

	## Collects all upcoming statements (from indent until dedent).
	func _init(parent: ParseNode, parser: YarnParser):
		super(parent, parser)

		if parser.error != OK:
			printerr("Block._init: detected error %s -> aborted." % [get_location_string()])
			return

		# blocks begin with an indent
		parser.try_pop_token_type([YarnGlobals.TokenType.Indent])

		# collect statements until dedent is hit
		while not parser.next_token_is([YarnGlobals.TokenType.Dedent]) and parser.error == OK:
			# parse all statements including nested blocks
			statements.append(Statement.new(self, parser))

		if parser.error != OK:
			printerr("Block._init: an error occurred while appending Statements %s -> aborted." % [get_location_string()])
			return

		# consume dedent
		parser.try_pop_token_type([YarnGlobals.TokenType.Dedent])

	## Returns a string representing this block (multipline, with indents).
	func get_tree_string(indent_level: int) -> String:
		var info: PackedStringArray = []

		info.append(apply_tab(indent_level, "Block {"))

		for statement in statements:
			info.append(statement.get_tree_string(indent_level + 1))

		info.append(apply_tab(indent_level, "}"))

		return String("").join(info)

	static func can_parse(parser: YarnParser) -> bool:
		return parser.next_token_is([YarnGlobals.TokenType.Indent]) # this only needs to recognise the *beginning* of a new block


## A node representing an if statement.
##
## Subclass of ParseNode. Contains an array of Clause objects representing the
## conditional expressions and sub-statements.
class IfStatement:
	extends ParseNode

	var clauses: Array[Clause] = []

	## Reads if, elseif and else clause(s) and stores them in the clauses array.
	func _init(parent: ParseNode, parser: YarnParser):
		super(parent, parser)

		if parser.error != OK:
			printerr("IfStatement._init: detected error %s -> aborted." % [get_location_string()])
			return

		# handle first if clause
		clauses.append(_read_clause(parser, YarnGlobals.TokenType.IfToken))

		while (
			parser.next_token_is([YarnGlobals.TokenType.Whitespace])
			and parser.error == OK
		):
			parser.pop_token()

		if parser.error != OK:
			printerr("IfStatement._init: an error occurred while removing whitespace after if clause %s -> aborted." % [get_location_string()])
			return

		# handle any elseif clauses
		while (
			parser.next_tokens_are([YarnGlobals.TokenType.BeginCommand, YarnGlobals.TokenType.ElseIf])
			and parser.error == OK
		):
			clauses.append(_read_clause(parser, YarnGlobals.TokenType.ElseIf))

			while (
				parser.next_token_is([YarnGlobals.TokenType.Whitespace])
				and parser.error == OK
			):
				parser.pop_token()

			if parser.error != OK:
				printerr("IfStatement._init: an error occurred while removing whitespace after elseif clause %s -> aborted." % [get_location_string()])
				return

		if parser.error != OK:
			printerr("IfStatement._init: an error occurred while appending Clauses %s -> aborted." % [get_location_string()])
			return
		
		# handle else (if one exists)
		if parser.next_tokens_are(
			[
				YarnGlobals.TokenType.BeginCommand,
				YarnGlobals.TokenType.ElseToken,
				YarnGlobals.TokenType.EndCommand
			]
		):
			# read <<else>>
			clauses.append(_read_clause(parser, YarnGlobals.TokenType.ElseToken))

			while (
				parser.next_token_is([YarnGlobals.TokenType.Whitespace])
				and parser.error == OK
			):
				parser.pop_token()
			
			if parser.error != OK:
				printerr("Statement._init: an error occurred while appending else-Statements %s -> aborted." % [get_location_string()])
				return
			
			# consume any dedents -> ignored
			while parser.next_token_is([YarnGlobals.TokenType.Dedent]):
				parser.pop_token()

		# read <<endif>>
		parser.try_pop_token_type([YarnGlobals.TokenType.BeginCommand])
		parser.try_pop_token_type([YarnGlobals.TokenType.EndIf])
		parser.try_pop_token_type([YarnGlobals.TokenType.EndCommand])

	func _read_clause(parser: YarnParser, clause_token_type: int) -> Clause:
		# read <<if Expression>> or <<elseif Expression>> or <<else>>
		parser.try_pop_token_type([YarnGlobals.TokenType.BeginCommand])
		parser.try_pop_token_type([clause_token_type]) # YarnGlobals.TokenType.If or YarnGlobals.TokenType.ElseIf

		var clause: Clause = Clause.new()
		
		if not clause_token_type == YarnGlobals.TokenType.ElseToken:
			clause.expression = ExpressionNode.parse(self, parser)

		parser.try_pop_token_type([YarnGlobals.TokenType.EndCommand])

		while (
			parser.next_token_is([YarnGlobals.TokenType.Whitespace])
			and parser.error == OK
		):
			parser.pop_token()

		if parser.error != OK:
			printerr("IfStatement._read_clause: an error occurred while removing whitespace before inner clause %s -> aborted." % [get_location_string()])
			return

		# read statements until <<elseif Expression>> or <<else>> or <<endif>> is reached
		var clause_statements: Array[Statement] = []
		while (
			not parser.next_tokens_are(
				[YarnGlobals.TokenType.BeginCommand, YarnGlobals.TokenType.ElseIf]
			)
			and not parser.next_tokens_are(
				[YarnGlobals.TokenType.BeginCommand, YarnGlobals.TokenType.ElseToken]
			)
			and not parser.next_tokens_are(
				[YarnGlobals.TokenType.BeginCommand, YarnGlobals.TokenType.EndIf]
			)
			and parser.error == OK
		):
			clause_statements.append(Statement.new(self, parser))

			# consume any dedents -> ignored
			while parser.next_token_is([YarnGlobals.TokenType.Dedent, YarnGlobals.TokenType.Whitespace]):
				parser.pop_token()

		if parser.error != OK:
			printerr("IfStatement._read_clause: an error occurred while reading clause-Statements %s -> aborted." % [get_location_string()])
			return null

		clause.statements = clause_statements

		return clause

	## Returns a string representing this if statement (multiline, with indents).
	func get_tree_string(indent_level: int) -> String:
		var info: PackedStringArray = []
		var is_first: bool = true

		for clause in clauses:
			if is_first:
				info.append(apply_tab(indent_level, "If:", true))
				is_first = false
			elif clause.expression != null:
				info.append(apply_tab(indent_level, "Else If", true))
			else:
				info.append(apply_tab(indent_level, "Else:", true))

			info.append(clause.get_tree_string(indent_level))

		return String("").join(info)
	
	static func can_parse(parser: YarnParser) -> bool:
		return parser.next_tokens_are(
			[YarnGlobals.TokenType.BeginCommand, YarnGlobals.TokenType.IfToken]
		)

	pass


## A class representing a clause of an if-elseif-else statement.
##
## Contains an expression (representing the conditional) as well as
## follow-up statements.
class Clause:
	var expression: ExpressionNode
	var statements: Array[Statement] = []

	func _init(expression: ExpressionNode = null, statements: Array[Statement] = []):
		self.expression = expression
		self.statements = statements

	## Returns a string representing this clause (multiline, with indents).
	func get_tree_string(indent_level: int) -> String:
		var info: PackedStringArray = []

		if expression != null:
			info.append(expression.get_tree_string(indent_level))

		info.append(apply_tab(indent_level, "{"))
		for statement in statements:
			info.append(statement.get_tree_string(indent_level + 1))
		info.append(apply_tab(indent_level, "}"))

		return String("").join(info)

	func apply_tab(indent_level: int, input: String, append_line_break: bool = true) -> String:
		var tabPrecursor = ""
		var indentSpacing = 3
		for i in range(indent_level):
			tabPrecursor += "|%*s" % [indentSpacing, ""]

		return "%*s %s%s" % [indent_level, tabPrecursor, input, "\n" if append_line_break else ""]
	# func tab(indent_level : int , input : String,newLine : bool = true)->String:
	# 	return ("%*s| %s%s"% [indent_level*2,"",input,("" if !newLine else "\n")])


## A node representing a set of shortcut options.
##
## Subclass of ParseNode. Contains an array of shortcut option nodes.
class ShortcutOptionGroup:
	extends ParseNode

	var options: Array[ShortcutOption] = []

	## Consumes a any positive number of ShortcutOption tokens to initialise
	## ShortcutOption nodes for the options array.
	func _init(parent: ParseNode, parser: YarnParser):
		super(parent, parser)

		if parser.error != OK:
			printerr("ShortcutOptionGroup._init: detected error %s -> aborted." % [get_location_string()])
			return

		# parse options until there are no more
		# expects at least one (otherwise invalid)
		var option_index: int = 1
		#options.append(ShortcutOption.new(option_index, self, parser))
		#option_index += 1
		while (
			parser.next_token_is([YarnGlobals.TokenType.ShortcutOption])
			and parser.error == OK
		):
			options.append(ShortcutOption.new(option_index, self, parser))
			option_index += 1

		if parser.error != OK:
			printerr("ShortcutOptionGroup._init: an error occurred while appending ShortcutOptions %s -> aborted." % [get_location_string()])
			return

		assert(option_index > 1) # If this causes a break, it means that there was a shortcut option group without any options. This could be because of a mistake in the yarn file or in the parser.

		var name_of_top_of_stack = YarnGlobals.get_script().get_token_type_name(parser._tokens.front().token_type)
		if parser.enable_logs: print("ShortcutOptionGroup: ended the shortcut group with a [%s] token on top" % name_of_top_of_stack)

	## Returns a string representing this shortcut option group (multiline, using tabs).
	func get_tree_string(indent_level: int) -> String:
		var info: PackedStringArray = []

		info.append(apply_tab(indent_level, "Shortcut Option Group{"))

		for option in options:
			info.append(option.get_tree_string(indent_level + 1))

		info.append(apply_tab(indent_level, "}"))

		return String("").join(info)

	static func can_parse(parser: YarnParser) -> bool:
		return parser.next_token_is([YarnGlobals.TokenType.ShortcutOption])

	pass


## A node representing a shortcut option statement.
##
## Subclass of ParseNode. Contains a line (of text etc.), a condition (optional),
## and a sub-block of further code (also optional).
class ShortcutOption:
	extends ParseNode

	var option_line: LineNode
	var option_condition: ExpressionNode
	var sub_node: DialogueSectionNode

	## Creates nodes representing line code line of this shortcut option,
	## its (optional) condition and its sub-block.
	func _init(option_index: int, parent: ParseNode, parser: YarnParser):
		super(parent, parser)

		if parser.error != OK:
			printerr("ShortcutOption._init: detected error %s -> aborted." % [get_location_string()])
			return

		if parser.enable_logs: print("ShortcutOption: starting shortcut option parse")
		parser.try_pop_token_type([YarnGlobals.TokenType.ShortcutOption])

		# option contains a line of code
		option_line = LineNode.new(self, parser)
		if parser.enable_logs: print("\tthis is a line found in shortcutoption : ", option_line.line_text)

		# parse the conditional << if $x >> when it exists
		# there may be a tag on the same line
		var tags: Array[String] = []
		while (
			parser.next_tokens_are( [YarnGlobals.TokenType.BeginCommand, YarnGlobals.TokenType.IfToken] )
			or parser.next_token_is([YarnGlobals.TokenType.TagMarker])
		) and parser.error == OK:
			if parser.next_tokens_are(
				[YarnGlobals.TokenType.BeginCommand, YarnGlobals.TokenType.IfToken], node_line_number
			):
				# conditional detected -> create expression node
				parser.try_pop_token_type([YarnGlobals.TokenType.BeginCommand])
				parser.try_pop_token_type([YarnGlobals.TokenType.IfToken])
				option_condition = ExpressionNode.parse(self, parser)
				parser.try_pop_token_type([YarnGlobals.TokenType.EndCommand])
			elif parser.next_token_is( [YarnGlobals.TokenType.TagMarker] ):
				# tag marker detected -> store
				parser.try_pop_token_type([YarnGlobals.TokenType.TagMarker])
				var tag: String = parser.try_pop_token_type([YarnGlobals.TokenType.Identifier]).value
				tags.append(tag)
			else:
				if parser.enable_logs: print("\tno if or tag on the remainder of this line.")
				break

		if parser.error != OK:
			printerr("ShortcutOption._init: an error occurred while parsing shortcut conditional %s -> aborted." % [get_location_string()])
			return

		self.tags = tags

		# if a line tag was found, apply it to the line node (it doesn't know about it yet!).
		for tag in tags:
			if tag.begins_with("line:") && option_line.line_id.is_empty():
				option_line.line_id = tag
		
		# parse statements in the sub-block of this option (if such a block exists).
		if parser.next_token_is([YarnGlobals.TokenType.Indent]):
			# sub-block detected -> create new DialogueSectionNode for that block.
			parser.try_pop_token_type([YarnGlobals.TokenType.Indent])
			sub_node = DialogueSectionNode.new("%s.%s" % [self.get_closest_dialogue_section_parent().dialogue_section_name, option_index], self, parser)
			parser.try_pop_token_type([YarnGlobals.TokenType.Dedent])

	## Returns a string representing this shortcut option (multiline, with indents).
	func get_tree_string(indent_level: int) -> String:
		var info: PackedStringArray = []

		info.append(apply_tab(indent_level, 'Option "%s"' % option_line.get_tree_string(indent_level)))

		if option_condition != null:
			info.append(apply_tab(indent_level + 1, "(when:"))
			info.append(option_condition.get_tree_string(indent_level + 2))
			info.append(apply_tab(indent_level + 1, "),"))
		if sub_node != null:
			info.append(apply_tab(indent_level, "{"))
			info.append(sub_node.get_tree_string(indent_level + 1))
			info.append(apply_tab(indent_level, "}"))

		return String("").join(info)


## A node representing a single line of Yarn code.
##
## Subclass of ParseNode. Contains inline expressions (InlineExpression),
## format functions (FormatFunction), a line tag, other tags and text.
## TODO FIXME: right now we are putting the formatfunctions and inline expressions in the same
##              list but if at some point we want to strongly type our sub list we need to make a new
##              parse node that can have either an InlineExpression or a FunctionFormat
##              This is a consideration for Godot 4!
class LineNode:
	extends ParseNode
	var line_text: String ## the contents of this line formatted as a string

	#TODO: FIXME: right now we are putting the formatfunctions and inline expressions in the same
	#             list but if at some point we want to strongly type our sub list we need to make a new
	#             parse node that can have either an InlineExpression or a FormatFunction>
	#             .. This is a consideration for Godot4.x
	var substitutions: Array[ParseNode] = []  ## of type <InlineExpression |& FormatFunction>

	var line_id: String = "" ## the ID assigned to this line via a tag.
	var line_tags: PackedStringArray = [] ## stores all non-line tags (i.e. those not starting with "line:")

	# NOTE: If inline functions and format functions are both present
	# returns a line in the format "Some text {0} and some other {1}[format "{2}" key="value" key="value"]"

	## Consumes text, format function, expression function and tag tokens to
	## create respective nodes and store their info.
	func _init(parent: ParseNode, parser):
		super(parent, parser)

		if parser.error != OK:
			printerr("LineNode._init: detected error %s -> aborted." % [get_location_string()])
			return

		while (
			parser.next_token_is([
				YarnGlobals.TokenType.FormatFunctionStart,
				YarnGlobals.TokenType.ExpressionFunctionStart,
				YarnGlobals.TokenType.TagMarker,
				YarnGlobals.TokenType.Text
			] as Array[int])
			and parser.error == OK
		):
			if FormatFunction.can_parse(parser):
				# format function upcoming -> create and store node and copy format text to line text.
				var ff = FormatFunction.new(self, parser, substitutions.size())
				if ff.expression_value != null:
					substitutions.append(ff.expression_value)
				line_text += ff.format_text
			elif InlineExpression.can_parse(parser):
				# inline expression upcoming -> create and store node and keep track of substitution count.
				var ie = InlineExpression.new(self, parser)
				line_text += "{%d}" % substitutions.size()
				substitutions.append(ie)
			elif parser.next_tokens_are(
				[YarnGlobals.TokenType.TagMarker, YarnGlobals.TokenType.Identifier] as Array[int]
			):
				# tag marker upcoming -> store line ID or other tag value
				parser.pop_token()
				var tag_token: Lexer.Token = parser.try_pop_token_type([YarnGlobals.TokenType.Identifier] as Array[int])
				if tag_token.value.begins_with("line:"):
					if line_id.is_empty():
						line_id = tag_token.value
					else:
						printerr("Tried to assign more than one tag to a line! @[%s:%d]" % [parser.current_node_name, tag_token.line_number])
						return
				else:
					tags.append(tag_token.value)

				break # line tag marks the end of the line!

			else:
				# expecting text -> store text
				var tt = parser.pop_token()
				if tt.line_number == node_line_number && !(tt.token_type == YarnGlobals.TokenType.BeginCommand):
					line_text += tt.value
				else:
					# token is actually a command -> put back on stack!
					parser._tokens.push_front(tt)
					break

		if parser.error != OK:
			printerr("LineNode._init: an error occurred while parsing the line %s -> aborted." % [get_location_string()])
			return

		if parser.enable_logs: print("LineNode: new line found: ", line_text)

	static func can_parse(parser: YarnParser) -> bool:
		return parser.next_token_is([
				YarnGlobals.TokenType.FormatFunctionStart,
				YarnGlobals.TokenType.ExpressionFunctionStart,
				YarnGlobals.TokenType.TagMarker,
				YarnGlobals.TokenType.Text
			] as Array[int])

	## Returns a string representing this line node.
	func get_tree_string(indent_level: int) -> String:
		return "Line: (%s)[%d]" % [line_text, substitutions.size()]


## A node representing a format function.
##
## Subclass of ParseNode. Contains an inline expression (InlineExpression)
## and format text surrounded by FormatFunctionStart/-End tokens.
class FormatFunction:
	extends ParseNode

	var format_text: String = "" ## has the form [function_name "{0}" key1="value1" key2="value2" ...]
	var expression_value: InlineExpression

	## Consumes the tokens delimiting the format function's start and end
	## and InlineExpression nodes and format text from the tokens within.
	func _init(parent: ParseNode, parser: YarnParser, expressionCount: int):
		super(parent, parser)

		if parser.error != OK:
			printerr("FormatFunction._init: detected error %s -> aborted." % [get_location_string()])
			return

		parser.try_pop_token_type([YarnGlobals.TokenType.FormatFunctionStart])
		format_text = "["

		var has_advanced: bool = false
		while (
			not parser.next_token_is([YarnGlobals.TokenType.FormatFunctionEnd] as Array[int])
			and parser.error == OK
		):
			has_advanced = false

			if parser.next_token_is([YarnGlobals.TokenType.Text]):
				format_text += parser.pop_token().value
				has_advanced = true

			if InlineExpression.can_parse(parser):
				expression_value = InlineExpression.new(self, parser)
				format_text += ' "{%d}" ' % expressionCount
				has_advanced = true

			if not has_advanced:
				printerr("FormatFunction._init: parser couldn't advance while parsing the insides of a format function! %s" % [get_location_string()])
		
		if parser.error != OK:
			printerr("FormatFunction._init: an error occurred while parsing the format function -> aborted.")
			return

		parser.pop_token() # consume FormatFunctionEnd token
		format_text += "]"

	## Checks whether the upcoming token can be used to parse this node.
	static func can_parse(parser: YarnParser) -> bool:
		return parser.next_token_is([YarnGlobals.TokenType.FormatFunctionStart])

	## Returns a string representing this format function.
	## TODO Make format prettier and add more information.
	func get_tree_string(indent_level: int) -> String:
		return "FormatFunction"


## A node representing an inline expression.
##
## Subclass of ParseNode. Contains an expression (ExpressionNode)
## surrounded by ExpressionFunctionStart/-End tokens.
class InlineExpression:
	extends ParseNode
	var expression_value: ExpressionNode

	## Consumes the tokens delimiting the expression function's start and end
	## and creates an ExpressionNode from the tokens within.
	func _init(parent: ParseNode, parser: YarnParser):
		super(parent, parser)

		if parser.error != OK:
			printerr("InlineExpression._init: detected error %s -> aborted." % [get_location_string()])
			return

		parser.try_pop_token_type([YarnGlobals.TokenType.ExpressionFunctionStart])
		expression_value = ExpressionNode.parse(self, parser)
		parser.try_pop_token_type([YarnGlobals.TokenType.ExpressionFunctionEnd])

	## Checks whether the upcoming token can be used to parse this node.
	static func can_parse(parser: YarnParser) -> bool:
		return parser.next_token_is([YarnGlobals.TokenType.ExpressionFunctionStart])

	## Returns a string representing this inline expression.
	## TODO make tree string nicer with added information about the expression.
	func get_tree_string(indent_level: int) -> String:
		return "InlineExpression:"


## A node representing links to other nodes.
##
## Subclass of ParseNode. Contains the name of a destination node as well as optional text.
## It's kind of a misnomer because it doesn't actually seem to provide any options.
## Syntax 1: [[NodeName]]
## Syntax 2: [[Text displayed to the user | Node Name]]
class OptionStatement:
	extends ParseNode

	var destination_node_name: String = ""
	var displayed_line: LineNode = null

	## Parses upcoming tokens to read the displayed text text (if provided)
	## and destination node name.
	func _init(parent: ParseNode, parser: YarnParser):
		super(parent, parser)

		if parser.error != OK:
			printerr("OptionStatement._init: detected error %s -> aborted." % [get_location_string()])
			return

		# begins with [[ (option start) token
		parser.try_pop_token_type([YarnGlobals.TokenType.OptionStart])

		# read text. this may be either the destination node's name or text
		# displayed to the user depending on whether or not an option delimit
		# token follows
		displayed_line = LineNode.new(self, parser)

		#printerr("option line[", line.line_text, "] has ", line.substitutions.size(), " subs")
		#printerr("line inside the statement : ",line.line_text)
		#var tokens := []
		#tokens.append(parser.try_pop_token_type([YarnGlobals.TokenType.Text]))

		if parser.next_token_is([YarnGlobals.TokenType.OptionDelimit]):
			# | (option delimit) token detected
			# -> line represents text displayed to the user, rest is destination node name
			parser.try_pop_token_type([YarnGlobals.TokenType.OptionDelimit])
			var t = parser.try_pop_token_type(
				[YarnGlobals.TokenType.Text, YarnGlobals.TokenType.Identifier]
			)
			destination_node_name = t.value

		if destination_node_name.is_empty():
			# no option delimit token has been detected
			# -> line represents the destination node name, no text will be displayed
			destination_node_name = displayed_line.line_text
			displayed_line = null
		else:
			get_closest_dialogue_section_parent().has_options = true ## TODO FIXME: shouldn't this be called in both the if AND the else case? an option exists either way!

		# this should be the end of the option
		parser.try_pop_token_type([YarnGlobals.TokenType.OptionEnd])

		# get tag (if one exists)
		if parser.next_token_is([YarnGlobals.TokenType.TagMarker], node_line_number):
			# TODO FIXME: give an error if there are too many line tags
			parser.pop_token()
			var id: String = parser.try_pop_token_type([YarnGlobals.TokenType.Identifier]).value
			if displayed_line:
				displayed_line.line_id = id

	## Returns a string representing this option statement.
	func get_tree_string(indent_level: int) -> String:
		if displayed_line != null:
			return apply_tab(indent_level, "Option: [%s] -> %s" % [displayed_line.get_tree_string(0), destination_node_name])
		else:
			return apply_tab(indent_level, "Option: -> %s" % destination_node_name)

	static func can_parse(parser: YarnParser) -> bool:
		return parser.next_token_is([YarnGlobals.TokenType.OptionStart])


## A node representing a function (expression) or client command.
##
## Subclass of ParseNode. Can represent a function (expression) or a client command.
class Command:
	extends ParseNode

	enum Type { ExpressionCommand, BuiltInCommand }
	var command_type: int

	# The class will instantiate exactly one of the following:
	var expression_command: ExpressionNode = null
	var built_in_command: String = ""
	var built_in_command_args: Array[ParseNode] = []

	## Consumes the begin/end command tokens and evaluates the
	## command within as a function (expression) or client command.
	func _init(parent: ParseNode, parser: YarnParser):
		super(parent, parser)

		if parser.error != OK:
			printerr("Command._init: detected error %s -> aborted." % [get_location_string()])
			return


		if parser.enable_logs: print("Parsing command...")

		parser.try_pop_token_type([YarnGlobals.TokenType.BeginCommand])

		# copy the tokens inside the command in a separate array
		# before evaluating further
		var command_tokens: Array[Lexer.Token] = []
		while (
			not parser.next_token_is([YarnGlobals.TokenType.EndCommand])
			and parser.error == OK
		):
			command_tokens.append(parser.pop_token())

		if parser.error != OK:
			printerr("Command._init: an error occurred while parsing command tokens %s -> aborted." % [get_location_string()])
			return

		if parser.enable_logs: print("\t%d command tokens detected." % [command_tokens.size()])

		parser.try_pop_token_type([YarnGlobals.TokenType.EndCommand])

		if command_tokens.size() == 0:
			return

		# evaluate the command tokens
		if (
			command_tokens[0].token_type == YarnGlobals.TokenType.Identifier
			and command_tokens[1].token_type == YarnGlobals.TokenType.LeftParen
		):
			_parse_custom_command(parser, command_tokens)
		else:
			_parse_built_in_command(parser, command_tokens)
	
	func _parse_custom_command(parser: YarnParser, command_tokens: Array[Lexer.Token]) -> void:
		# first token is an identifier and second is left parenthesis
		# -> evaluate as custom command (function)
		#  -> create parser for the command
		if parser.enable_logs: print("\tidentified to be a custom command")
		command_type = Type.ExpressionCommand
		
		var p: YarnParser = YarnParser.new(command_tokens, parser.enable_logs)
		var expression: ExpressionNode = ExpressionNode.parse(self, p)
		expression_command = expression
		
		if p.error != OK:
			parser.error = p.error
	
	func _parse_built_in_command(parser: YarnParser, command_tokens: Array[Lexer.Token]) -> void:
		# text -> build-in command -> evaluate
		if parser.enable_logs: print("\tidentified to be a built-in command")
		command_type = Type.BuiltInCommand
		
		built_in_command = command_tokens[0].value
		if parser.enable_logs: print("\tbuilt-in command name: %s" % built_in_command)
		
		if command_tokens.size() <= 1:
			# no args -> done
			return
		command_tokens.pop_front() # remove command name, leave only args
		
		if parser.enable_logs:
			print("\targs:")
			for ct in command_tokens:
				print("\t\t%s: %s" % [YarnGlobals.TokenType.find_key(ct.token_type), ct.value])
		
		# parse all args
		var p: YarnParser = YarnParser.new(command_tokens, parser.enable_logs)
		while p._tokens.size() > 0 and p.error == OK:
			if p.next_token_is([
				YarnGlobals.TokenType.Number,
				YarnGlobals.TokenType.Str,
				YarnGlobals.TokenType.TrueToken,
				YarnGlobals.TokenType.FalseToken,
				YarnGlobals.TokenType.Variable,
				YarnGlobals.TokenType.NullToken
			]):
				# number / variable arg
				var value_node: ValueNode = ValueNode.new(self, p)
				built_in_command_args.append(value_node)
			elif p.next_tokens_are([
				YarnGlobals.TokenType.Identifier,
				YarnGlobals.TokenType.LeftParen
			]):
				# function arg
				var expression: ExpressionNode = ExpressionNode.parse(self, p)
				built_in_command_args.append(expression)
			elif p.next_token_is([YarnGlobals.TokenType.Comma]):
				# comma -> ignore
				p.pop_token()
			else:
				printerr("Command._parse_built_in_command: unexpected arg token %s (value %s) %s" % [
					YarnGlobals.TokenType.find_key((p._tokens.front() as Lexer.Token).token_type),
					(p._tokens.front() as Lexer.Token).value,
					get_location_string()
				])
				p.error = ERR_INVALID_DATA
		
		if p.error != OK:
			parser.error = p.error
	
	## Returns a string representing this custom command. Depends on the command type.
	func get_tree_string(indent_level: int) -> String:
		match command_type:
			Type.ExpressionCommand:
				return apply_tab(indent_level, "Custom Command (Expression): %s" % expression_command.get_tree_string(indent_level + 1))
			Type.BuiltInCommand:
				return apply_tab(indent_level, "Built-In Command: %s" % built_in_command)
		return ""

	static func can_parse(parser: YarnParser) -> bool:
		return (
			parser.next_tokens_are(
				[YarnGlobals.TokenType.BeginCommand, YarnGlobals.TokenType.Text]
			)
			or parser.next_tokens_are(
				[YarnGlobals.TokenType.BeginCommand, YarnGlobals.TokenType.Identifier]
			)
		)


## A node representing a value assignment operation.
##
## Subclass of ParseNode. Contains the name of a variable, the value that
## will be assigned and the operation type.
## Example 1: <<set Variable to Value>>
## Example 2: <<set Variable += Value>>
class Assignment:
	extends ParseNode

	var variable_name: String ## name of the variable whose value will be assigned
	var value: ExpressionNode
	var operation_type: int # item of YarnGlobals.TokenType

	func _init(parent: ParseNode, parser: YarnParser):
		super(parent, parser)

		if parser.error != OK:
			printerr("Assignment._init: detected error %s -> aborted." % [get_location_string()])
			return

		# read <<set Variable to Value>>
		parser.try_pop_token_type([YarnGlobals.TokenType.BeginCommand]) # <<
		parser.try_pop_token_type([YarnGlobals.TokenType.Set]) # set
		variable_name = parser.try_pop_token_type([YarnGlobals.TokenType.Variable]).value # Variable
		operation_type = parser.try_pop_token_type(Assignment.valid_ops()).token_type # to / = / += / ...
		value = ExpressionNode.parse(self, parser) # Value
		parser.try_pop_token_type([YarnGlobals.TokenType.EndCommand]) # >>

	## Returns a string representing the assignment.
	func get_tree_string(indent_level: int) -> String:
		var info: PackedStringArray = []

		info.append(apply_tab(indent_level, "set:"))
		info.append(apply_tab(indent_level + 1, variable_name))
		info.append(apply_tab(indent_level + 1, YarnGlobals.get_script().get_token_type_name(operation_type)))
		info.append(value.get_tree_string(indent_level + 1))
		return String("").join(info)

	static func can_parse(parser: YarnParser) -> bool:
		return parser.next_tokens_are(
			[YarnGlobals.TokenType.BeginCommand, YarnGlobals.TokenType.Set]
		)

	## Returns an array of YarnGlobals.TokenType items representing
	## the operators that may be used to assign values.
	static func valid_ops() -> Array[int]:
		return [
			YarnGlobals.TokenType.EqualToOrAssign,
			YarnGlobals.TokenType.AddAssign,
			YarnGlobals.TokenType.MinusAssign,
			YarnGlobals.TokenType.DivideAssign,
			YarnGlobals.TokenType.MultiplyAssign
		]


## A node representing an expression.
##
## Subclass of ParseNode. Expressions encompass a wide range of things like:
## - math (1 + 2 - 5 * 3 / 10 % 2)
## - assignments
## - Identifiers
## - Values
class ExpressionNode:
	extends ParseNode

	var expression_type: int # Value or FunctionCall

	# one of the following two will be set
	var value: ValueNode
	var function_name: String

	var function_params: Array[ExpressionNode] = []

	# Remove this constant if it causes any trouble.
	# It's only used for stronger typing to ensure there are no typos.
	const Lexer = preload("uid://chwwhyiwk8nxm") # lexer.gd


	## Constructs an ExpressionNode from already existing arguments (without parsing).
	## To parse an ExpressionNode, use [method parse] instead.
	func _init(parent: ParseNode, parser: YarnParser, value: ValueNode, function_name: String = "", function_params: Array[ExpressionNode] = []):
		super(parent, parser)

		if parser.error != OK:
			printerr("ExpressionNode._init: detected error %s -> aborted." % [get_location_string()])
			return

		if value != null:
			self.expression_type = YarnGlobals.ExpressionType.Value
			self.value = value
		else:
			# no value given -> interpreted as function call
			self.expression_type = YarnGlobals.ExpressionType.FunctionCall
			self.function_name = function_name
			self.function_params = function_params

	## Returns a string representing this expression.
	func get_tree_string(indent_level: int) -> String:
		var info: PackedStringArray = []

		match expression_type:
			YarnGlobals.ExpressionType.Value:
				return value.get_tree_string(indent_level)
			YarnGlobals.ExpressionType.FunctionCall:
				info.append(apply_tab(indent_level, "Func[%s - params(%s)]:{" % [function_name, function_params.size()]))
				for param in function_params:
					#if parser.enable_logs: print("----> %s paramSize:%s"%[(function) , params.size()])
					info.append(param.get_tree_string(indent_level + 1))
				info.append(apply_tab(indent_level, "}"))

		return String("").join(info)

	## Parses tokens to construct an expression node.
	static func parse(parent: ParseNode, parser: YarnParser) -> ExpressionNode:
		# Use Djikstra's shunting-yard algorithm to convert the
		# stream of infix expressions into postfix notation.
		# Then, build a tree of expressions.

		var rpn: Array[Lexer.Token] = []  # stack for reverse Polish notation (= postfix notation)
		var op_stack: Array[Lexer.Token] = []  # stack of operations

		# track function parameters
		var func_stack: Array[Lexer.Token] = []  # stack of functions

		var valid_types: Array[int] = [
			YarnGlobals.TokenType.Number,
			YarnGlobals.TokenType.Variable,
			YarnGlobals.TokenType.Str,
			YarnGlobals.TokenType.LeftParen,
			YarnGlobals.TokenType.RightParen,
			YarnGlobals.TokenType.Identifier,
			YarnGlobals.TokenType.Comma,
			YarnGlobals.TokenType.TrueToken,
			YarnGlobals.TokenType.FalseToken,
			YarnGlobals.TokenType.NullToken
		]
		valid_types.append_array(Operator.get_op_types()) # adds all operators, e.g. YarnGlobals.TokenType.Add
		valid_types.reverse() # check for operators before checking for arguments

		var last: Lexer.Token

		# read valid expression content
		while (
			parser.get_tokens().size() > 0
			and parser.next_token_is(valid_types)
			and parser.error == OK
		):
			var next: Lexer.Token = parser.try_pop_token_type(valid_types)

			if (
				next.token_type == YarnGlobals.TokenType.Variable
				|| next.token_type == YarnGlobals.TokenType.Number
				|| next.token_type == YarnGlobals.TokenType.Str
				|| next.token_type == YarnGlobals.TokenType.TrueToken
				|| next.token_type == YarnGlobals.TokenType.FalseToken
				|| next.token_type == YarnGlobals.TokenType.NullToken
			):
				# output primitives
				rpn.append(next)
			elif next.token_type == YarnGlobals.TokenType.Identifier:
				op_stack.push_back(next)
				func_stack.push_back(next)

				# next token is a left parenthesis
				next = parser.try_pop_token_type([YarnGlobals.TokenType.LeftParen])
				op_stack.push_back(next)
			elif next.token_type == YarnGlobals.TokenType.Comma:
				if op_stack.size() == 0:
					printerr("ExpressionNode.parse: unbalanced parenthesis in %s %s (case 1)" % [next.name, parent.get_location_string()])
					parser.error = ERR_INVALID_DATA
					return null

				# resolve sub expression before moving on
				var left_paranthesis_found: bool = false
				while op_stack.size() > 0:
					if op_stack.back().token_type == YarnGlobals.TokenType.LeftParen:
						left_paranthesis_found = true
						break

					var p: Lexer.Token = op_stack.pop_back()
					if p == null:
						printerr("ExpressionNode.parse: unexpectedly reached end of op_stack at %s %s " % [next.name, parent.get_location_string()])
						parser.error = ERR_INVALID_DATA
						return null
						break
					rpn.append(p)

				if not left_paranthesis_found:
					printerr("ExpressionNode.parse: unbalanced parenthesis in %s %s (case 2)" % [next.name, parent.get_location_string()])
					parser.error = ERR_INVALID_DATA
					return null
					break

				# next token in op_stack left paren
				# next parser token not allowed to be right paren or comma
				if parser.next_token_is(
					[YarnGlobals.TokenType.RightParen, YarnGlobals.TokenType.Comma]
				):
					printerr("ExpressionNode.parse: expected Expression but received right parenthesis or comma in %s %s" % [parser.get_tokens().front().name, parent.get_location_string()])
					parser.error = ERR_INVALID_DATA
					return null

				# find the closest function on stack
				# increment parameters
				func_stack.back().param_count += 1

			elif Operator.is_op(next.token_type):
				# current token is an operator

				# if this is a minus, we need to determine if it is a
				# unary minus or a binary minus.
				# a unary minus looks like this : -1
				# a binary minus looks like this 2 - 3
				# things get complex when we say stuff like: 1 + -1
				# but it's easier when we realize that a minus
				# is only unary when the last token was a left paren,
				# an operator, or it's the first token.

				if next.token_type == YarnGlobals.TokenType.Minus:
					if (
						last == null
						|| last.token_type == YarnGlobals.TokenType.LeftParen
						|| Operator.is_op(last.token_type)
					):
						# unary minus
						next.token_type = YarnGlobals.TokenType.UnaryMinus

				# cannot assign inside expression
				# x = a is the same as x == a
				if next.token_type == YarnGlobals.TokenType.EqualToOrAssign:
					next.token_type = YarnGlobals.TokenType.EqualTo

				# operator precedence
				while ExpressionNode.check_op_takes_priotity(next.token_type, op_stack):
					var op: Lexer.Token = op_stack.pop_back()
					rpn.append(op)

				op_stack.push_back(next)

			elif next.token_type == YarnGlobals.TokenType.LeftParen:
				# entered parenthesis sub expression
				op_stack.push_back(next)

			elif next.token_type == YarnGlobals.TokenType.RightParen:
				# leaving sub expression
				# resolve order of operations
				while op_stack.back().token_type != YarnGlobals.TokenType.LeftParen:
					rpn.append(op_stack.pop_back())
					if op_stack.back() == null:
						printerr("ExpressionNode.parse: unbalanced parenthasis #RightParen %s" % [parent.get_location_string()])
						parser.error = ERR_INVALID_DATA
						return null

				op_stack.pop_back()  # pop left parenthesis
				if !op_stack.is_empty() && op_stack.back().token_type == YarnGlobals.TokenType.Identifier:
					# function call
					# last token == left paren this == no params
					# else
					# we have more than 1 param
					if last.token_type != YarnGlobals.TokenType.LeftParen:
						func_stack.back().param_count += 1

					rpn.append(op_stack.pop_back())
					func_stack.pop_back()

			#record last token used
			last = next

			# -> continue while-loop

		if parser.error != OK:
			printerr("ExpressionNode.parse: an error occurred while parsing the expression content %s -> aborted." % [parent.get_location_string()])
			return null

		# no more tokens : pop operators to output
		while op_stack.size() > 0:
			rpn.append(op_stack.pop_back())

		# if rpn is empty then this is not an expression
		if rpn.size() == 0:
			printerr("ExpressionNode.parse: expression invalid or not found! %s" % [parent.get_location_string()])
			return null

		# build expression tree
		var first: Lexer.Token = rpn.front()
		var eval_stack: Array[ExpressionNode] = []

		while rpn.size() > 0:
			var next: Lexer.Token = rpn.pop_front()
			if Operator.is_op(next.token_type):
				# current token is an operation
				var info: OperatorInfo = Operator.get_op_info(next.token_type)

				if eval_stack.size() < info.num_arguments:
					printerr( "Error parsing : Not enough arguments for %s [ got %s expected - was %s] %s" % [
							YarnGlobals.get_script().get_token_type_name(next.token_type),
							eval_stack.size(),
							info.num_arguments,
							parent.get_location_string()
						]
					)

				var params: Array[ExpressionNode] = []
				for i in range(info.num_arguments):
					params.append(eval_stack.pop_back())

				params.reverse()

				var function: String = get_func_name(next.token_type)

				var expression: ExpressionNode = ExpressionNode.new(
					parent, parser, null, function, params
				)

				eval_stack.append(expression)

			elif next.token_type == YarnGlobals.TokenType.Identifier:
				# function call

				var function: String = next.value

				var params: Array[ExpressionNode] = []
				for i in range(next.param_count):
					params.append(eval_stack.pop_back())

				params.reverse()

				var expression: ExpressionNode = ExpressionNode.new(
					parent, parser, null, function, params
				)

				eval_stack.append(expression)
			else:
				#raw value
				var value: ValueNode = ValueNode.new(parent, parser, next)
				var expression: ExpressionNode = ExpressionNode.new(parent, parser, value)
				eval_stack.append(expression)

		# we should have a single root expression left
		# if more then we failed ---- NANI
		if eval_stack.size() != 1:
			printerr("Error parsing expression (stack did not reduce correctly ) @[l%4d,c%4d] (parent %s)" % [
				first.line_number,
				first.column,
				parent.get_location_string()
			])
			return null

		return eval_stack.pop_back()

	# static func can_parse(parser)->bool:
	# 	return false

	## Returns the string of the YarnGlobals.TokenType value
	## that's equal to the given token type.
	static func get_func_name(token_type: int) -> String:
		for key in YarnGlobals.TokenType.keys():
			if YarnGlobals.TokenType[key] == token_type:
				return key

		return ""

	## Checks whether the operation at the back of the given operator stack
	## is evaluated before the given operation type (e.g. * before + and so on).
	## Returns false if the stack is empty or if the item on the stack isn't an operation.
	## Prints an error if the passed token type is not an operation type.
	static func check_op_takes_priotity(token_type: int, operator_stack: Array[Lexer.Token]) -> bool:
		if operator_stack.size() == 0:
			return false

		if not Operator.is_op(token_type):
			printerr("Expression parsing error: passed token type %d is not an operation! (op_stack position %d)" % [
				token_type,
				operator_stack.front().line_number if operator_stack.size() > 0 else -1
			])
			print_stack()
			return false
		var operation_type: int = token_type

		var stack_operation_type: int = operator_stack.back().token_type

		if !Operator.is_op(stack_operation_type):
			return false

		var first_info: OperatorInfo = Operator.get_op_info(operation_type)
		var second_info: OperatorInfo = Operator.get_op_info(stack_operation_type)

		if (
			first_info.associativity == OperatorInfo.Associativity.Left
			&& first_info.precedence_score <= second_info.precedence_score
		):
			return true

		if (
			first_info.associativity == OperatorInfo.Associativity.Right
			&& first_info.precedence_score < second_info.precedence_score
		):
			return true

		return false


## A node representing a value.
##
## Subclass of ParseNode. Contains a Value object (see core/value.gd).
class ValueNode:
	extends ParseNode

	const Value = preload("uid://dtwoppax6efli") # value.gd - class representing a value and operations on it
	const Lexer = preload("uid://chwwhyiwk8nxm") # lexer.gd

	var value: Value

	func _init(parent: ParseNode, parser: YarnParser, token: Lexer.Token = null):
		super(parent, parser)

		if parser.error != OK:
			printerr("ValueNode._init: detected error %s -> aborted." % [get_location_string()])
			return

		var t: Lexer.Token = token
		if t == null:
			t = parser.try_pop_token_type(
				[
					YarnGlobals.TokenType.Number,
					YarnGlobals.TokenType.Str,
					YarnGlobals.TokenType.FalseToken,
					YarnGlobals.TokenType.TrueToken,
					YarnGlobals.TokenType.Variable,
					YarnGlobals.TokenType.NullToken,
				]
			)

		use_token(t, parser)

	## Stores a value depending on type of the given token.
	func use_token(t: Lexer.Token, parser: YarnParser) -> void:
		match t.token_type:
			YarnGlobals.TokenType.Number:
				value = Value.new(float(t.value))
			YarnGlobals.TokenType.Str:
				value = Value.new(t.value)
			YarnGlobals.TokenType.FalseToken:
				value = Value.new(false)
			YarnGlobals.TokenType.TrueToken:
				value = Value.new(true)
			YarnGlobals.TokenType.Variable:
				value = Value.new(null)
				value.type = YarnGlobals.ValueType.Variable
				value.variable = t.value
			YarnGlobals.TokenType.NullToken:
				value = Value.new(null)
			_:
				printerr("%s, Invalid token type @[l%4d:c%4d] (location %s)" % [
					YarnGlobals.get_script().get_token_type_name(t.token_type),
					t.line_number,
					t.offset,
					get_location_string()
					])
				parser.error = ERR_INVALID_DATA

	## Returns a string representing this value.
	func get_tree_string(indent_level: int, append_line_break: bool = true) -> String:
		return apply_tab(
			indent_level,
			"<%s>%s" % [YarnGlobals.get_script().get_value_type_name(value.type), value.get_value()],
			append_line_break
		)


## A node representing a mathematical operator.
##
## Subclass of ParseNode. Contains an object marking the type of operation.
## Also has a class to output information about an operation, e.g. its
## associativity and precedence.
class Operator:
	extends ParseNode

	var op_type: int ## item of YarnGlobals.TokenType

	func _init(parent: ParseNode, parser, op_type = null):
		super(parent, parser)

		if parser.error != OK:
			printerr("Operator._init: detected error %s -> aborted." % [get_location_string()])
			return

		if op_type == null:
			self.op_type = parser.pop_token(Operator.get_op_types()).token_type
		else:
			self.op_type = op_type

	## Returns a string representing this operator.
	func get_tree_string(indent_level: int) -> String:
		var info: PackedStringArray = []
		info.append(apply_tab(indent_level, YarnGlobals.get_token_type_name(op_type)))
		return String("").join(info)

	## Returns an OperatorInfo object for this operation type.
	static func get_op_info(op_type: int) -> OperatorInfo:
		if not Operator.is_op(op_type):
			printerr("Operator.get_op_info: %s is not a valid operator" % YarnGlobals.get_token_type_name(op_type))
			print_stack()
			return null

		#determine associativity and operands
		# each operand has
		var TokenType = YarnGlobals.TokenType

		match op_type:
			TokenType.Not, TokenType.UnaryMinus:
				return OperatorInfo.new(OperatorInfo.Associativity.Right, 30, 1)
			TokenType.Multiply, TokenType.Divide, TokenType.Modulo:
				return OperatorInfo.new(OperatorInfo.Associativity.Left, 20, 2)
			TokenType.Add, TokenType.Minus:
				return OperatorInfo.new(OperatorInfo.Associativity.Left, 15, 2)
			TokenType.GreaterThan, TokenType.LessThan, TokenType.GreaterThanOrEqualTo, TokenType.LessThanOrEqualTo:
				return OperatorInfo.new(OperatorInfo.Associativity.Left, 10, 2)
			TokenType.EqualTo, TokenType.EqualToOrAssign, TokenType.NotEqualTo:
				return OperatorInfo.new(OperatorInfo.Associativity.Left, 5, 2)
			TokenType.And:
				return OperatorInfo.new(OperatorInfo.Associativity.Left, 4, 2)
			TokenType.Or:
				return OperatorInfo.new(OperatorInfo.Associativity.Left, 3, 2)
			TokenType.Xor:
				return OperatorInfo.new(OperatorInfo.Associativity.Left, 2, 2)
			_:
				printerr("Operator.get_op_info: unknown or unimplemented operator %s" % YarnGlobals.get_token_type_name(op_type))
				print_stack()

		return null

	## Returns whether this token type represents a supported
	## operator.
	static func is_op(token_type: int) -> bool:
		return get_op_types().has(token_type)

	## Returns an array of YarnGlobals.TokenType items representing
	## all supported operators.
	static func get_op_types() -> Array[int]:
		return [
			YarnGlobals.TokenType.Not,
			YarnGlobals.TokenType.UnaryMinus,
			YarnGlobals.TokenType.Add,
			YarnGlobals.TokenType.Minus,
			YarnGlobals.TokenType.Divide,
			YarnGlobals.TokenType.Multiply,
			YarnGlobals.TokenType.Modulo,
			YarnGlobals.TokenType.EqualToOrAssign,
			YarnGlobals.TokenType.EqualTo,
			YarnGlobals.TokenType.GreaterThan,
			YarnGlobals.TokenType.GreaterThanOrEqualTo,
			YarnGlobals.TokenType.LessThan,
			YarnGlobals.TokenType.LessThanOrEqualTo,
			YarnGlobals.TokenType.NotEqualTo,
			YarnGlobals.TokenType.And,
			YarnGlobals.TokenType.Or,
			YarnGlobals.TokenType.Xor
		]


## A class containing information about an operator type.
##
## Contains an operator's associativity, a score indicating
## the order it's evaluated in compared to other operators
## and the number of arguments that it takes.
class OperatorInfo:
	enum Associativity { Left, Right, None }

	var associativity: int ## Item of the Associativity enum.
	var precedence_score: int ## Operators with a higher precedence score are evaluated before those with a lower score.
	var num_arguments: int ## The number of argument that this operator takes.

	func _init(associativity: int, precedence_score: int, num_arguments: int):
		self.associativity = associativity
		self.precedence_score = precedence_score
		self.num_arguments = num_arguments
