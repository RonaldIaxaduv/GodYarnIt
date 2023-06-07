## A resource containing an exported array of file paths pointing to library scripts.
##
## A standard implementation of a library exists with the core/libraries/standard.gd script.
extends Resource

# Original
#export(Array, String, FILE, "*.gd") var libraries setget set_libraries
#@export_file("*.gd") var libraries : Array[String]:
#	get:
#		return libraries
#	set(value):
#		set_libraries(value)

# This isn't quite the same as the original since there is no file filtering
# in there, but i don't think that this is possible atm...
@export var libraries : Array[String]: ## Array of file paths to library files. Only enter paths to .gd files here!
	set = set_libraries
#@export_file("*.gd") var libraries : String setget set_libraries


## Setter method for [member libraries]. Triggers whenever values (libraries)
## are added, changed or removed. Checks if the new/changed library is valid.
func set_libraries(value: Array[String]):
	if value.size() > libraries.size():
		# added a library
		var added = value.back()
		if !added.is_empty():
			var check: Script = load(added)
			if _is_valid_library(check):
				libraries = value
	elif value.size() == libraries.size():
		# library not added but changed
		var changed_index: int = -1
		for i in range(value.size()):
			if libraries[i] != value[i]:
				changed_index = i
				break
		if _is_valid_library(load(value[changed_index]) as Script):
			libraries = value
	else:
		# removed a library -> still valid, nothing to check
		libraries = value


## Valid libraries require a get_function method. This method checks
## whether the given script has such a function.
func _is_valid_library(lib: Script) -> bool:
	if lib.has_method("get_function"):
		return true
	else:
		printerr("Invalid library script : %s")
		printerr("Library scripts must be .gd files containing a get_function method.")
	return false
