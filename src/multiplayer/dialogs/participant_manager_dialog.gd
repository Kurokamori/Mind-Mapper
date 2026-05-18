class_name ParticipantManagerDialog
extends AcceptDialog

@onready var _list: ItemList = %ParticipantList
@onready var _add_button: Button = %AddButton
@onready var _remove_button: Button = %RemoveButton
@onready var _transfer_button: Button = %TransferButton
@onready var _local_id_label: Label = %LocalIdLabel
@onready var _local_fingerprint_label: Label = %LocalFingerprintLabel
@onready var _import_dialog: AcceptDialog = %ImportPublicKeyDialog
@onready var _import_field: TextEdit = %ImportPublicKeyField
@onready var _import_name_field: LineEdit = %ImportNameField
@onready var _guest_policy_option: OptionButton = %GuestPolicyOption
@onready var _discovery_check: CheckBox = %DiscoveryCheckBox
@onready var _discovery_hint: Label = %DiscoveryHint
@onready var _room_code_row: HBoxContainer = %RoomCodeRow
@onready var _room_code_label: Label = %RoomCodeLabel
@onready var _room_code_copy_button: Button = %RoomCodeCopyButton


func _ready() -> void:
	ThemeManager.apply_relative_font_size(_discovery_hint, 0.80)
	title = "Participants"
	min_size = Vector2(620, 460)
	add_cancel_button("Close")
	get_ok_button().visible = false
	_add_button.pressed.connect(_on_add_pressed)
	_remove_button.pressed.connect(_on_remove_pressed)
	_transfer_button.pressed.connect(_on_transfer_pressed)
	_import_dialog.confirmed.connect(_on_import_confirmed)
	_guest_policy_option.add_item("View only", 0)
	_guest_policy_option.add_item("Comment", 1)
	_guest_policy_option.add_item("Edit", 2)
	_guest_policy_option.item_selected.connect(_on_guest_policy_changed)
	_discovery_check.toggled.connect(_on_discovery_toggled)
	_room_code_copy_button.pressed.connect(_on_room_code_copy_pressed)
	MultiplayerService.participants_changed.connect(_refresh)
	MultiplayerService.session_state_changed.connect(_on_session_state_changed)
	AppState.project_opened.connect(_on_project_opened_for_discovery)
	_refresh()


func _refresh() -> void:
	_list.clear()
	var participants: Array = MultiplayerService.participants_list()
	for entry_v: Variant in participants:
		var entry: Dictionary = entry_v
		var stable_id: String = String(entry.get("stable_id", ""))
		var display_name: String = String(entry.get("display_name", "Player"))
		var role: String = String(entry.get("role", ParticipantsManifest.ROLE_CO_AUTHOR))
		var connected: bool = bool(entry.get("connected", false))
		var status: String = "online" if connected else "offline"
		var label: String = "%s — %s — %s — %s" % [display_name, role, status, stable_id]
		_list.add_item(label)
		var idx: int = _list.item_count - 1
		_list.set_item_metadata(idx, entry)
		var color: Color = PeerIdentity.color_for_stable_id(stable_id)
		_list.set_item_custom_fg_color(idx, color.lightened(0.2))
	_local_id_label.text = MultiplayerService.local_stable_id()
	_local_fingerprint_label.text = KeypairService.public_key_fingerprint()
	var manifest: ParticipantsManifest = MultiplayerService.participants_manifest()
	if manifest != null:
		match manifest.guest_policy:
			ParticipantsManifest.GUEST_POLICY_VIEW:
				_guest_policy_option.select(0)
			ParticipantsManifest.GUEST_POLICY_COMMENT:
				_guest_policy_option.select(1)
			ParticipantsManifest.GUEST_POLICY_EDIT:
				_guest_policy_option.select(2)
	var is_owner: bool = manifest != null and manifest.is_owner(MultiplayerService.local_stable_id())
	_add_button.disabled = not is_owner
	_remove_button.disabled = not is_owner
	_transfer_button.disabled = not is_owner
	_guest_policy_option.disabled = not is_owner
	_refresh_discovery_state(is_owner)
	_refresh_room_code()


func _refresh_room_code() -> void:
	var code: String = MultiplayerService.current_webrtc_room_code()
	if code == "":
		_room_code_row.visible = false
		_room_code_label.text = ""
		return
	_room_code_row.visible = true
	_room_code_label.text = code
	_room_code_label.add_theme_color_override("font_color", PeerIdentity.color_for_stable_id(code).lightened(0.25))


func _on_room_code_copy_pressed() -> void:
	var code: String = MultiplayerService.current_webrtc_room_code()
	if code == "":
		return
	DisplayServer.clipboard_set(code)


func _on_session_state_changed(_state: int) -> void:
	_refresh_room_code()


func _on_add_pressed() -> void:
	_import_field.text = ""
	_import_name_field.text = ""
	PopupSizer.popup_fit(_import_dialog)


func _on_import_confirmed() -> void:
	var pem: String = _import_field.text.strip_edges()
	var display_name: String = _import_name_field.text.strip_edges()
	if pem == "":
		return
	if display_name == "":
		display_name = "Co-author"
	MultiplayerService.add_co_author_by_public_key(pem, display_name)


func _on_remove_pressed() -> void:
	var sel: PackedInt32Array = _list.get_selected_items()
	if sel.is_empty():
		return
	var entry: Variant = _list.get_item_metadata(sel[0])
	if typeof(entry) != TYPE_DICTIONARY:
		return
	var stable_id: String = String((entry as Dictionary).get("stable_id", ""))
	if stable_id == "" or stable_id == MultiplayerService.local_stable_id():
		return
	MultiplayerService.remove_co_author(stable_id)


func _on_transfer_pressed() -> void:
	var sel: PackedInt32Array = _list.get_selected_items()
	if sel.is_empty():
		return
	var entry: Variant = _list.get_item_metadata(sel[0])
	if typeof(entry) != TYPE_DICTIONARY:
		return
	var stable_id: String = String((entry as Dictionary).get("stable_id", ""))
	if stable_id == "" or stable_id == MultiplayerService.local_stable_id():
		return
	MultiplayerService.transfer_ownership(stable_id)


func _on_guest_policy_changed(idx: int) -> void:
	var policy: String = ParticipantsManifest.GUEST_POLICY_VIEW
	match idx:
		0:
			policy = ParticipantsManifest.GUEST_POLICY_VIEW
		1:
			policy = ParticipantsManifest.GUEST_POLICY_COMMENT
		2:
			policy = ParticipantsManifest.GUEST_POLICY_EDIT
	MultiplayerService.set_guest_policy(policy)


func _refresh_discovery_state(is_owner: bool) -> void:
	if AppState.current_project == null:
		_discovery_check.disabled = true
		_discovery_check.button_pressed = false
		return
	_discovery_check.disabled = not is_owner
	_discovery_check.button_pressed = AppState.current_project.discovery_enabled


func _on_discovery_toggled(enabled: bool) -> void:
	if AppState.current_project == null:
		return
	if AppState.current_project.discovery_enabled == enabled:
		return
	MultiplayerService.set_project_discovery_enabled(enabled)


func _on_project_opened_for_discovery(_project: Project) -> void:
	_refresh()
