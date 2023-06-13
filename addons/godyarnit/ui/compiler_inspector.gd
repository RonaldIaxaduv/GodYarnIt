## A custom editor inspector for compiling yarn programs.
##
## Instantiates as CompileUi.tscn scene.
extends EditorInspectorPlugin

const YarnRunner = preload("res://addons/godyarnit/yarn_runner.gd")

var compiler_ui: PackedScene = preload("res://addons/godyarnit/ui/CompileUi.tscn")


## Determines whether this inspector plugin is applied to the passed object's inspector.
func _can_handle(object: Object) -> bool:
	var is_runner: bool = (object as YarnRunner) != null
	return is_runner


## Ensures that the compiler UI compiles its contained
## program when pressing the compile button, and adds
## the UI as a custom control.
func _parse_begin(object: Object) -> void:
	var instance: Node = compiler_ui.instantiate()
	if !instance.is_connected("compile_clicked", Callable(object, "_compile_programs")):
		instance.connect("compile_clicked", Callable(object, "_compile_programs"))

	add_custom_control(instance)
