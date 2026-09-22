extends Node2D

const PELLET_POINTS := 10
const POWER_POINTS := 50

@onready var maze: Node2D = $Board/Maze
@onready var player: Node2D = $Board/Player
@onready var score_label: Label = $HUD/Score

var score := 0


func _ready() -> void:
	_register_wasd()
	maze.reset_pellets()
	player.entered_cell.connect(_on_player_entered_cell)
	player.spawn_at(MazeData.find_all("P")[0])
	_update_hud()


func _on_player_entered_cell(cell: Vector2i) -> void:
	match maze.eat(cell):
		".":
			score += PELLET_POINTS
		"o":
			score += POWER_POINTS
		_:
			return
	_update_hud()


func _update_hud() -> void:
	score_label.text = "SCORE %d" % score


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
