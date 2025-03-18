@icon("res://addons/godyarnit/assets/function_library_storage.png")
class_name FunctionLibraryStorage
extends Node


const FunctionLibrary = preload("res://addons/godyarnit/core/libraries/library.gd")


@export var libraries_to_use: Array[GDScript] = []
