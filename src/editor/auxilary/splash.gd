class_name Splash
extends Control

signal finished

const HOLD_SECONDS: float = 1.5

@onready var _splash: TextureRect = %Splash
@onready var _animation: AnimationPlayer = %Animation


func _ready() -> void:
	_animation.animation_finished.connect(_on_animation_finished)
	_animation.play("intro")


func _on_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		&"intro":
			var timer: SceneTreeTimer = get_tree().create_timer(HOLD_SECONDS)
			timer.timeout.connect(_on_hold_timeout)
		&"outro":
			finished.emit()


func _on_hold_timeout() -> void:
	_animation.play("outro")
