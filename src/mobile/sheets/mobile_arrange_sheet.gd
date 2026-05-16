class_name MobileArrangeSheet
extends Control

signal action_chosen(action: String)

const ACTION_GROUP: String = "group"
const ACTION_ALIGN_LEFT: String = "align_left"
const ACTION_ALIGN_HCENTER: String = "align_hcenter"
const ACTION_ALIGN_RIGHT: String = "align_right"
const ACTION_ALIGN_TOP: String = "align_top"
const ACTION_ALIGN_VCENTER: String = "align_vcenter"
const ACTION_ALIGN_BOTTOM: String = "align_bottom"
const ACTION_DISTRIBUTE_H: String = "distribute_h"
const ACTION_DISTRIBUTE_V: String = "distribute_v"
const ACTION_BRING_FORWARD: String = "bring_forward"
const ACTION_BRING_TO_FRONT: String = "bring_to_front"
const ACTION_SEND_BACKWARD: String = "send_backward"
const ACTION_SEND_TO_BACK: String = "send_to_back"

@onready var _selection_label: Label = %SelectionLabel
@onready var _group_button: Button = %GroupButton
@onready var _align_left_button: Button = %AlignLeftButton
@onready var _align_hcenter_button: Button = %AlignHCenterButton
@onready var _align_right_button: Button = %AlignRightButton
@onready var _align_top_button: Button = %AlignTopButton
@onready var _align_vcenter_button: Button = %AlignVCenterButton
@onready var _align_bottom_button: Button = %AlignBottomButton
@onready var _distribute_h_button: Button = %DistributeHButton
@onready var _distribute_v_button: Button = %DistributeVButton
@onready var _bring_forward_button: Button = %BringForwardButton
@onready var _bring_front_button: Button = %BringFrontButton
@onready var _send_backward_button: Button = %SendBackwardButton
@onready var _send_back_button: Button = %SendBackButton


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_group_button.pressed.connect(func() -> void: action_chosen.emit(ACTION_GROUP))
	_align_left_button.pressed.connect(func() -> void: action_chosen.emit(ACTION_ALIGN_LEFT))
	_align_hcenter_button.pressed.connect(func() -> void: action_chosen.emit(ACTION_ALIGN_HCENTER))
	_align_right_button.pressed.connect(func() -> void: action_chosen.emit(ACTION_ALIGN_RIGHT))
	_align_top_button.pressed.connect(func() -> void: action_chosen.emit(ACTION_ALIGN_TOP))
	_align_vcenter_button.pressed.connect(func() -> void: action_chosen.emit(ACTION_ALIGN_VCENTER))
	_align_bottom_button.pressed.connect(func() -> void: action_chosen.emit(ACTION_ALIGN_BOTTOM))
	_distribute_h_button.pressed.connect(func() -> void: action_chosen.emit(ACTION_DISTRIBUTE_H))
	_distribute_v_button.pressed.connect(func() -> void: action_chosen.emit(ACTION_DISTRIBUTE_V))
	_bring_forward_button.pressed.connect(func() -> void: action_chosen.emit(ACTION_BRING_FORWARD))
	_bring_front_button.pressed.connect(func() -> void: action_chosen.emit(ACTION_BRING_TO_FRONT))
	_send_backward_button.pressed.connect(func() -> void: action_chosen.emit(ACTION_SEND_BACKWARD))
	_send_back_button.pressed.connect(func() -> void: action_chosen.emit(ACTION_SEND_TO_BACK))


func update_selection_state(selection_count: int) -> void:
	_selection_label.text = "%d selected" % selection_count
	var has_two: bool = selection_count >= 2
	var has_three: bool = selection_count >= 3
	var has_one: bool = selection_count >= 1
	_group_button.disabled = not has_one
	_align_left_button.disabled = not has_two
	_align_hcenter_button.disabled = not has_two
	_align_right_button.disabled = not has_two
	_align_top_button.disabled = not has_two
	_align_vcenter_button.disabled = not has_two
	_align_bottom_button.disabled = not has_two
	_distribute_h_button.disabled = not has_three
	_distribute_v_button.disabled = not has_three
	_bring_forward_button.disabled = not has_one
	_bring_front_button.disabled = not has_one
	_send_backward_button.disabled = not has_one
	_send_back_button.disabled = not has_one
