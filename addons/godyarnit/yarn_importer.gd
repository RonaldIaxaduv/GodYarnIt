## A subclass of [class EditorImportPlugin] used to import this plugin.
##
## The importer links custom file extensions with their associated Resource class
## through the [method _import] method, which takes in a file and converts it
## into a Resource object.
@tool
class_name YarnImporter
extends EditorImportPlugin

const YARN_TRACKER_PATH := "res://.tracked_yarn_files"


func _ready():
	pass


## Unique name of the importer
func _get_importer_name() -> String:
	return "gdyarn.yarn_file"


## Gets the name to display in the import window ("Import as _get_visible_name()")
func _get_visible_name() -> String:
	return "Yarn File"


## Gets a list of file extensions recognised by this plugin.
## The file extensions are case-insensitive.
func _get_recognized_extensions() -> PackedStringArray:
	return ["yarn"]


## "Gets the extension used to save this resource in the `.godot/imported` directory." - Godot doc
func _get_save_extension() -> String:
	return "tres"


## Returns the Resource class used by this importer.
func _get_resource_type() -> String:
	return "Resource"


enum Presets { Default } ## currently only one preset (not really used)

## Gets the number of presets for this Importer.
func _get_preset_count() -> int:
	return Presets.keys().size()


## "Gets the options and default values for the preset at this index.
## Returns an Array of Dictionaries with the following keys:
## name, default_value, property_hint (optional), hint_string (optional), usage (optional)."
## - Godot doc
func _get_import_options(path: String, preset: int) -> Array[Dictionary]:
	return []


## Gets the name of the given preset. 
func _get_preset_name(preset: int) -> String:
	for key in Presets.keys():
		if Presets[key] == preset:
			return key
	return "Unknown"


## No options hidden.
func _get_option_visibility(path: String, option: StringName, options: Dictionary) -> bool:
	return true


## "Imports source_file_path` into `save_path` with the import `options` specified.
## The `platform_variants` and `gen_files` arrays will be modified by this function."
## - Godot doc
## Here: Creates a Resource file recognised by this plugin from the given source file.
func _import(source_file_path: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> Error:
#	if ResourceLoader.exists(source_file_path):
#		# file has already been imported
#		return OK
#
#		# TODO: check whether source file has changed since the file has been
#		#		imported. if so, re-import after all!
	
	print("YarnImporter: importing " + source_file_path)

	# get all files in the file tracker

	var all_tracked_files := PackedStringArray([])
	var existing_file_tracker : FileAccess

	# Check whether file containing all tracked files already exists.
	# If so, load its contents into all_tracked_files.
	if existing_file_tracker.file_exists(YARN_TRACKER_PATH):
		existing_file_tracker = FileAccess.open(YARN_TRACKER_PATH, FileAccess.READ)
		all_tracked_files = existing_file_tracker.get_as_text().split("\n")
		existing_file_tracker.close()

	if !(source_file_path in all_tracked_files):
		all_tracked_files.append(source_file_path)

	# Check whether all files exist. If any of them don't, delete them.
	var indexes_to_remove := []
	for i in range(all_tracked_files.size()):
		if not FileAccess.file_exists(all_tracked_files[i]):
			indexes_to_remove.append(i)

	for i in indexes_to_remove:
		all_tracked_files.remove_at(i)

	# Update the file containing all tracked files.
	existing_file_tracker = FileAccess.open(YARN_TRACKER_PATH, FileAccess.WRITE)
	existing_file_tracker.store_string(String("\n").join(all_tracked_files))
	existing_file_tracker.close()

	# Check if a file for the new resource has already been created.
	# If so: done.
	var save_file_path: String = "%s.%s" % [save_path, _get_save_extension()]
	if FileAccess.file_exists(save_file_path):
		return OK

	# File for the new resource doesn't exist yet -> create!
	var yarn_file: Resource = Resource.new()
	yarn_file.resource_path = source_file_path
	yarn_file.resource_name = source_file_path.get_file()

	return ResourceSaver.save(yarn_file, save_file_path) # returns OK if successful

## Returns a number determining when this plugin is loaded
## in relation to other plugins.
## Here: loaded first since there are no dependencies atm.
func _get_import_order() -> int:
	return 0 # default (run first -> should be fine since there are no further dependencies)

## Returns the priority of this plugin for its extension. Higher numbers are preferred.
func _get_priority() -> float:
	return 1.0 # default
