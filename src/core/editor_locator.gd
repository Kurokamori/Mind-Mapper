class_name EditorLocator
extends Object

const GROUP_ACTIVE_BOARD_EDITOR: String = "active_board_editor"


static func find_for(origin: Node) -> Node:
	if origin == null:
		return null
	var n: Node = origin.get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	var tree: SceneTree = origin.get_tree()
	if tree == null:
		return null
	var fallback: Node = tree.get_first_node_in_group(GROUP_ACTIVE_BOARD_EDITOR)
	if fallback != null and fallback.has_method("instantiate_item_from_dict"):
		return fallback
	return null
