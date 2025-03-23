## Various helpers for Yarn execution.
##
## Contains enums for the compiler, (lexical) Tokens and Statements.
## Contains classes and methods for detecting and evaluating format functions (indicated by square brackets).
## This script will be registeren in Godot's autoloads under the name YarnGlobals.
@tool
extends Node

## Execution states of the virtual machine (virtual_machine.gd)
enum ExecutionState { Stopped, Running, WaitingForOption, Suspended }

## Callback states for telling the virtual machine (virtual_machine.gd)
## whether to continue or pause execution after the method.
enum HandlerState { PauseExecution, ContinueExecution }

## Callback enum for the compilation process.
enum CompileStatus {
	Succeeded,
	SucceededUntaggedStrings,
}

## Instruction byte codes for the virtual machine (virtual_machine.gd).
enum ByteCode {
	# opA = string: label name
	Label,
	# opA = string: label name
	JumpTo,
	# peek string from stack and jump to that label
	Jump,
	# opA = int: string number
	RunLine,
	# opA = string: command text
	RunCommand,
	# opA = int: string number for option to add
	AddOption,
	# present the current list of options, then clear the list; most recently
	# selected option will be on the top of the stack
	ShowOptions,
	# opA = int: string number in table; push string to stack
	PushString,
	# opA = float: number to push to stack
	PushNumber,
	# opA = int (0 or 1): bool to push to stack
	PushBool,
	# pushes a null value onto the stack
	PushNull,
	# opA = string: label name if top of stack is not null, zero or false, jumps
	# to that label
	JumpIfFalse,
	# discard top of stack
	Pop,
	# opA = string; looks up function, pops as many arguments as needed, result is
	# pushed to stack
	CallFunc,
	# opA = name of variable to get value of and push to stack
	PushVariable,
	# opA = name of variable to store top of stack in
	StoreVariable,
	# stops execution
	Stop,
	# run the node whose name is at the top of the stack
	RunNode
}


## Names for all lexical tokens (~text patterns) recognised by Yarn Lexer
## in the yarn source code files.
## Examples: Indent, BeginCommand, EndCommand, Set, Add, Xor,…
enum TokenType {
	#0 Special tokens
	Whitespace,
	Indent,
	Dedent,
	EndOfLine,
	EndOfInput,
	#5 Numbers. Everybody loves a number
	Number,
	#6 Strings. Everybody also loves a string
	Str,
	#7 '#'
	TagMarker,
	#8 Command syntax ("<<foo>>")
	BeginCommand, ## <<
	EndCommand, ## >>
	#10 Variables ("$foo")
	Variable, ## $
	#11 Shortcut syntax ("->")
	ShortcutOption, ## ->
	#12 Option syntax ("[[Let's go here|Destination]]")
	OptionStart, ## [[
	OptionDelimit, ## |
	OptionEnd, ## ]]
	# format functions are proccessed further in the compiler
	FormatFunctionStart, ## [
	FormatFunctionEnd, ## ]
	# for inline Expressions
	ExpressionFunctionStart, ## {
	ExpressionFunctionEnd, ## }
	#15 Command types (specially recognised command word)
	IfToken,
	ElseIf,
	ElseToken,
	EndIf,
	Set,
	#20 Boolean values
	TrueToken,
	FalseToken,
	#22 The null value
	NullToken,
	#23 Parentheses
	LeftParen,
	RightParen,
	#25 Parameter delimiters
	Comma,
	#26 Operators
	EqualTo, ## ==, eq, is
	GreaterThan, ## >, gt
	GreaterThanOrEqualTo, ## >=, gte
	LessThan, ## <, lt
	LessThanOrEqualTo, ## <=, lte
	NotEqualTo, ## !=, neq
	#32 Logical operators
	Or, ## ||, or
	And, ## &&, and
	Xor, ## ^, xor
	Not, ## !, not
	# this guy's special because '=' can mean either 'equal to'
	# 36 or 'becomes' depending on context
	EqualToOrAssign, ## =, to
	#37
	UnaryMinus, ## -; this is differentiated from Minus when parsing expressions
	#38
	Add, ## +
	Minus, ## -
	Multiply, ## *
	Divide, ## /
	Modulo, ## %
	#43
	AddAssign, ## +=
	MinusAssign, ## -=
	MultiplyAssign, ## *=
	DivideAssign, ## /=
	Comment, ## a run of text that we ignore
	Identifier, ## a single word (used for functions)
	Text ## a run of text until we hit other syntax
}

## Enum for classifying the type of an expression. Expressions can be
## either values or function calls.
## Used by the Yarn Parser and Yarn Compiler.
enum ExpressionType { Value, FunctionCall }

## Enum of high-level chunks of Yarn code used by the
## Yarn Parser and Yarn Compiler.
## Examples: CustomCommand, ShortcutOptionGroup, IfStatement, Block, Line,...
enum StatementTypes {
	Command,
	ShortcutOptionGroup,
	Block,
	IfStatement,
	OptionStatement,
	AssignmentStatement,
	Line
}

## Categories of values recognised by Yarn.
## Examples: Number, String, Boolean,...
enum ValueType { Number, Str, Boolean, Variable, Nullean }  # null lel

const GDYarnUtils := preload("res://addons/godyarnit/autoloads/gdyarn_utilities.gd")


## Outputs the name of the ValueType item with the given value.
static func get_value_type_name(valueType: int):
	for key in ValueType.keys():
		if ValueType[key] == valueType:
			return key
	return "Invalid"


## NOT IMPLEMENTED
func default_value(type):
	pass

## Outputs the name of the TokenType item with the given value.
static func get_token_type_name(value: int) -> String:
	for key in TokenType.keys():
		if TokenType[key] == value:
			return key
	return "NOTVALID"


## Copies all entires in the patch Dictionary to the target dictionary.
## Overrides shared keys.
static func copy_directory(target: Dictionary, patch: Dictionary):
	for key in patch:
		target[key] = patch[key]


## Same as get_token_type_name but not static. Outputs the name of the TokenType item with the given value.
func get_token_name(type: int) -> String:
	var string: String = ""

	for key in TokenType.keys():
		if TokenType[key] == type:
			return key
	return string


## FORMAT FUNCTION HANDLERS
##
## Contains the name, value and parameters of a format function handler. Also handles errors.
class FormatFunctionData:
	var function_name: String = ""
	var variable_value: String = ""
	var value_map: Dictionary = {} # type: [String, String] -> (value, replacement value)
	var error: String = ""

	func _init():
		pass

	func _error(message: String):
		error = message
		return self


## Evaluates format functions (indicated by square brackets). Handles the following things:
## - error handling (replaces faulty format functions with their error messages)
## - select
## - language-dependent plurals
## - language-dependent ordinal numbers (first, second etc.)
## TODO FIXME: slightly suboptimal performance due to missing RegEx pre-compilation.
func expand_format_functions(input: String, locale: String, enable_logs: bool) -> String:
	#if enable_logs: print("detected locale: %s" % locale)
	var processed_locale: String = locale.split("_")[0]
	var formatted_line: String = input

	# TODO FIXME: probably dont want to compile the regex patterns every time we expand
	#			  a format a function. Scope this up.
	var regex = RegEx.new()

	# find anything inside of square brackets ["--"]
	regex.compile("((?<=\\[)[^\\]]*)")
	var regex_results: Array = regex.search_all(input)
	# print(" %d groups found in line <%s> "% [regex_results.size(), input])
	if !regex_results.is_empty():
		for regexResult in regex_results:
			var segment : String = regexResult.get_string()
			var function_result: FormatFunctionData = parse_function(segment)
			# print("working on string <%s>" % segment)
			if !function_result:  # skip invalid format functions
				continue

			# display error
			if !function_result.error.is_empty():
				formatted_line = formatted_line.replace(
					"[" + segment + "]", "<" + function_result.error + ">"
				)
				printerr("ExecutionStates.expand_format_functions: faulty format function: %s -> %s" % [segment, function_result.error])
				continue

			var pcase : String = ""
			# here we use our pluralisation library to get the correct results
			# printerr("functionName = %s value=[%s] , locale=[%s]" % [function_result.function_name, function_result.variable_value, locale])
			match function_result.function_name:
				"select":
					if enable_logs:
						print("executing selection format function...")
						print("value: %s" % function_result.variable_value)
						print("maps:")
						for key in function_result.value_map.keys():
							print("\t%s -> %s" % [key, function_result.value_map[key]])
					
					if function_result.value_map.has(function_result.variable_value):
						# use specific case
						formatted_line = formatted_line.replace(
							"[" + segment + "]", function_result.value_map[function_result.variable_value]
						)
					else:
						# use "other" case
						formatted_line = formatted_line.replace(
							"[" + segment + "]", function_result.value_map["other"]
						)
				"plural":
					pcase = NumberPlurals.get_plural_case_string(
						NumberPlurals.get_plural_case(processed_locale, float(function_result.variable_value))
					)

				"ordinal":
					if enable_logs:
						print("ordinal case: %d" % NumberPlurals.get_ordinal_case(
								processed_locale, float(function_result.variable_value)
							))
						print("locale: " + processed_locale)
						print("function_result: %d" % float(function_result.variable_value))
						print("number of parameters: %d" % function_result.value_map.size())
						for c in function_result.value_map:
							print(c)
						print("segment: " + segment)
					pcase = NumberPlurals.get_plural_case_string(
						NumberPlurals.get_ordinal_case(
							processed_locale, float(function_result.variable_value)
						)
					)

			if !pcase.is_empty():
				if pcase in function_result.value_map:
					formatted_line = formatted_line.replace(
						"[" + segment + "]", function_result.value_map[pcase]
					)
				else:
					formatted_line = formatted_line.replace("[" + segment + "]", "<%s>" % pcase)

	return formatted_line


## Parses a format function string (indicated by square brackets) and converts it into a FormatFunctionData object.
## Also checks for syntax errors.
## TODO FIXME: should make a parser that actually steps through the input instead of just collecting all the patterns.
## TODO FIXME: slightly suboptimal performance due to missing RegEx pre-compilation.
func parse_function(segment: String) -> FormatFunctionData:
	# expecting a format function in the format:
	#                    name "value" param1="paramValue1" param2="paramValue2"
	#
	#
	# we check if its a valid function if it starts with either
	# select | plural | ordinal
	# TODO FIXME: same as in parse_format_functions, we should move all regex compilations so that they don't compile each time we are parsing a function
	var function_name_regex = RegEx.new()
	function_name_regex.compile("^(?:(?:plural)|(?:ordinal)|(?:select))")

	var values_regex = RegEx.new()
	values_regex.compile('"[^"]*"')  # matches all the values in the string "value"

	var map_regex = RegEx.new()
	map_regex.compile('(?<=\\s)([^\\s]*(?=(?:=")))')  # matches all params

	var function_validator = function_name_regex.search(segment)
	# if this is not a valid function then we just skip it
	if !function_validator:
		return null

	var format_function_data: FormatFunctionData = FormatFunctionData.new()
	var values: Array = values_regex.search_all(segment)
	var maps: Array = map_regex.search_all(segment)

	# first value in the values regex is our function value
	# this means that map_regex should return values_regex.size()-1
	if maps.size() != values.size() - 1:
		printerr("Mismatched parameters! input: ", segment, " params:", maps.size(), " values:", values.size())
		return format_function_data._error("Mismatched parameters")

	format_function_data.function_name = function_validator.get_string()

	# remove quote marks in string:
	format_function_data.variable_value = (values[0] as RegExMatch).get_string().replace('"', "")

	# TODO add position check to
	# param[i].end must be < value[i].start

	for i in range(1, values.size()):
		format_function_data.value_map[maps[i - 1].get_string()] = values[i].get_string().replace('"', "").replace(
			"%", format_function_data.variable_value.replace('"', "")
		)

	return format_function_data
