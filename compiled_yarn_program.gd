## A resource class containing the location of a compiled yarn program and the means to load/save it.
##
## [method compile_programs] compiles all yarn files in [member _yarn_source_code_paths] and
## compiles them into a single compiled yarn program at the designated location.
## The program can be saved/loaded using [method _save_compiled_program] and [method _load_compiled_program].
@tool
class_name CompiledYarnProgram
extends Resource


const ProgramUtils = preload("res://addons/godyarnit/core/program/program_utils.gd")
const GDYarnUtils = preload("res://addons/godyarnit/autoloads/gdyarn_utilities.gd")
const YarnCompiler = preload("res://addons/godyarnit/core/compiler/compiler.gd")

const YarnProgram = ProgramUtils.YarnProgram
const EXTENSION := "cyarn"


@export var _compiled_program_name : String = "compiled_yarn_program": ## this will be the name of the .cyarn file in the given directory
	set = set_program_name
@export_dir var _compiled_program_directory = "res://":
	set = set_dir 
#export(Array, String, FILE, "*.yarn") var _yarn_source_code_paths = []
@export var _yarn_source_code_paths : Array[String] = [] ## Only fill this with file paths leading to .yarn files. Should contain all yarn files that should be contained in the final yarn program.


func _init():
	pass


## Sets the directory that the compiled yarn program will be stored in.
## Used for the [member _compiled_program_directory] member.
func set_dir(value: String) -> void:
	if DirAccess.dir_exists_absolute(value): # assumes that the path is absolute. if it isn't, try DirAccess.open("").dir_exists(value)
		_compiled_program_directory = value
	else:
		printerr("Directory does not exist : %s" % value)


## Sets the name of the compiled yarn program.
## Used for the [member _compiled_program_name] member.
func set_program_name(value: String) -> void:
	_compiled_program_name = value


## Compiles all the program files into a singular program.
## Also ensures that all lines in the programs are tagged.
func _compile_programs(show_tokens: bool, print_syntax: bool, print_logs: bool) -> YarnProgram:
	var programs: Array[YarnProgram] = []
	var yarn_source_codes: Dictionary = {} # [String, String] -> (yarn program file path, yarn program file as text)

	# load all yarn program source files
	for yarn_source_code_path in _yarn_source_code_paths:
		if yarn_source_code_path.is_empty():
			continue

		var f: FileAccess = FileAccess.open(yarn_source_code_path, FileAccess.READ)
		if f == null:
			printerr("CompiledYarnProgram._compile_programs: failed to open file %s (error: %s). Skipped." % [yarn_source_code_path, FileAccess.get_open_error()])
			continue
		
		yarn_source_codes[yarn_source_code_path] = f.get_as_text()
		f.close()
	
	# gather all line tags currently in the files
	var line_tags: Dictionary = GDYarnUtils.get_tags_from_sources(yarn_source_codes)
	
	if line_tags.has("error"):
		printerr("CompiledYarnProgram._compile_programs: found a conflict of line tags that needs to be resolved: %s" % line_tags["error"])
		return
	
	# tag all untagged lines
	var changed_source_codes: Dictionary = GDYarnUtils.tag_untagged_lines(yarn_source_codes, line_tags, print_logs)
	for file_path in changed_source_codes:
		# save any files that have changed due to adding line tags
		var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
		file.store_string(changed_source_codes[file_path])
		file.close()
	
	for source_code_path in yarn_source_codes.keys():
		var source_code: String = yarn_source_codes[source_code_path] # contains a compiled yarn program converted to a string
		if source_code.is_empty():
			continue

		var yarn_program: YarnProgram = _compile_program(source_code, source_code_path, show_tokens, print_syntax, print_logs)
		if yarn_program == null:
			printerr("CompiledYarnProgram: failed to compile yarn program [%s]." % source_code_path)
			return null
		else:
			programs.append(yarn_program)
			if print_logs: print("Compiled yarn program [%s] successfully. %d nodes, %d strings." % [
				source_code_path,
				yarn_program.yarn_nodes.size(),
				yarn_program.yarn_strings.size()
			])
	
	# combine all the programs into a single one
	var programs_copy: Array[YarnProgram] = []
	programs_copy.append_array(programs)
	var combined_yarn_program: YarnProgram = ProgramUtils.combine_programs(programs_copy)
	
	if print_logs: print("Combined yarn program: %s (%d nodes, %d strings)" % [
		combined_yarn_program.program_name,
		combined_yarn_program.yarn_nodes.size(),
		combined_yarn_program.yarn_strings.size()
	])
	
	return combined_yarn_program


## Transforms the given yarn source code into compiled
## yarn nodes and adds them to the given yarn program.
## Optionally prints the tokens and parser syntax of
## the result.
## Returns whether there were any errors.
func _compile_program(
	source_code: String, source_code_path: String, show_tokens: bool, print_syntax: bool, print_logs: bool
) -> YarnProgram:
	var compiler = YarnCompiler.new()
	var e: Error = compiler.compile_string(source_code, source_code_path, show_tokens, print_syntax, print_logs)
	if e != OK:
		return null
	else:
		return compiler._program


## Loads the compiled yarn program according at the location given
## by the [member _compiled_program_name] and [member _compiled_program_directory]
## members.
## Returns the compiled program if the loading was successful, otherwise null.
func _load_compiled_program(locale: String) -> YarnProgram:
	var filepath: String = "%s%s.%s" % [_compiled_program_directory, _compiled_program_name, EXTENSION]
	if FileAccess.file_exists(filepath):
		var program: YarnProgram = ProgramUtils._import_program(filepath, locale)
		program.program_name = _compiled_program_name
		return program
	else:
		printerr("Unable to load program : could not find File [%s] " % filepath)
		return null

## Saves the given yarn program to the location given
## by the [member _compiled_program_name], [member _compiled_program_directory]
## and [const EXTENSION] members.
func _save_compiled_program(program: YarnProgram) -> void:
	var filepath = get_full_file_path()
	ProgramUtils.export_program(YarnProgram.new() if program == null else program, filepath)

func get_full_file_path() -> String:
	var effective_directory: String = _compiled_program_directory
	if not effective_directory == "res://" and not effective_directory.ends_with("/"):
		effective_directory += "/"
	
	return "%s%s.%s" % [effective_directory, _compiled_program_name, EXTENSION]

# func set_files(arr):
# 	if !Engine.editor_hint:
# 		return
# 	if arr.size() > _yarn_source_code_paths.size():
# 		# added new program file
# 		if !arr.back().empty() && !_yarn_source_code_paths.has(arr.back()):
# 			var f = File.new()
# 			f.open(arr.back(),File.READ)
# 			var source : String = f.get_as_text()
# 			f.close()
# 			var p = _compile_program(source,arr.back())
# 			program = p if !program else ProgramUtils.combine_programs([program,p])
# 		_yarn_source_code_paths = arr

# 	elif arr.size() < _yarn_source_code_paths.size():
# 		# removed program
# 		_reload_all_programs(arr)
# 		_yarn_source_code_paths = arr
# 	else:
# 		# we did not remove any program but we updated
# 		# one of the current entries
# 		var index = _get_diff(arr)
# 		if index != -1 && !_yarn_source_code_paths.has(arr[index]):
# 			_reload_all_programs(arr)
# 			_yarn_source_code_paths = arr

#get the change so we can load/unload
# func _get_diff(newOne:Array,offset:int = 0)->int:
# 	for i in range(offset,_yarn_source_code_paths.size()):
# 		if _yarn_source_code_paths[i] != newOne[i]:
# 			return i
# 	return -1

# func set_file(arr):
# 	if arr.size() != _yarn_source_code_paths.size():
# 		if arr.size() > _yarn_source_code_paths.size():
# 			#case where we added a new script
# 			#assume it was added at the end
# 			if (!arr.back().empty()):
# 				var f = File.new()
# 				f.open(arr.back(),File.READ)
# 				var source : String = f.get_as_text()
# 				f.close()
# 				# programs.append(_compile_program(source,arr.back()))

# 		else:
# 			#case where we removed a yarn script
# 			#we have to figure out which one is the
# 			#one we removed and also get rid of the program
# 			var index:int = -1
# 			for i in range(_yarn_source_code_paths.size()):
# 				if !(_yarn_source_code_paths[i] in arr):
# 					index = i
# 					break
# 			if index != -1:
# 				programs.remove(index)
# 	else:
# 		var index:int = _get_diff(arr)
# 		#script was changed
# 		print("difference %s"%index)
# 		if index != -1:

# 			if (!arr[index].empty()):
# 				var f = File.new()
# 				f.open(arr[index],File.READ)
# 				var source : String = f.get_as_text()
# 				f.close()

# 				if programs.size() == arr.size():
# 					# programs[index] = _compile_program(source,arr.back())
# 					emit_signal("program_added",arr.back(),index,source)
# 				else:
# 					# programs.insert(index,_compile_program(source,arr.back()))
# 					emit_signal("program_added",arr.back(),index,source)
#       _yarn_source_code_paths=arr
