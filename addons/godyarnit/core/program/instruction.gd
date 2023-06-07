## A simple container holding data of an instruction.
##
## Contains the bytecode encoding an operation, and an array of operands (see core/program/operand.gd).
## These instructions are used to execute compiled yarn nodes.
extends Object

const Operand = preload("res://addons/godyarnit/core/program/operand.gd")

var operation: int  # bytecode given through YarnGlobals.ByteCode denoting an operation
var operands: Array[Operand]  # contains operands given through operand.gd


func _init(other = null):
	if other != null && other.get_script() == self.get_script():
		self.operation = other.operation
		self.operands.append_array(other.operands)


func dump(program, library) -> String:
	return "InstructionInformation:NotImplemented"
