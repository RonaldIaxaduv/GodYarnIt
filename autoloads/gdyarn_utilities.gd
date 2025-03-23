## Various Utility Tools for Yarn
##
## Contains methods for tagging lines (incl. tag detection determining whether a line should be tagged).
## Contains methods for CSV (comma-separated values) file handling.


######################### LineTag Utilities #########################

const lineTagPattern: String = "#line:(?:[0-9]|(?:a|b|c|d|e|f))+" # regex pattern to get the line tag in the line if it exists
const commandStartPatern: String = "^(?:<<)" # regex pattern to detect the beginning of a command (<<)
const commentTrimPattern: String = "(?(?=^\\/\\/)|(?(?=.*\\/\\/)(?:.+?(?=\\/\\/))|.*))" # regex pattern used to trim the comments from lines


## Generate a line tag (32bit hex value) using a given seed.
## This is 8 bits larger than the yarnspinner implementation
## which should prevent collisions between nodes.
static func generate_line_tag(s: int) -> String:
	var rng = RandomNumberGenerator.new()
	rng.seed = s
	var tagNum = rng.randi()
	return "line:%x" % tagNum


## Tag all untagged lines in the sources and then return any files that need to be saved to disk.
## Will return in the format {file,new_source}.
static func tag_untagged_lines(sources: Dictionary, tags: Dictionary, enable_log: bool) -> Dictionary:
	var changed_files := {}

	for source_key in sources:
		var source = sources[source_key]
		var line_number: int = 0
		var changed: bool = false

		var file_lines: PackedStringArray = source.split("\n", true)
		# printerr("source lines %s" % file_lines.size())
		for i in range(file_lines.size()):
			file_lines[i] = file_lines[i].strip_edges(false, true)

		while line_number < file_lines.size():
			# get title
			while line_number < file_lines.size() && file_lines[line_number] != "---":
				line_number += 1

			line_number += 1

			while line_number < file_lines.size() && file_lines[line_number] != "===":
				var tag : String = get_line_tag(file_lines[line_number])
				if should_tag_line(file_lines[line_number]) && tag.is_empty():
					# no tag found so we make one
					var tagSeed: int = (
						(
							33 * line_number * Time.get_time_dict_from_system().second # instead of get_time
							+ source_key.hash()
							+ file_lines[line_number].hash()
						)
						% 65537
					)
					var searchingForValidTag: bool = true
					while searchingForValidTag:
						tag = generate_line_tag(tagSeed)

						if enable_log: print("returning tag : %s" % tag)
						if !tags.has(tag):
							tags[tag] = source_key
							changed = true
							file_lines.set(line_number, add_tag_to_line(file_lines[line_number], tag))
							searchingForValidTag = false
							if enable_log: print("tag added ")
						else:
							tagSeed = ((tagSeed << 1) * 89) % 65537

				line_number += 1

			line_number += 1
		if changed:
			sources[source_key] = String("\n").join(file_lines)
			changed_files[source_key] = sources[source_key]

	return changed_files


## Gets all the line tags from the passed sources dictionary. Returned as a dictionary of the form {tag : source_key}.
## Entries in the dictionary are in the format {file : source}.
## Returns dictionary with an {error : message} key value pair if there is a conflict.
static func get_tags_from_sources(sources: Dictionary) -> Dictionary:
	var lineTags: Dictionary = {}

	for source_key in sources:
		var source = sources[source_key]
		var line_number: int = 0

		var file_lines: PackedStringArray = source.split("\n", true)
		# printerr("source lines %s" % file_lines.size())
		for i in range(file_lines.size()):
			file_lines[i] = file_lines[i].strip_edges(false, true)

		while line_number < file_lines.size():
			# get title
			while line_number < file_lines.size() && file_lines[line_number] != "---":
				line_number += 1

			line_number += 1

			while line_number < file_lines.size() && file_lines[line_number] != "===":
				var tag : String = get_line_tag(file_lines[line_number])
				if lineTags.has(tag):
					printerr("duplicate line tag[%s] in file[%s] and file[%s]" % [tag, source_key, lineTags[tag]])
					return {
						"error":
						(
							"duplicate line tag[%s] in file[%s] and file[%s]"
							% [tag, source_key, lineTags[tag]]
						)
					}
				if !tag.is_empty():
					lineTags[tag] = source_key
				line_number += 1

			line_number += 1

	return lineTags


## Gets all the tags in the node body in an array.
static func get_all_tags(sourceLines: Array) -> Array[String]:
	var results := []
	for line in sourceLines:
		var lineTag : String = get_line_tag(line)
		if !lineTag.is_empty():
			results.append(lineTag)
	return results


# get the line tag for the passd in line
#
# we will stop looking once we start a comment line,
# reach the end, or find a line tag in the form #line:<value>
static func get_line_tag(line: String) -> String:
	# regex used to trim the comments from lines
	var commentTrimRegex: RegEx = RegEx.new()

	# regex to get the line tag in the line if it exists
	var lineTagRegex: RegEx = RegEx.new()

	commentTrimRegex.compile(commentTrimPattern)
	lineTagRegex.compile(lineTagPattern)
	# then we strip the line of comments
	# this is to make sure that we are not finding any tags that are
	# commented out
	var trimmedLine: RegExMatch = commentTrimRegex.search(line)

	if trimmedLine && !trimmedLine.get_string().is_empty():
		# find the line tag and return it if found
		var lineTagMatch: RegExMatch = lineTagRegex.search(trimmedLine.get_string())

		if lineTagMatch:
			return lineTagMatch.get_string()

	return ""


## Adds the given tag to the given line. If a tag already exists, it's replaced.
static func add_tag_to_line(line: String, tag: String) -> String:
	# regex used to trim the comments from lines
	var commentTrimRegex: RegEx = RegEx.new()

	commentTrimRegex.compile(commentTrimPattern)
	var strippedLine = strip_line_tag(line)

	# trim comments
	var trimmedLineMatch := commentTrimRegex.search(strippedLine)

	if !trimmedLineMatch || trimmedLineMatch.get_string().is_empty():
		return strippedLine

	var comments: String = strippedLine.replace(trimmedLineMatch.get_string(), "")

	var trimmedLine := trimmedLineMatch.get_string()

	return "%s %s %s" % [trimmedLineMatch.get_string(), "#" + tag, comments]


## Checks if the given line should be tagged. Returns false if the line starts with a command or consist only of a comment.
static func should_tag_line(line: String) -> bool:
	# regex used to trim the comments from lines
	var commentTrimRegex: RegEx = RegEx.new()

	# regex used to check if line starts with command - if it does then we ignore it
	var commandStartRegex: RegEx = RegEx.new()

	commentTrimRegex.compile(commentTrimPattern)
	commandStartRegex.compile(commandStartPatern)
	if (
		commandStartRegex.search(line.strip_edges())
		|| !commentTrimRegex.search(line) # comment stripping failed
		|| commentTrimRegex.search(line).get_string().is_empty() # the line consist only of a comment
	):
		return false
	return true


# removes the #line: tag from the line if it exists
static func strip_line_tag(line: String) -> String:
	var commentTrimRegex: RegEx = RegEx.new()
	var commandStartRegex: RegEx = RegEx.new()
	var lineTagRegex: RegEx = RegEx.new()
	commentTrimRegex.compile(commentTrimPattern)
	commandStartRegex.compile(commandStartPatern)
	lineTagRegex.compile(lineTagPattern)

	# if line starts with command, then do nothing
	if commandStartRegex.search(line):
		return line

	# trim comments
	var trimmedLineMatch := commentTrimRegex.search(line)

	if !trimmedLineMatch || trimmedLineMatch.get_string().is_empty():
		return line

	var trimmedLine := trimmedLineMatch.get_string()

	# find and replace line tag if found

	var lineTagMatch := lineTagRegex.search(trimmedLine)

	if lineTagMatch:
		return line.replace(lineTagMatch.get_string(), "")

	return line


######################### CSV Utilities #########################

# need to seperate headers from the content and create
# an array that will be a look-up table
# [id, topic1, topic2, topic3]

# then we need to split each line into its array of entries
# [lineId, entry1 , entry2, entry3]

# I should the be able to say, change the entry of topic1 for line with lineidX
# and we can use the topic index to quickly access it.


## Returns an array of headers and comma-separated value lines. The output has the following form:
## [Headers: PackedStringArray, csvLines: Array[PackedStringArray]]
static func get_csv_from_text(fileText: String, delim: String = ",") -> Array:
	var splits: PackedStringArray = fileText.split("\n") # split into lines
	var csvLines: Array[PackedStringArray] = []
	
	# get headers
	var headers := splits[0].split(delim) # first line contains headers
	for i in range(headers.size()):
		headers.set(i, headers[i].strip_edges())
	splits.remove_at(0)
	
	# get CSV data
	for line in splits:
		var csvLine: PackedStringArray = line.split(delim)
		csvLine.set(0, csvLine[0].strip_edges())
		csvLines.append(csvLine)
	
	return [headers, csvLines]


## Searches all the csvLines using the id of the 0th element.
static func get_row_of_id(csvLines: Array, id: String) -> int:
	for i in range(csvLines.size()):
		if csvLines[i][0].id == id:
			return i
	return -1


## Gets the column index of the given header (if it exists).
static func get_col_of_header(headers: PackedStringArray, head: String) -> int:
	return Array(headers).find(head)


## Generates a CSV text from the given CSV data.
static func get_text_from_csv(headers: PackedStringArray, csvLines: Array[PackedStringArray], delim: String = ",") -> String:
	csvLines.insert(0, headers)
	var lines: PackedStringArray = []

	for line in csvLines:
		lines.append(delim.join(line))

	return String("\n").join(lines)


## In the given csvLines, set the item in the given row and column to the given string.
## Returns false if the row/column is out of range.
static func set_data_at(data: String, csvLines: Array[PackedStringArray], row: int, col: int) -> bool:
	if csvLines.size() > row && csvLines[row].size() > col:
		csvLines[row].set(col, data)
		return true
	return false


## In the given csvLines, get the item in the given row and column.
## Returns an empty string if the row/column is out of range.
static func get_data_at(csvLines: Array[PackedStringArray], row: int, col: int) -> String:
	if csvLines.size() > row && csvLines[row].size() > col:
		return csvLines[row][col].strip_edges()
	return ""
