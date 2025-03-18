
# Table of Contents

1.  [Introduction](#Introduction)
2.  [Features](#Features)
3.  [Installation](#Installation)
	1.  [Install from GitHub](#org641f555)
	2.  [After Install](#org7865e93)
4.  [Quickstart](#Quickstart)
    1.  [Complete Beginner to YarnSpinner?](#orgb593371)
    2.  [How to create Yarn files?](#orge11a839)
    3.  [Your first dialogue](#org9fa26f1)
        1.  [Variable Storage](#orgf42125a)
        2.  [Compiled Yarn Program](#CompiledYarnProgram)
        3.  [Yarn Runner](#orgdbcf403)
        4.  [GUI Display](#orge8fe07e)
        5. [Function Library Storage](#orge8fe07f)



<a id="Introduction"></a>

# Introduction

**GodYarnIt** is a port of [Kyperbelt's GDYarn](https://github.com/kyperbelt/GDYarn) to **[Godot](https://godotengine.org/) 4**. It allows you to create interactive dialogues using a simple markup language with strong similarities to [twine](https://twinery.org/). It is easy enough to get, but powerful enough to take your games to the next level with branching narratives that can change based on user interactions.

GodYarnIt, like GDYarn, is a **reconstruction of [YarnSpinner](https://yarnspinner.dev)** completely written in [GDScript](https://docs.godotengine.org/en/stable/getting_started/scripting/gdscript/gdscript_basics.html). The project aims to be as feature complete as possible compared to the C# version but may forgo certain things in lieu of similar alternatives that make it blend better with the Godot ecosystem.

This port not only includes code fixes (GDScript saw many changes in Godot 4), but also major code documentation as well as some re-naming done to some classes, methods and variables.
When I began working on the port, I noticed that there are some bugs that needed me to dig deeper into the code (especially the one where the wait command doesn't work correctly, as also pointed out in [BreadcrumpIsTaken's fork](https://github.com/BreadcrumbIsTaken/GDYarn) - that one's fixed on here btw). This was a huge hassle, however, because the original code wasn't well-documented, didn't always stick to the [GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) and often didn't use any type-hints or insightful and consistent class/method/variable names.
Hence, I decided to go the long way and **gave the code a big face-lift and extensive documentation**. While I don't know for sure whether I will keep working on this repository long-term, the main goal of this fork (besides making it functional for Godot 4) is to **make the original code more intuitive to use** so that if Kyperbelt or anyone else wants to expand on it further, they don't need to spend weeks trying to understand every script to fix a bug or implement a new feature.

![Exmaple of Running a Dialogue](https://raw.githubusercontent.com/kyperbelt/GDYarn/main/images/yarn_running_dialogue.gif)

<a id="Features"></a>

# Features

-   [x] Compatibility with Godot 4 (incl. port bug fixes)
-   [X] Compile multiple Yarn files into a single Program
-   [X] Inline Expressions `{3 * $variable + foo()}`
-   [X] Format Functions `[func {$value} args...]` (select, plural, ordinal)
-   [X] Pluralisation
-   [ ] Persistent Variable Storage (currently can only be done manually)
-   [ ] Custom Commands (implemented already, but cumbersome to use)
-   [X] Function Library Extensions
-   [X] Option Links `[[OptionalText | TargetNode]]` (deprecated for Yarn 2.0, might get removed)
-   [X] Shortcut Options `->`
-   [ ] Localisation (WIP)
-   [X] if/elseif/else Statements `<<if ...>>`
-   [X] set command `<<set $var = 5>>`
-   [X] wait command `<<wait 4>>`
-   [X] support for BBCode `[b]bold[/b]` (**must use RichTextLabel**)
-   [ ] Header info processing
-   [ ] Yarn 2.0+ functionalities like jumps `<<jump TargetNode>>` or variable declarations `<<declare $value = true as bool>>`


<a id="Installation"></a>

# Installation


<a id="org641f555"></a>

## Install from GitHub

Go to the folder where you want to download this project to and clone it using your preferred method.
The files expect the following file path within your project: `res://addons/godyarnit/`. If you'd like to drop them somewhere else, press Ctrl+Shift+R when you're in the Godot editor. This will open up a replacement prompt. Enter `res://addons/godyarnit/` as your search term and the relative path to the new directory as the replacement term (you can get that path by right-clicking the directory in the editor and selecting `Copy Path`). Select the folder into which you've dropped the files as your search region in the prompt. When you hit `Replace`, all the file paths will be adjusted to your new location. You'll probably have to reload the editor, but afterwards you should be good!

For more information regarding this process checkout the official [Godot Documentation](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/installing_plugins.html) regarding plugin installation.


<a id="org7865e93"></a>

## After Installing

Make sure the plugin directory is located in `res://addons/` (case-sensitive!). If not, you will need to adjust dozens of file paths (`Ctrl+Shift+F`, search GodYarnIt's directory, replace all affected paths).

Enable the plugin by going to `Project > Project Settings > Plugins` and ticking GodYarnIt's checkbox.


<a id="Quickstart"></a>

# Quickstart


<a id="orgb593371"></a>

## Complete Beginner to YarnSpinner?

Checkout the official [Yarnspinner Tutorial](https://yarnspinner.dev/docs/writing/) page to get started writing interactive narratives!
Read the introduction pages up until you hit the Unity stuff (we don't need that since we are not working in Unity).
Also make sure to checkout the syntax Reference for a comprehensive list of the yarn languages capabilities.

> :warning: Some core functionalities (notably those of Yarn 2.0+) are still missing ([please report any issues](https://github.com/RonaldIaxaduv/GodYarnIt/issues)).


<a id="orge11a839"></a>

## How to create Yarn files?

Yarn files are simple text files that are written in using the [Yarn Language Syntax](https://yarnspinner.dev/docs/syntax/) and can be created in the following ways:

-   [Web Yarn Editor](https://yarnspinnertool.github.io/YarnEditor/) for more information go ([here](https://yarnspinner.dev/docs/writing/yarn-editor/)).
-   [VS Code](https://code.visualstudio.com/) with the [YarnSpinner Extension](https://marketplace.visualstudio.com/items?itemName=SecretLab.yarn-spinner)
-   Any Text Editor (They are just plain text files!)


<a id="org9fa26f1"></a>

## Your first dialogue

In order to start using Yarn Dialogues in your games you require the following things:


<a id="orgf42125a"></a>

### Variable Storage

The **Variable Storage** node is one of the many ways that your dialogues can interact with your game. It is in charge of storing the values that your dialogues use at runtime and can be also accessed through certain script function calls like `set_value(name,value)` and `get_value(name)`.

At least one Variable Storage node must be added to your scene hierarchy in order to run yarn programs using the Yarn Runner. It can be found in the [Create Node Popup in the Godot Editor](https://docs.godotengine.org/en/stable/getting_started/step_by_step/nodes_and_scenes.html#creating-your-first-scene).

1.  Signals:

    -   `value_set(valName)`: emitted when a value is set. Passes in the name of the value.


<a id="CompiledYarnProgram"></a>

### Compiled Yarn Program

This is a [Resource](https://docs.godotengine.org/en/stable/getting_started/step_by_step/resources.html) that contains a collection of yarn script files. On its own its really not that crucial but when combined with the Yarn Runner, it allows you to combine multiple yarn scripts into a single program.

This Resource is available in the Resource drop down and can be created when adding a new resource to the Yarn Runner.

1.  Properties:

    -   **Compiled Program Name** : This is the name of the Yarn Program once it is compiled.
    -   **Compiled Program Directory**: This is the directory to which you want to save the Compiled Yarn Program.
    -   **Yarn Program Paths**: This is an array of paths to `.yarn` files to be combined and compiled into a single Yarn Program. Note that they must not have any conflicting node names as this will generate an error at compile time.


<a id="orgdbcf403"></a>

### Yarn Runner

The bread and butter of this whole thing. It communicates with the scripts running the Yarn Program and turns their states and outputs into useful signals and methods for UI elements. Although it would not be impossible to run Yarn Programs (compiled Yarn Dialogues) without this node, it would certainly be difficult.
WAIT! Before we hit the big shiny **Compile Button**, let's first get to know some things about the Yarn Runner.

1.  Properties:

    -   **Start Node Title**: This is the title of the Yarn Node that runs when you start the runner. This refers to the nodes in the YarnSpinner narrative script, it does **not** have anything to do with nodes inside Godot.
    -   **Should Auto Start**: If this is enabled, the Yarn Runner will automatically start the dialogue as soon as it enters the tree. This is fine for testing or for other specific test cases, but for the most part you will want to start the runner externally through its `start` function.
    -   **Variable Storage**: The Variable Storage node that you will be using for this runner.
    -   **Compiled Yarn Program**: as Explained above, this is the resource that contains information about the program.
    
    Right now the only way to compile and run Yarn scripts is through the Yarn Runner node.
    Before you can touch the compile button you must first add a [Compiled Yarn Program Resource](#CompiledYarnProgram) to the **Yarn Runner** through the [Inspector](https://docs.godotengine.org/en/stable/tutorials/editor/inspector_dock.html).
    
    Once it's added you can expand it, edit its various properties and add all the scripts that you want to compile. Then hit compile, and if all went well, there will be no errors displayed. Instead you will get compilation success messages! Woooo!
    
    Set your start node title, and add a variable storage and you are ready to move on to the next step.

2.  Signals:

    -   `dialogue_started`: Emitted when the dialogue has been started.
    -   `next_line_prepared(prepared_line: String)`: Emitted when the runner has prepared a new line to display. `prepared_line` contains that line.
    -   `command_triggered(command: String, arguments: Array[String])`: Emitted when a command is being handled by the runner. The `command` and an array of its `arguments` are passed.
    -   `options_prepared(prepared_options: Array[String])`: Emitted when options (either Shortcut Options or Dialogue Link Options) are handled by the runner. `prepared_options` contains the displayed text of each option.
    -   `dialogue_finished`: Emitted when the dialogue has finished.
    -   `resumed`: Emitted when `resume` is called on the **YarnRunner**
    -   `node_started(node_name: String)`: Emitted when a new node has started running. `node_name` is the title of that node.
    -   `node_complete(node_name: String)`: Emitted when a node has finished running. `node_name` is the title of that node.


<a id="orge8fe07e"></a>

### Yarn Display

If the **Yarn Runner** was the bread and butter, then a **GUI** is the plate you serve it on. To create a GUI for displaying Yarn Dialogues, you need a reference to a Yarn Runner node and mainly listen to the signals it outputs to receive the text that should be displayed.

GodYarnIt, like GDYarn, comes with a default GUI implementation which will be explained here. But just know that you are not forced to use the provided implementation and are more than encouraged to create your own if your use-case requires it.

1.  Properties:

    -   **Yarn Runner Path**: The runner that this GUI will be listening to.
    -   **Text Display Path**: The text node that this GUI will feed lines to. **Note** that the only requirement of the node is that it has a `set_text(text)` function, but it is highly recommended that you use the built in Godot controls for displaying text like [Label](https://docs.godotengine.org/en/stable/classes/class_label.html) and [RichTextLabel](https://docs.godotengine.org/en/stable/classes/class_richtextlabel.html).
    -   **Name Plate Display Path**: This is another text label node, that when present, will look for lines with the pattern `"<name>: <line content>"` and split them at the `:`. The name will be fed to the nameplate and the line content to the Text.
    -   **Option Display Paths**: An array of label nodes that will be used for displaying options (Shortcut Options or Dialogue Link Options). You can add as many as you will need (usually you should put as many as the most options that will be displayed to the user at any single time). Options nodes will be made invisible when not in use. If you use a button control, it will be automatically connected to a handler method.
    -   **Text Speed**: This is the speed at which text is displayed in characters per second. If `<= 0`, then lines will be displayed instantly.
    
    The only requirements for the GUI display is that you call its `finish_line()` function when you want to call the next line (or close it when there is no lines left). This can be done through a script, or you can hook up a button pressed signal to it.
    
    As you can see, this GUI implementation makes no requirement for visual style - that part is entirely up to you!
    
    The node structure of your Yarn Display will probably look like this:
- YarnGUI
	- TextDisplay
	- NameDisplay
	- OptionsDisplays (plain control node)
		- OptionDisplay0
		- OptionDisplay1
		- ...
	- YarnRunner
		- VariableStorage

2.  Signals:

    -   `text_changed`: Emitted every time the text for the text display changes.
    -   `line_started`: Emitted every time that a new line is received.
    -   `line_finished`: Emitted every time a line finishes displaying.
    -   `options_shown`: Emitted when a set of options is displayed.
    -   `option_selected`: Emitted when an option selection has been made.
    -   `gui_shown`: Emitted when `show_gui()` is called.
    -   `gui_hidden`: Emitted when `hide_gui()` is called.


<a id="orge8fe07f"></a>

### Function Library Storage

The **Function Library Storage** node is allows you to add functions with custom names that can be called from within your Yarn script files.

It contains an array of GDScript resources. These need to be subclasses of the library class (`//core/libraries/library.gd`). Feel free to use the Standard library (`//core/libraries/standard.gd`) or the code section below as a reference.

In order for the functions to be loaded, the Yarn Runner needs to hold a reference to a Function Library Storage - as for the Variable Storage, there is an export variable for this. The Yarn Runner will automatically import all libraries contained in the referenced Function Library Storage node.

The following kinds of functions are supported:
- functions without arguments: `{Foo1()}`
- functions with a set number of arguments `{Foo2($arg1, 2)}`
- functions with a variable number of arguments: `{Foo3()}`, `{Foo3($arg1, $arg2)}`
- functions without a return value: `{Foo4()}` (these will turn into empty strings)

In the code, they would look like this:
```GDScript
extends "res://addons/godyarnit/core/libraries/library.gd"

const Value = preload("res://addons/godyarnit/core/value.gd")

func _init():
	register_function("Foo1", 0, Callable(self, "get_random_float"), true)
	register_function("Foo2", 2, Callable(self, "get_random_int_in_range"), true)
	register_function("Foo3", 2, Callable(self, "get_random_int_optional_args"), true)
	register_function("Foo4", 0, Callable(self, "print_random_int"), false)


## Returns a random number between 0.0 and 1.0 (inclusive)
func get_random_float() -> float:
	return randf()

## Returns a random number between min and max (inclusive)
func get_random_int(min: Value, max: Value) -> int:
	return randi_range(min.as_number(), max.as_number())

## Returns a random int between min and max, uses defaults if no args given
func get_random_int_optional_args(min = 0, max = 10) -> int:
	var min_to_use: int = min.as_number() if min is Value else min
	var max_to_use: int = max.as_number() if max is Value else max
	return randi_range(min_to_use, max_to_use)

## Prints a random int without returning anything
func print_random_int() -> void:
	print("Here's a random int: %d" % [randi()])
```