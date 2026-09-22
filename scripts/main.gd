extends Node2D

const PELLET_POINTS := 10
const POWER_POINTS := 50
const START_LIVES := 3
const CATCH_DISTANCE := 18.0
const FRIGHT_TIME := 7.0
const GHOST_POINTS := [200, 400, 800, 1600]

const GHOST_SCRIPT := preload("res://scripts/ghost.gd")
const GHOST_COLORS := [Color("ff0000"), Color("ffb8ff"), Color("00ffff"), Color("ffb852")]
const GHOST_CORNERS := [Vector2i(17, 1), Vector2i(1, 1), Vector2i(17, 19), Vector2i(1, 19)]
const GHOST_DELAYS := [0.0, 2.0, 5.0, 8.0]

@onready var board: Node2D = $Board
@onready var maze: Node2D = $Board/Maze
@onready var player: Node2D = $Board/Player
@onready var score_label: Label = $HUD/Score
@onready var lives_label: Label = $HUD/Lives
@onready var message_label: Label = $HUD/Message

var score := 0
var lives := START_LIVES
var ghosts: Array[Node2D] = []
var running := false
var finished := false
var combo := 0


func _ready() -> void:
	_register_wasd()
	maze.reset_pellets()
	maze.pellets_cleared.connect(_on_maze_cleared)
	player.entered_cell.connect(_on_player_entered_cell)
	_spawn_ghosts()
	_reset_positions()
	_update_hud()
	await _get_ready()


func _spawn_ghosts() -> void:
	var spawns := MazeData.find_all("G")
	for i in spawns.size():
		var ghost := Node2D.new()
		ghost.set_script(GHOST_SCRIPT)
		ghost.personality = i
		ghost.body_color = GHOST_COLORS[i % GHOST_COLORS.size()]
		ghost.home_corner = GHOST_CORNERS[i % GHOST_CORNERS.size()]
		ghost.release_delay = GHOST_DELAYS[i % GHOST_DELAYS.size()]
		ghost.start_cell = spawns[i]
		ghost.player = player
		board.add_child(ghost)
		ghosts.append(ghost)


func _reset_positions() -> void:
	player.spawn_at(MazeData.find_all("P")[0])
	for ghost in ghosts:
		ghost.spawn()


func _process(_delta: float) -> void:
	if not running:
		return
	for ghost in ghosts:
		if not ghost.is_catchable():
			continue
		if player.position.distance_to(ghost.position) >= CATCH_DISTANCE:
			continue
		if ghost.is_frightened():
			_eat_ghost(ghost)
		else:
			_lose_life()
			return


func _on_player_entered_cell(cell: Vector2i) -> void:
	match maze.eat(cell):
		".":
			score += PELLET_POINTS
		"o":
			score += POWER_POINTS
			combo = 0
			for ghost in ghosts:
				ghost.frighten(FRIGHT_TIME)
		_:
			return
	_update_hud()


func _eat_ghost(ghost: Node2D) -> void:
	ghost.get_eaten()
	score += GHOST_POINTS[mini(combo, GHOST_POINTS.size() - 1)]
	combo += 1
	_update_hud()


func _lose_life() -> void:
	lives -= 1
	running = false
	_set_entities_active(false)
	_update_hud()

	if lives <= 0:
		_finish("GAME OVER")
		return

	message_label.text = "CAUGHT!"
	await get_tree().create_timer(1.2).timeout
	_reset_positions()
	await _get_ready()


func _on_maze_cleared() -> void:
	running = false
	_set_entities_active(false)
	_finish("YOU WIN!")


func _get_ready() -> void:
	running = false
	_set_entities_active(false)
	message_label.text = "READY!"
	await get_tree().create_timer(1.5).timeout
	message_label.text = ""
	_set_entities_active(true)
	running = true


func _finish(text: String) -> void:
	finished = true
	message_label.text = text + "\nPRESS SPACE"


func _unhandled_input(event: InputEvent) -> void:
	if finished and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()


func _set_entities_active(active: bool) -> void:
	player.set_process(active)
	for ghost in ghosts:
		ghost.set_process(active)


func _update_hud() -> void:
	score_label.text = "SCORE %d" % score
	lives_label.text = "LIVES %d" % lives


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
