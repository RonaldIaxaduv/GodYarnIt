## An editor UI element for initiating the compilation of a yarn program.
##
## Contains a button for starting the compilation as well as checkboxes
## for printing the generated tokens and the parser tree.
## It seems like this scene and script were still WIP.
@tool
extends VBoxContainer

signal compile_clicked(show_tokens: bool, print_syntax: bool, print_logs: bool)

@export var CompileButton : NodePath ## Pressing this button will start the compilation of the yarn program.
@export var ShowTokensCheckBox : NodePath ## If this CheckBox is ticked, the tokens created by the Lexer will be printed during compilation.
@export var PrintTreeCheckBox : NodePath ## If this CheckBox is ticked, the node tree of the Parser will be printed during compilation.
@export var PrintLogsCheckBox : NodePath ## If this CheckBox is ticked, the Parser and other classes will print more details during their execution.
@export var OpenDialog : NodePath ## TODO FIXME: what was this supposed to do?
@export var Dialog : NodePath ## TODO FIXME: what was this supposed to do?
@export var TestButton : NodePath ## TODO FIXME: what was this supposed to do?


# Called when the node enters the scene tree for the first time.
func _ready():
	get_node(CompileButton).connect("pressed", Callable(self, "_on_compile_pressed"))
	get_node(OpenDialog).connect("pressed", Callable(self, "_on_open_dialog_pressed"))
	get_node(TestButton).connect("pressed", Callable(self, "_on_close_dialog_pressed"))


func _on_compile_pressed():
	compile_clicked.emit(
		(get_node(ShowTokensCheckBox) as CheckBox).button_pressed,
		(get_node(PrintTreeCheckBox) as CheckBox).button_pressed,
		(get_node(PrintLogsCheckBox) as CheckBox).button_pressed
	)


func _on_open_dialog_pressed():
	(get_node(Dialog) as PopupPanel).popup_centered() # used to be PopupDialog


func _on_close_dialog_pressed():
	(get_node(Dialog) as PopupPanel).hide() # used to be PopupDialog
