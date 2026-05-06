class_name HistoryCommand
extends RefCounted


func do() -> void:
	pass


func undo() -> void:
	pass


func record_op_forward() -> void:
	pass


func description() -> String:
	return "Command"
