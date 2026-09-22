extends Node2D


func _ready() -> void:
	_register_wasd()


# The arrow keys come from Godot's built-in ui_* actions; add WASD on top
# so the game feels right on a laptop.
func _register_wasd() -> void:
	var extra := {
		"ui_up": KEY_W,
		"ui_left": KEY_A,
		"ui_down": KEY_S,
		"ui_right": KEY_D,
	}
	for action in extra:
		var event := InputEventKey.new()
		event.physical_keycode = extra[action]
		InputMap.action_add_event(action, event)
