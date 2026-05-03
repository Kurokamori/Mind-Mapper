extends Node

signal selection_changed(selected_items: Array)

var _items: Array[BoardItem] = []


func current() -> Array[BoardItem]:
	return _items.duplicate()


func is_selected(item: BoardItem) -> bool:
	return _items.has(item)


func clear() -> void:
	if _items.is_empty():
		return
	for it in _items:
		if is_instance_valid(it):
			it.set_selected(false)
	_items.clear()
	emit_signal("selection_changed", current())


func set_single(item: BoardItem) -> void:
	for it in _items:
		if it != item and is_instance_valid(it):
			it.set_selected(false)
	_items.clear()
	if item != null:
		_items.append(item)
		item.set_selected(true)
	emit_signal("selection_changed", current())


func add(item: BoardItem) -> void:
	if item == null or _items.has(item):
		return
	_items.append(item)
	item.set_selected(true)
	emit_signal("selection_changed", current())


func remove(item: BoardItem) -> void:
	if not _items.has(item):
		return
	_items.erase(item)
	if is_instance_valid(item):
		item.set_selected(false)
	emit_signal("selection_changed", current())


func toggle(item: BoardItem) -> void:
	if _items.has(item):
		remove(item)
	else:
		add(item)


func set_many(items: Array) -> void:
	for it in _items:
		if is_instance_valid(it) and not items.has(it):
			it.set_selected(false)
	_items.clear()
	for it in items:
		if it is BoardItem:
			_items.append(it)
			it.set_selected(true)
	emit_signal("selection_changed", current())
