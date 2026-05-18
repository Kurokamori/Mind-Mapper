class_name LanSyncOfferDialog
extends Window

signal decision_made(decision: String, per_file_kept_mine: Dictionary)
signal dialog_dismissed()

const RESOLUTION_KEEP_THEIRS: String = "theirs"
const RESOLUTION_KEEP_MINE: String = "mine"
const REVIEW_ROW_SCENE: PackedScene = preload("res://src/mobile/sync/lan_sync_offer_review_row.tscn")

@onready var _summary_label: Label = %SummaryLabel
@onready var _files_summary_label: Label = %FilesSummaryLabel
@onready var _actions_row: HBoxContainer = %ActionsRow
@onready var _reject_button: Button = %RejectButton
@onready var _reject_block_button: Button = %RejectBlockButton
@onready var _accept_all_button: Button = %AcceptAllButton
@onready var _accept_review_button: Button = %AcceptReviewButton
@onready var _review_panel: VBoxContainer = %ReviewPanel
@onready var _review_summary_label: Label = %ReviewSummaryLabel
@onready var _review_list: VBoxContainer = %ReviewList
@onready var _review_keep_all_mine: Button = %ReviewKeepAllMineButton
@onready var _review_keep_all_theirs: Button = %ReviewKeepAllTheirsButton
@onready var _review_apply_button: Button = %ReviewApplyButton
@onready var _review_cancel_button: Button = %ReviewCancelButton

var _op_kind: String = ""
var _client_name: String = ""
var _conflicting_paths: Array = []
var _incoming_only_paths: Array = []
var _per_file_decision: Dictionary = {}
var _review_rows: Array = []
var _decision_finalized: bool = false


func _ready() -> void:
	close_requested.connect(_on_close_requested)
	_reject_button.pressed.connect(_on_reject_pressed)
	_reject_block_button.pressed.connect(_on_reject_block_pressed)
	_accept_all_button.pressed.connect(_on_accept_all_pressed)
	_accept_review_button.pressed.connect(_on_accept_review_pressed)
	_review_keep_all_mine.pressed.connect(_on_review_keep_all_mine)
	_review_keep_all_theirs.pressed.connect(_on_review_keep_all_theirs)
	_review_apply_button.pressed.connect(_on_review_apply_pressed)
	_review_cancel_button.pressed.connect(_on_review_cancel_pressed)
	_review_panel.visible = false


func configure(op_kind: String, client_name: String, conflicting_paths: Array, incoming_only_paths: Array, project_name: String) -> void:
	_op_kind = op_kind
	_client_name = client_name if client_name.strip_edges() != "" else "Mobile"
	_conflicting_paths = conflicting_paths.duplicate(true)
	_incoming_only_paths = incoming_only_paths.duplicate(true)
	var action_verb: String = "sync" if op_kind == LanSyncProtocol.OFFER_OP_SYNC else "push"
	title = "%s requested" % action_verb.capitalize()
	var project_label: String = project_name if project_name.strip_edges() != "" else "this project"
	_summary_label.text = "%s wants to %s changes to '%s'." % [_client_name, action_verb, project_label]
	var conflict_count: int = _conflicting_paths.size()
	var new_count: int = _incoming_only_paths.size()
	_files_summary_label.text = "%d conflict(s) · %d new file(s)" % [conflict_count, new_count]
	_reject_block_button.visible = op_kind == LanSyncProtocol.OFFER_OP_SYNC
	_review_panel.visible = false
	_actions_row.visible = true


func _on_reject_pressed() -> void:
	_finalize(LanSyncProtocol.DECISION_REJECT, {})


func _on_reject_block_pressed() -> void:
	_finalize(LanSyncProtocol.DECISION_REJECT_AND_BLOCK, {})


func _on_accept_all_pressed() -> void:
	_finalize(LanSyncProtocol.DECISION_ACCEPT_ALL, {})


func _on_accept_review_pressed() -> void:
	if _conflicting_paths.is_empty():
		_finalize(LanSyncProtocol.DECISION_ACCEPT_ALL, {})
		return
	_per_file_decision.clear()
	for path: String in _conflicting_paths:
		_per_file_decision[path] = RESOLUTION_KEEP_THEIRS
	_actions_row.visible = false
	_review_panel.visible = true
	_review_summary_label.text = "Choose which side to keep for each conflicting file (default: keep mine)."
	_build_review_rows()
	for path: String in _per_file_decision.keys():
		_per_file_decision[path] = RESOLUTION_KEEP_MINE
	_refresh_review_rows()


func _build_review_rows() -> void:
	for row: Node in _review_rows:
		if row != null and is_instance_valid(row):
			row.queue_free()
	_review_rows.clear()
	for path: String in _conflicting_paths:
		var row: LanSyncOfferReviewRow = REVIEW_ROW_SCENE.instantiate()
		_review_list.add_child(row)
		row.bind(path)
		row.choice_changed.connect(_on_review_row_choice_changed)
		_review_rows.append(row)


func _refresh_review_rows() -> void:
	for row_v: Variant in _review_rows:
		var row: LanSyncOfferReviewRow = row_v
		if row == null:
			continue
		var choice: String = String(_per_file_decision.get(row.relative_path(), RESOLUTION_KEEP_MINE))
		row.set_choice(choice)


func _on_review_row_choice_changed(relative_path: String, choice: String) -> void:
	_per_file_decision[relative_path] = choice


func _on_review_keep_all_mine() -> void:
	for path: String in _per_file_decision.keys():
		_per_file_decision[path] = RESOLUTION_KEEP_MINE
	_refresh_review_rows()


func _on_review_keep_all_theirs() -> void:
	for path: String in _per_file_decision.keys():
		_per_file_decision[path] = RESOLUTION_KEEP_THEIRS
	_refresh_review_rows()


func _on_review_apply_pressed() -> void:
	var kept_mine_map: Dictionary = {}
	for path_v: Variant in _per_file_decision.keys():
		var path: String = String(path_v)
		kept_mine_map[path] = String(_per_file_decision[path]) == RESOLUTION_KEEP_MINE
	_finalize(LanSyncProtocol.DECISION_ACCEPT_REVIEW, kept_mine_map)


func _on_review_cancel_pressed() -> void:
	_review_panel.visible = false
	_actions_row.visible = true


func configure_review_only(host_name: String, project_name: String, conflicting_paths: Array, op_kind: String) -> void:
	_op_kind = op_kind
	_client_name = host_name if host_name.strip_edges() != "" else "Host"
	_conflicting_paths = conflicting_paths.duplicate(true)
	_incoming_only_paths = []
	var action_verb: String = "sync" if op_kind == LanSyncProtocol.OFFER_OP_SYNC else "push"
	title = "Resolve conflicts before %s" % action_verb
	var project_label: String = project_name if project_name.strip_edges() != "" else "this project"
	_summary_label.text = "%s asked you to resolve the merge for '%s' here on the desktop." % [_client_name, project_label]
	_files_summary_label.text = "%d conflict(s) need a choice" % conflicting_paths.size()
	_actions_row.visible = false
	_review_panel.visible = true
	_review_summary_label.text = "Pick which side to keep for each file. The host will skip your file when 'Keep mine' is chosen."
	_per_file_decision.clear()
	for path: String in _conflicting_paths:
		_per_file_decision[path] = RESOLUTION_KEEP_MINE
	_build_review_rows()
	_refresh_review_rows()


func _on_close_requested() -> void:
	if _decision_finalized:
		return
	_finalize(LanSyncProtocol.DECISION_REJECT, {})


func _finalize(decision: String, per_file_kept_mine: Dictionary) -> void:
	if _decision_finalized:
		return
	_decision_finalized = true
	emit_signal("decision_made", decision, per_file_kept_mine)
	emit_signal("dialog_dismissed")
	hide()
	queue_free()
