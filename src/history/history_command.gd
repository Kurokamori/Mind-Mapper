class_name HistoryCommand
extends RefCounted


func do() -> void:
	pass


func undo() -> void:
	pass


func record_op_forward() -> void:
	pass


func rollback_local() -> void:
	pass


func primary_op_kind() -> String:
	return ""


func description() -> String:
	return "Command"
