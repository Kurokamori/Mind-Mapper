extends Node

const TYPE_TEXT: String = "text"
const TYPE_IMAGE: String = "image"
const TYPE_LABEL: String = "label"
const TYPE_RICH_TEXT: String = "rich_text"
const TYPE_PRIMITIVE: String = "primitive"
const TYPE_GROUP: String = "group"
const TYPE_SOUND: String = "sound"
const TYPE_TIMER: String = "timer"
const TYPE_PINBOARD: String = "pinboard"
const TYPE_SUBPAGE: String = "subpage"
const TYPE_MAP_PAGE: String = "map_page"
const TYPE_TODO_LIST: String = "todo_list"
const TYPE_BLOCK_STACK: String = "block_stack"
const TYPE_URL: String = "url"
const TYPE_CODE: String = "code"
const TYPE_TABLE: String = "table"
const TYPE_EQUATION: String = "equation"
const TYPE_STICKY: String = "sticky"

var _scenes: Dictionary = {}


func _ready() -> void:
	_scenes[TYPE_TEXT] = preload("res://src/nodes/text/text_node.tscn")
	_scenes[TYPE_IMAGE] = preload("res://src/nodes/image/image_node.tscn")
	_scenes[TYPE_LABEL] = preload("res://src/nodes/label/label_node.tscn")
	_scenes[TYPE_RICH_TEXT] = preload("res://src/nodes/rich_text/rich_text_node.tscn")
	_scenes[TYPE_PRIMITIVE] = preload("res://src/nodes/primitive/primitive_node.tscn")
	_scenes[TYPE_GROUP] = preload("res://src/nodes/group/group_node.tscn")
	_scenes[TYPE_SOUND] = preload("res://src/nodes/sound/sound_node.tscn")
	_scenes[TYPE_TIMER] = preload("res://src/nodes/timer/timer_node.tscn")
	_scenes[TYPE_PINBOARD] = preload("res://src/nodes/pinboard/pinboard_node.tscn")
	_scenes[TYPE_SUBPAGE] = preload("res://src/nodes/subpage/subpage_node.tscn")
	_scenes[TYPE_MAP_PAGE] = preload("res://src/nodes/map_page/map_page_node.tscn")
	_scenes[TYPE_TODO_LIST] = preload("res://src/nodes/todo_list/todo_list_node.tscn")
	_scenes[TYPE_BLOCK_STACK] = preload("res://src/nodes/block_stack/block_stack_node.tscn")
	_scenes[TYPE_URL] = preload("res://src/nodes/url/url_node.tscn")
	_scenes[TYPE_CODE] = preload("res://src/nodes/code/code_node.tscn")
	_scenes[TYPE_TABLE] = preload("res://src/nodes/table/table_node.tscn")
	_scenes[TYPE_EQUATION] = preload("res://src/nodes/equation/equation_node.tscn")
	_scenes[TYPE_STICKY] = preload("res://src/nodes/sticky/sticky_node.tscn")


func default_payload(type_id: String) -> Dictionary:
	match type_id:
		TYPE_TEXT: return {"text": "New text", "font_size": 18}
		TYPE_LABEL: return {"text": "Label", "font_size": 16}
		TYPE_RICH_TEXT: return {"bbcode_text": "[b]Rich[/b] text"}
		TYPE_PRIMITIVE: return {"shape": 0}
		TYPE_GROUP: return {"title": "Group"}
		TYPE_TIMER: return {"initial_duration_sec": 600.0, "label_text": "Timer", "mode": "duration", "target_unix": 0}
		TYPE_TODO_LIST: return {"title": "List", "cards": []}
		TYPE_BLOCK_STACK: return {"title": "Blocks", "blocks": []}
		TYPE_URL: return {"url": "https://example.com", "title": "Untitled link"}
		TYPE_CODE: return {"code": "// code", "language": "plaintext"}
		TYPE_TABLE: return {"rows": 3, "cols": 3, "cells": []}
		TYPE_EQUATION: return {"latex": "E = mc^2"}
		TYPE_STICKY: return {"text": "Sticky note", "color_index": 0}
	return {}


func has_type(type_id: String) -> bool:
	return _scenes.has(type_id)


func instantiate(type_id: String) -> BoardItem:
	if not _scenes.has(type_id):
		return null
	var scene: PackedScene = _scenes[type_id]
	var inst: BoardItem = scene.instantiate()
	inst.type_id = type_id
	return inst


func instantiate_from_dict(d: Dictionary) -> BoardItem:
	var type_id: String = String(d.get("type", ""))
	var inst: BoardItem = instantiate(type_id)
	if inst == null:
		return null
	inst.apply_dict(d)
	return inst


func types() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k in _scenes.keys():
		out.append(k)
	return out
