## Lexical analysis script. Converts a sequence of characters into lexical tokens (~text patterns) recognised by Yarn.
##
## The lexer is implemented through a state machine (using a dictionary) with various transition rules.
## To implement new tokens, new states and transition rules need to be added.

const LINE_COMMENT: String = "//"
const FORWARD_SLASH: String = "/"

const LINE_SEPARATOR: String = "\n"

const BASE: String = "base"
const COMMAND: String = "command"
const LINK: String = "link"
const SHORTCUT: String = "shortcut"
const TAG: String = "tag"
const EXPRESSION: String = "expression"
const ASSIGNMENT: String = "assignment"
const OPTION: String = "option"
const DESTINATION: String = "destination"
const FORMAT_FUNCTION: String = "format"
const WHITESPACE: String = "\\s*"

var error = OK

var _states: Dictionary = {}
var _default_state: LexerState
var _current_state: LexerState

var _indent_stack: Array[IntBoolPair] = []
var _should_track_indent: bool = false


func _init():
	create_states()


## Creates lexer states that handle all the various token patterns.
## TODO: FIXME: Add transition from shortcut options and option links into inline expressions and format functions
## TODO: FIXME - Tags are not being proccessed properly. We must look for the format #{identifier}:{value}
##       Possible solution is to add more transitions
func create_states() -> void:
	# create a dictionary containing RegEx patterns for all supported tokens
	var patterns: Dictionary = {}
	patterns[YarnGlobals.TokenType.Text] = ".*"

	patterns[YarnGlobals.TokenType.Number] = "\\-?[0-9]+(\\.[0-9]+)?"
	patterns[YarnGlobals.TokenType.Str] = '"([^"\\\\]*(?:\\.[^"\\\\]*)*)"'
	patterns[YarnGlobals.TokenType.TagMarker] = "#"  #"(#[a-zA-Z]+:)"
	patterns[YarnGlobals.TokenType.LeftParen] = "\\("
	patterns[YarnGlobals.TokenType.RightParen] = "\\)"
	patterns[YarnGlobals.TokenType.EqualTo] = "(==|is(?!\\w)|eq(?!\\w))"
	patterns[YarnGlobals.TokenType.EqualToOrAssign] = "(=|to(?!\\w))"
	patterns[YarnGlobals.TokenType.NotEqualTo] = "(\\!=|neq(?!\\w))"
	patterns[YarnGlobals.TokenType.GreaterThanOrEqualTo] = "(\\>=|gte(?!\\w))"
	patterns[YarnGlobals.TokenType.GreaterThan] = "(\\>|gt(?!\\w))"
	patterns[YarnGlobals.TokenType.LessThanOrEqualTo] = "(\\<=|lte(?!\\w))"
	patterns[YarnGlobals.TokenType.LessThan] = "(\\<|lt(?!\\w))"
	patterns[YarnGlobals.TokenType.AddAssign] = "\\+="
	patterns[YarnGlobals.TokenType.MinusAssign] = "\\-="
	patterns[YarnGlobals.TokenType.MultiplyAssign] = "\\*="
	patterns[YarnGlobals.TokenType.DivideAssign] = "\\/="
	patterns[YarnGlobals.TokenType.Add] = "\\+"
	patterns[YarnGlobals.TokenType.Minus] = "\\-"
	patterns[YarnGlobals.TokenType.Multiply] = "\\*"
	patterns[YarnGlobals.TokenType.Divide] = "\\/"
	patterns[YarnGlobals.TokenType.Modulo] = "\\%"
	patterns[YarnGlobals.TokenType.And] = "(\\&\\&|and(?!\\w))"
	patterns[YarnGlobals.TokenType.Or] = "(\\|\\||or(?!\\w))"
	patterns[YarnGlobals.TokenType.Xor] = "(\\^|xor(?!\\w))"
	patterns[YarnGlobals.TokenType.Not] = "(\\!|not(?!\\w))"
	patterns[YarnGlobals.TokenType.Variable] = "\\$([A-Za-z0-9_\\.])+"
	patterns[YarnGlobals.TokenType.Comma] = "\\,"
	patterns[YarnGlobals.TokenType.TrueToken] = "true(?!\\w)"
	patterns[YarnGlobals.TokenType.FalseToken] = "false(?!\\w)"
	patterns[YarnGlobals.TokenType.NullToken] = "null(?!\\w)"
	patterns[YarnGlobals.TokenType.BeginCommand] = "\\<\\<"
	patterns[YarnGlobals.TokenType.EndCommand] = "\\>\\>"
	patterns[YarnGlobals.TokenType.OptionStart] = "\\[\\["
	patterns[YarnGlobals.TokenType.OptionEnd] = "\\]\\]"
	patterns[YarnGlobals.TokenType.OptionDelimit] = "\\|"
	patterns[YarnGlobals.TokenType.ExpressionFunctionStart] = "\\{"
	patterns[YarnGlobals.TokenType.ExpressionFunctionEnd] = "\\}"
	patterns[YarnGlobals.TokenType.FormatFunctionStart] = "(?<!\\[)\\[(?!\\[)"
	patterns[YarnGlobals.TokenType.FormatFunctionEnd] = "\\]"
	patterns[YarnGlobals.TokenType.Identifier] = "[a-zA-Z0-9_:\\.]+"
	patterns[YarnGlobals.TokenType.IfToken] = "if(?!\\w)"
	patterns[YarnGlobals.TokenType.ElseToken] = "else(?!\\w)"
	patterns[YarnGlobals.TokenType.ElseIf] = "elseif(?!\\w)"
	patterns[YarnGlobals.TokenType.EndIf] = "endif(?!\\w)"
	patterns[YarnGlobals.TokenType.Set] = "set(?!\\w)"
	patterns[YarnGlobals.TokenType.ShortcutOption] = "\\-\\>\\s*"

	# compound states
	var shortcut_option: String = SHORTCUT + "-" + OPTION
	var shortcut_option_tag: String = shortcut_option + "-" + TAG
	var command_or_expression: String = COMMAND + "-" + "or" + "-" + EXPRESSION
	var link_destination: String = LINK + "-" + DESTINATION
	var format_expression: String = FORMAT_FUNCTION + "-" + EXPRESSION
	var inline_expression: String = "inline" + "-" + EXPRESSION

	# TODO: FIXME: Add transition from shortcut options and option links into inline expressions and format functions

	_states = {} # clear state dictionary

	_states[BASE] = LexerState.new(patterns)
	_states[BASE].add_transition(YarnGlobals.TokenType.BeginCommand, COMMAND, true)
	_states[BASE].add_transition(
		YarnGlobals.TokenType.ExpressionFunctionStart, inline_expression, true
	)
	_states[BASE].add_transition(YarnGlobals.TokenType.FormatFunctionStart, FORMAT_FUNCTION, true)
	_states[BASE].add_transition(YarnGlobals.TokenType.OptionStart, LINK, true)
	_states[BASE].add_transition(YarnGlobals.TokenType.ShortcutOption, shortcut_option)
	_states[BASE].add_transition(YarnGlobals.TokenType.TagMarker, TAG, true)
	_states[BASE].add_text_rule(YarnGlobals.TokenType.Text)

	#TODO: FIXME - Tags are not being proccessed properly this way. We must look for the format #{identifier}:{value}
	#              Possible solution is to add more transitions
	_states[TAG] = LexerState.new(patterns)
	_states[TAG].add_transition(YarnGlobals.TokenType.Identifier, BASE)

	_states[shortcut_option] = LexerState.new(patterns)
	_states[shortcut_option].track_indent = true
	_states[shortcut_option].add_transition(YarnGlobals.TokenType.BeginCommand, EXPRESSION, true)
	_states[shortcut_option].add_transition(
		YarnGlobals.TokenType.ExpressionFunctionStart, inline_expression, true
	)
	_states[shortcut_option].add_transition(
		YarnGlobals.TokenType.TagMarker, shortcut_option_tag, true
	)
	_states[shortcut_option].add_text_rule(YarnGlobals.TokenType.Text, BASE)

	_states[shortcut_option_tag] = LexerState.new(patterns)
	_states[shortcut_option_tag].add_transition(YarnGlobals.TokenType.Identifier, shortcut_option)

	_states[COMMAND] = LexerState.new(patterns)
	_states[COMMAND].add_transition(YarnGlobals.TokenType.IfToken, EXPRESSION)
	_states[COMMAND].add_transition(YarnGlobals.TokenType.ElseToken)
	_states[COMMAND].add_transition(YarnGlobals.TokenType.ElseIf, EXPRESSION)
	_states[COMMAND].add_transition(YarnGlobals.TokenType.EndIf)
	_states[COMMAND].add_transition(YarnGlobals.TokenType.Set, ASSIGNMENT)
	_states[COMMAND].add_transition(YarnGlobals.TokenType.EndCommand, BASE, true)
	_states[COMMAND].add_transition(YarnGlobals.TokenType.Identifier, command_or_expression)
	_states[COMMAND].add_text_rule(YarnGlobals.TokenType.Text)

	_states[command_or_expression] = LexerState.new(patterns)
	_states[command_or_expression].add_transition(YarnGlobals.TokenType.LeftParen, EXPRESSION)
	_states[command_or_expression].add_transition(YarnGlobals.TokenType.EndCommand, BASE, true)
	_states[command_or_expression].add_text_rule(YarnGlobals.TokenType.Text)

	_states[ASSIGNMENT] = LexerState.new(patterns)
	_states[ASSIGNMENT].add_transition(YarnGlobals.TokenType.Variable)
	_states[ASSIGNMENT].add_transition(YarnGlobals.TokenType.EqualToOrAssign, EXPRESSION)
	_states[ASSIGNMENT].add_transition(YarnGlobals.TokenType.AddAssign, EXPRESSION)
	_states[ASSIGNMENT].add_transition(YarnGlobals.TokenType.MinusAssign, EXPRESSION)
	_states[ASSIGNMENT].add_transition(YarnGlobals.TokenType.MultiplyAssign, EXPRESSION)
	_states[ASSIGNMENT].add_transition(YarnGlobals.TokenType.DivideAssign, EXPRESSION)

	_states[FORMAT_FUNCTION] = LexerState.new(patterns)
	_states[FORMAT_FUNCTION].add_transition(YarnGlobals.TokenType.FormatFunctionEnd, BASE, true)
	_states[FORMAT_FUNCTION].add_transition(
		YarnGlobals.TokenType.ExpressionFunctionStart, format_expression, true
	)
	_states[FORMAT_FUNCTION].add_text_rule(YarnGlobals.TokenType.Text)

	_states[format_expression] = LexerState.new(patterns)
	_states[format_expression].add_transition(
		YarnGlobals.TokenType.ExpressionFunctionEnd, FORMAT_FUNCTION
	)
	form_expression_state(_states[format_expression])

	_states[inline_expression] = LexerState.new(patterns)
	_states[inline_expression].add_transition(YarnGlobals.TokenType.ExpressionFunctionEnd, BASE)
	form_expression_state(_states[inline_expression])

	_states[EXPRESSION] = LexerState.new(patterns)
	_states[EXPRESSION].add_transition(YarnGlobals.TokenType.EndCommand, BASE)
	#_states[EXPRESSION].add_transition(YarnGlobals.TokenType.FormatFunctionEnd,BASE)
	form_expression_state(_states[EXPRESSION])

	_states[LINK] = LexerState.new(patterns)
	_states[LINK].add_transition(YarnGlobals.TokenType.OptionEnd, BASE, true)
	_states[LINK].add_transition(YarnGlobals.TokenType.ExpressionFunctionStart, "link-ee", true)
	_states[LINK].add_transition(YarnGlobals.TokenType.FormatFunctionStart, "link-ff", true)
	_states[LINK].add_transition(YarnGlobals.TokenType.FormatFunctionEnd, LINK, true)
	_states[LINK].add_transition(YarnGlobals.TokenType.OptionDelimit, link_destination, true)
	_states[LINK].add_text_rule(YarnGlobals.TokenType.Text)

	_states["link-ff"] = LexerState.new(patterns)
	_states["link-ff"].add_transition(YarnGlobals.TokenType.FormatFunctionEnd, LINK, true)
	_states["link-ff"].add_transition(
		YarnGlobals.TokenType.ExpressionFunctionStart, "link-ee", true
	)
	_states["link-ff"].add_text_rule(YarnGlobals.TokenType.Text)

	_states["link-ee"] = LexerState.new(patterns)
	_states["link-ee"].add_transition(YarnGlobals.TokenType.ExpressionFunctionEnd, LINK)
	form_expression_state(_states["link-ee"])

	_states[link_destination] = LexerState.new(patterns)
	_states[link_destination].add_transition(YarnGlobals.TokenType.Identifier)
	_states[link_destination].add_transition(YarnGlobals.TokenType.OptionEnd, BASE)

	_default_state = _states[BASE]

	for state_key in _states.keys():
		_states[state_key].state_name = state_key

	pass


func form_expression_state(expression_state) -> void:
	expression_state.add_transition(YarnGlobals.TokenType.Number)
	expression_state.add_transition(YarnGlobals.TokenType.Str)
	expression_state.add_transition(YarnGlobals.TokenType.LeftParen)
	expression_state.add_transition(YarnGlobals.TokenType.RightParen)
	expression_state.add_transition(YarnGlobals.TokenType.EqualTo)
	expression_state.add_transition(YarnGlobals.TokenType.EqualToOrAssign)
	expression_state.add_transition(YarnGlobals.TokenType.NotEqualTo)
	expression_state.add_transition(YarnGlobals.TokenType.GreaterThanOrEqualTo)
	expression_state.add_transition(YarnGlobals.TokenType.GreaterThan)
	expression_state.add_transition(YarnGlobals.TokenType.LessThanOrEqualTo)
	expression_state.add_transition(YarnGlobals.TokenType.LessThan)
	expression_state.add_transition(YarnGlobals.TokenType.Add)
	expression_state.add_transition(YarnGlobals.TokenType.Minus)
	expression_state.add_transition(YarnGlobals.TokenType.Multiply)
	expression_state.add_transition(YarnGlobals.TokenType.Divide)
	expression_state.add_transition(YarnGlobals.TokenType.Modulo)
	expression_state.add_transition(YarnGlobals.TokenType.And)
	expression_state.add_transition(YarnGlobals.TokenType.Or)
	expression_state.add_transition(YarnGlobals.TokenType.Xor)
	expression_state.add_transition(YarnGlobals.TokenType.Not)
	expression_state.add_transition(YarnGlobals.TokenType.Variable)
	expression_state.add_transition(YarnGlobals.TokenType.Comma)
	expression_state.add_transition(YarnGlobals.TokenType.TrueToken)
	expression_state.add_transition(YarnGlobals.TokenType.FalseToken)
	expression_state.add_transition(YarnGlobals.TokenType.NullToken)
	expression_state.add_transition(YarnGlobals.TokenType.Identifier)


## Create tokens for the entirety of the given text (may consist of several lines).
## Line numbering starts at the given value.
## This will be called in the compiler.gd script on the body of the respective yarn code.
func tokenize(text: String, line_number: int) -> Array[Token]:
	_indent_stack.clear()
	_indent_stack.push_front(IntBoolPair.new(0, false))
	_should_track_indent = false

	var tokens: Array[Token] = [] as Array[Token]

	_current_state = _default_state

	var lines: PackedStringArray = text.split(LINE_SEPARATOR)
	lines.append("")

	# var line_number : int = 1

	# tokenize each line
	for line in lines:
		if error != OK:
			break
		tokens.append_array(tokenize_line(line, line_number))
		line_number += 1

	var end_of_input: Token = Token.new(
		YarnGlobals.TokenType.EndOfInput, _current_state, line_number, 0
	)
	tokens.append(end_of_input)

	return tokens


## Create tokens for the given line of text.
func tokenize_line(line: String, line_number: int) -> Array[Token]:
	var token_stack: Array[Token] = []

	var fresh_line = line.replace("\t", "    ").replace("\r", "")

	# record indentation
	var indentation: int = get_line_indentation_depth(fresh_line)
	#printerr("line indentation of ((%s)) is %d !!!!!%s" %[freshLine, indentation,str(_shouldTrackIndent)])
	var prev_indentation: IntBoolPair = _indent_stack.front()

	if _should_track_indent && indentation > prev_indentation.key:
		# indent depth increased -> add indenation token to record indent level
		_indent_stack.push_front(IntBoolPair.new(indentation, true))

		var indent_token: Token = Token.new(
			YarnGlobals.TokenType.Indent, _current_state, line_number, prev_indentation.key
		)
		indent_token.value = "%*s" % [indentation - prev_indentation.key, "0"]

		_should_track_indent = false
		token_stack.push_front(indent_token)

	elif indentation < prev_indentation.key: # TODO FIXME: should this also check for _shouldTrackIndent?
		# indent depth decreased -> add dedentation token to record indent level

		while indentation < _indent_stack.front().key:
			var top: IntBoolPair = _indent_stack.pop_front()
			if top.value:
				var dedent_token: Token = Token.new(
					YarnGlobals.TokenType.Dedent, _current_state, line_number, 0
				)
				token_stack.push_front(dedent_token)
	
	var token_count_pre_eval: int = token_stack.size() # used to determine whether line was empty (after the big while loop)
	var offset: int = indentation

	var whitespace: RegEx = RegEx.new()
	var _ok = whitespace.compile(WHITESPACE)
	if _ok != OK:
		printerr("unable to compile the whitespace regex")
		error = ERR_COMPILATION_FAILED
		return []

	# create all non-indent tokens for this line
	while offset < fresh_line.length():
		if fresh_line.substr(offset).begins_with(LINE_COMMENT):
			break

		var matched: bool = false

		for rule in _current_state.rules:
			var found: RegExMatch = rule.regex.search(fresh_line, offset)

			if !found:
				continue

			var token_text: String

			if rule.token_type == YarnGlobals.TokenType.Text:
				# if this is text then we back up to the most recent
				# delimiting token and treat everything from there as text.

				var start_index: int = indentation

				if token_stack.size() > 0:
					while token_stack.front().token_type == YarnGlobals.TokenType.Identifier:
						var t = token_stack.pop_front()
						# if t.token_type == YarnGlobals.TokenType.Indent:
						# printerr("popped off some indentation")

					var start_delimit_token: Token = token_stack.front()
					start_index = start_delimit_token.offset

					if start_delimit_token.token_type == YarnGlobals.TokenType.Indent:
						start_index += start_delimit_token.value.length()
					if start_delimit_token.token_type == YarnGlobals.TokenType.Dedent:
						start_index = indentation

				offset = start_index
				var end_index: int = found.get_start() + found.get_string().length()

				token_text = fresh_line.substr(start_index, end_index - start_index)

			else:
				# not a text token
				token_text = found.get_string()

			# advance offset by the text found by the currently checked rule
			offset += token_text.length()

			# pre-proccess string
			if rule.token_type == YarnGlobals.TokenType.Str:
				token_text = token_text.substr(1, token_text.length() - 2)
				token_text = token_text.replace("\\\\", "\\")
				token_text = token_text.replace('\\"', '"')

			var token: Token = Token.new(
				rule.token_type, _current_state, line_number, offset, token_text
			)
			token.delimits_text_start = rule.delimits_text_start

			token_stack.push_front(token)

			if rule.target_state != null && rule.target_state.length() > 0:
				if !_states.has(rule.target_state):
					printerr(
						(
							"Tried to enter unknown lexer state: [%s] - line(%s) offset(%s)"
							% [rule.enter_state, line_number, offset]
						)
					)
					error = ERR_DOES_NOT_EXIST
					return []

				enter_state(_states[rule.target_state])

				if _should_track_indent:
					if _indent_stack.front().key < indentation:
						_indent_stack.append(IntBoolPair.new(indentation, false))

			matched = true
			break

		if !matched:
			printerr(
				(
					"Lexer couldn't resolve a section of text: expectedTokens [%s] - line(%s) offset(%s)"
					% [_current_state.expected_tokens_string(), line_number, offset]
				)
			)
			error = ERR_INVALID_DATA
			return []
		
		# handle whitespace characters trailing this token
		var last_white_space: RegExMatch = whitespace.search(fresh_line, offset)
		if last_white_space and last_white_space.get_string().length() > 0:
			if !check_token_ignores_trailing_whitespace(token_stack):
				# don't ignore whitespace characters after certain tokens, e.g. format functions
				var whitespace_token: Token = Token.new(
					YarnGlobals.TokenType.Text, _current_state, line_number, offset + last_white_space.get_string().length(),
					fresh_line.substr(offset, last_white_space.get_string().length()))
				whitespace_token.delimits_text_start = true
				token_stack.push_front(whitespace_token)
			#else:
			#	# ignore trailing whitespace
			offset += last_white_space.get_string().length()

	# here: tokenization of the line completed.
	
	if token_stack.size() == token_count_pre_eval:
		# no tokens have been generated while evaluating the line -> line was empty
		var spacer_token: Token = Token.new(
			YarnGlobals.TokenType.Whitespace, _current_state, line_number, offset, fresh_line
		)
		token_stack.append(spacer_token)

	# if tokenStack.size() >= 1 && (tokenStack.front().token_type == YarnGlobals.TokenType.Text || tokenStack.front().token_type == YarnGlobals.TokenType.Identifier):
	# 	tokenStack.push_front(Token.new(YarnGlobals.TokenType.EndOfLine,_currentState,lineNumber,column,"break"))
	token_stack.reverse() # pushed everything to the front so far, so to match the order of the tokens in the actual text, everything needs to be reversed

	return token_stack


## Checks whether the previously added token should ignore whitespaces that
## follow it.
## This is important to allow whitespaces between format functions and
## expressions, e.g. "[format function] [another format function]".
func check_token_ignores_trailing_whitespace(token_stack: Array[Token]):
	return not ((token_stack.front() as Token).token_type == YarnGlobals.TokenType.FormatFunctionEnd
		or (token_stack.front() as Token).token_type == YarnGlobals.TokenType.ExpressionFunctionEnd)


## Gets the indentation depth of the given line
func get_line_indentation_depth(line: String) -> int:
	var indent_regex: RegEx = RegEx.new()
	indent_regex.compile("^(?:\\s*)")

	var found: RegExMatch = indent_regex.search(line)

	if !found || found.get_string().length() <= 0:
		return 0

	return found.get_string().length()


## Makes the lexer enter the given state.
func enter_state(state: LexerState) -> void:
	_current_state = state
	_should_track_indent = true if _current_state.track_indent else _should_track_indent


## A lexical token of a given type (YarnGlobals.TokenType enum) in a given section of text.
## 
## 
class Token:
	var token_type: int
	var value: String

	var line_number: int
	var offset: int
	var text: String

	var delimits_text_start: bool = false
	var param_count: int
	var lexer_state: String

	func _init(
		token_type: int, state: LexerState, line_number: int = -1, offset: int = -1, value: String = ""
	):
		self.token_type = token_type
		self.lexer_state = state.state_name
		self.line_number = line_number
		self.offset = offset
		self.value = value

	func _to_string():
		return (
			"%s (%s) at %s:%s (state: %s)"
			% [YarnGlobals.get_token_name(token_type), value, line_number, offset, lexer_state]
		)


## State machine nodes for the lexer.
##
## Contains methods for adding transitions and transition rules (using RegEx patterns) to other states.
class LexerState:
	var state_name: String
	var patterns: Dictionary ## RegEx patterns for all supported tokens
	var rules: Array[Rule] = []
	var track_indent: bool = false

	func _init(patterns):
		self.patterns = patterns
	
	## Adds a state transition from this state to a given other state upon detection of the given token.
	## Returns the newly created transition rule. The rule is also added to the rules array.
	func add_transition(token_type: int, target_state: String = "", delimit_text: bool = false) -> Rule:
		var pattern = "\\G%s" % patterns[token_type]
		var rule = Rule.new(token_type, pattern, target_state, delimit_text)
		rules.append(rule)
		return rule

	## 
	func add_text_rule(token_type: int, target_state: String = "") -> Rule:
		if contains_text_rule():
			printerr("State already contains Text rule")
			return null

		var delimiters: PackedStringArray = []
		for rule in rules:
			if rule.delimits_text_start:
				delimiters.append("%s" % rule.regex.get_pattern().substr(2))

		var pattern: String = "\\G((?!%s).)*" % [String("|").join(delimiters)]
		var rule: Rule = add_transition(token_type, target_state)
		rule.regex = RegEx.new()
		rule.regex.compile(pattern)
		rule.is_text_rule = true
		return rule

	## Returns a string listing all the tokens (strings of YarnGlobals.TokenType) that this state recognises.
	func expected_tokens_string() -> String:
		var result = ""
		for rule in rules:
			result += "" + YarnGlobals.token_name(rule.token_type)
		return result
	
	## Returns true if this state contains a text rule
	func contains_text_rule() -> bool:
		for rule in rules:
			if rule.is_text_rule:
				return true
		return false


## Rule for detecting a certain token using a certain RegEx, used for transitioning to a new lexer state.
## 
## Also stores some information, e.g. which lexer state it transitions to.
class Rule:
	var regex: RegEx

	var target_state: String
	var token_type: int
	var is_text_rule: bool
	var delimits_text_start: bool # if there's text following the token created by this rule, the text will be parsed starting at the token's offset value

	func _init(token_type: int, regex_pattern: String, target_state: String, delimits_text_start: bool):
		self.token_type = token_type
		self.regex = RegEx.new()
		self.regex.compile(regex_pattern)
		self.target_state = target_state
		self.delimits_text_start = delimits_text_start
		self.is_text_rule = false

	func _to_string():
		return "[Rule : %s - %s]" % [YarnGlobals.token_name(token_type), regex]


## A simple tuple containing a single [int, bool] value pair.
class IntBoolPair:
	var key: int
	var value: bool

	func _init(key: int, value: bool):
		self.key = key
		self.value = value
