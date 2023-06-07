## A custom editor inspector for compiling yarn programs.
##
## Instantiates as CompileUi.tscn scene.
extends EditorInspectorPlugin

var compiler_ui: PackedScene = preload("res://addons/godyarnit/ui/CompileUi.tscn")


## TODO FIXME: what is this used for?
func can_handle(object):
	if object.has_method("_handle_command"):
		return true
	return false


## Ensures that the compiler UI compiles its contained
## program when pressing the compile button, and adds
## the UI as a custom control.
func parse_begin(object: CompiledYarnProgram):
	var instance: Node = compiler_ui.instantiate()
	if !instance.is_connected("compile_clicked", Callable(object, "_compile_programs")):
		instance.connect("compile_clicked", Callable(object, "_compile_programs"))

	add_custom_control(instance)
