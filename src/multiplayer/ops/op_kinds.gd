class_name OpKinds
extends RefCounted

const SCOPE_BOARD: String = "board"
const SCOPE_PROJECT: String = "project"
const SCOPE_MANIFEST: String = "manifest"

const CREATE_ITEM: String = "create_item"
const DELETE_ITEM: String = "delete_item"
const MOVE_ITEMS: String = "move_items"
const SET_ITEM_PROPERTY: String = "set_item_property"
const REORDER_ITEMS: String = "reorder_items"
const REPARENT_ITEMS: String = "reparent_items"
const SET_BLOCK_STACK_ROW: String = "set_block_stack_row"
const SET_TODO_CARD: String = "set_todo_card"
const MOVE_TODO_CARD: String = "move_todo_card"

const CREATE_CONNECTION: String = "create_connection"
const DELETE_CONNECTION: String = "delete_connection"
const SET_CONNECTION_PROPERTY: String = "set_connection_property"

const CREATE_BOARD: String = "create_board"
const RENAME_BOARD: String = "rename_board"
const REPARENT_BOARD: String = "reparent_board"
const DELETE_BOARD: String = "delete_board"
const SET_BOARD_PROPERTY: String = "set_board_property"

const REPLACE_ASSET: String = "replace_asset"

const CREATE_COMMENT: String = "create_comment"
const DELETE_COMMENT: String = "delete_comment"
const SET_COMMENT_PROPERTY: String = "set_comment_property"

const ADD_PARTICIPANT: String = "add_participant"
const REMOVE_PARTICIPANT: String = "remove_participant"
const TRANSFER_OWNERSHIP: String = "transfer_ownership"
const SET_PROJECT_PROPERTY: String = "set_project_property"
const SET_GUEST_POLICY: String = "set_guest_policy"


static func scope_for_kind(kind: String) -> String:
	match kind:
		CREATE_ITEM, DELETE_ITEM, MOVE_ITEMS, SET_ITEM_PROPERTY, REORDER_ITEMS, REPARENT_ITEMS, \
		SET_BLOCK_STACK_ROW, SET_TODO_CARD, MOVE_TODO_CARD, \
		CREATE_CONNECTION, DELETE_CONNECTION, SET_CONNECTION_PROPERTY, \
		CREATE_COMMENT, DELETE_COMMENT, SET_COMMENT_PROPERTY, \
		REPLACE_ASSET, SET_BOARD_PROPERTY:
			return SCOPE_BOARD
		CREATE_BOARD, RENAME_BOARD, REPARENT_BOARD, DELETE_BOARD:
			return SCOPE_PROJECT
		ADD_PARTICIPANT, REMOVE_PARTICIPANT, TRANSFER_OWNERSHIP, SET_PROJECT_PROPERTY, SET_GUEST_POLICY:
			return SCOPE_MANIFEST
		_:
			return SCOPE_BOARD


static func is_owner_only(kind: String) -> bool:
	match kind:
		ADD_PARTICIPANT, REMOVE_PARTICIPANT, TRANSFER_OWNERSHIP, SET_PROJECT_PROPERTY, SET_GUEST_POLICY:
			return true
		_:
			return false


static func is_structural(kind: String) -> bool:
	match kind:
		CREATE_ITEM, DELETE_ITEM, CREATE_CONNECTION, DELETE_CONNECTION, \
		CREATE_BOARD, DELETE_BOARD, REPARENT_BOARD:
			return true
		_:
			return false


static func is_comment_kind(kind: String) -> bool:
	match kind:
		CREATE_COMMENT, DELETE_COMMENT, SET_COMMENT_PROPERTY:
			return true
		_:
			return false
