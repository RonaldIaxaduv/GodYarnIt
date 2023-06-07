## A script for handling the (de)activation of this plugin.
##
## Handles the automatic (un)registration of autoloads, new node types,
## tool menu items and inspectors, as well as telling Godot how to
## import and read the plugin (using the YarnImporter class).
@tool
extends EditorPlugin

const CompilerInspector: Script = preload("res://addons/godyarnit/ui/compiler_inspector.gd") # uses the CompileUi
const LocalizerScene: PackedScene = preload("res://addons/godyarnit/ui/LocalizerGui.tscn")

const LOCALIZER_NAME: String = "GodYarnIt Localiser" ## name of the localiser menu item under Project > Tools

var autoloads: Dictionary = {
	"NumberPlurals": "res://addons/godyarnit/autoloads/number_plurals.gd",
	"YarnGlobals": "res://addons/godyarnit/autoloads/execution_states.gd",
	# "GDYarnUtils" : "res://addons/godyarnit/autoloads/gdyarn_utilities.gd"
} ## scripts that will autoamtically be placed in the autoloads section of Godot (necessary for the plugin to function!)

var custom_nodes: Dictionary = {
	#name            #parent         #script                                     #icon
	"YarnRunner":
	["Node", "res://addons/godyarnit/yarn_runner.gd", "res://addons/godyarnit/assets/runner.PNG"],
} ## custom node types that will automatically be added to Godot's node type tree

var localizer_gui # type LocalizerScene
var compiler_inspector # type CompilerInspector

var yarn_importer: YarnImporter = null


## Called when the plugin is activated.
## Registers the new plugin and adds new content.
func _enter_tree():
	# Register the editor import plugin.
	# "Import plugins are used to import custom and unsupported assets as a custom Resource type." - Godot doc
	yarn_importer = YarnImporter.new()
	add_import_plugin(yarn_importer)

	# Automatically add scripts to the autoloads section of Godot (if they haven't been registered already).
	for auto in autoloads.keys():
		add_autoload_singleton(auto, autoloads[auto])

	# Audomatically add custom types (nodes) to the node type tree of Godot.
	for node in custom_nodes.keys():
		add_custom_type(node, custom_nodes[node][0], load(custom_nodes[node][1]), load(custom_nodes[node][2]))

	localizer_gui = LocalizerScene.instantiate()
	localizer_gui._initiate()
	add_child(localizer_gui)
	if localizer_gui.visible:
		localizer_gui.get_ok_button()._pressed()
	
	# add UI element for compilation
	compiler_inspector = CompilerInspector.new()

	# add menu item under Project > Tools
	add_tool_menu_item(LOCALIZER_NAME, Callable(self, "open_localizer_gui"))

	add_inspector_plugin(compiler_inspector) # Inspector plugins are used to extend EditorInspector and provide custom configuration tools for object's properties.


## Called when the plugin is deactivated.
## Un-registers the plugin and removes any previously added content.
func _exit_tree():
	for auto in autoloads.keys():
		remove_autoload_singleton(auto)

	for node in custom_nodes.keys():
		remove_custom_type(node)

	remove_inspector_plugin(compiler_inspector)
	remove_tool_menu_item(LOCALIZER_NAME)
	remove_import_plugin(yarn_importer)

	yarn_importer = null


## Called when the menu item in **Project > Tools** with the name of [const LOCALIZER_NAME] is clicked.
func open_localizer_gui():
	localizer_gui.popup_centered()
