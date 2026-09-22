extends Node2D

const PARCEL_POINTS := 10
const COFFEE_POINTS := 50
const START_LIVES := 3
const CRASH_DISTANCE := 18.0
const PULLOVER_TIME := 7.0
const BUMP_POINTS := [200, 400, 800, 1600]

const CAR_SCRIPT := preload("res://scripts/car.gd")
const CAR_COLORS := [Color("f2c200"), Color("e8e8ec"), Color("3b6ee0"), Color("e07b2a")]
const CAR_CORNERS := [Vector2i(17, 1), Vector2i(1, 1), Vector2i(17, 19), Vector2i(1, 19)]
const CAR_DELAYS := [0.0, 2.0, 5.0, 8.0]

@onready var board: Node2D = $Board
@onready var city: Node2D = $Board/City
@onready var courier: Node2D = $Board/Courier
@onready var score_label: Label = $HUD/Score
@onready var lives_label: Label = $HUD/Lives
@onready var message_label: Label = $HUD/Message

var score := 0
var lives := START_LIVES
var cars: Array[Node2D] = []
var running := false
var finished := false
var combo := 0


func _ready() -> void:
	_register_wasd()
	city.reset_parcels()
	city.all_collected.connect(_on_all_delivered)
	courier.entered_cell.connect(_on_courier_entered_cell)
	_spawn_cars()
	_reset_positions()
	_update_hud()
	await _start_shift()


func _spawn_cars() -> void:
	var spawns := CityData.find_all("G")
	for i in spawns.size():
		var car := Node2D.new()
		car.set_script(CAR_SCRIPT)
		car.personality = i
		car.body_color = CAR_COLORS[i % CAR_COLORS.size()]
		car.patrol_corner = CAR_CORNERS[i % CAR_CORNERS.size()]
		car.release_delay = CAR_DELAYS[i % CAR_DELAYS.size()]
		car.start_cell = spawns[i]
		car.courier = courier
		board.add_child(car)
		cars.append(car)


func _reset_positions() -> void:
	courier.spawn_at(CityData.find_all("P")[0])
	for car in cars:
		car.spawn()


func _process(_delta: float) -> void:
	if not running:
		return
	for car in cars:
		if not car.is_on_the_road():
			continue
		if courier.position.distance_to(car.position) >= CRASH_DISTANCE:
			continue
		if car.is_pulled_over():
			_bump_car(car)
		else:
			_crash()
			return


func _on_courier_entered_cell(cell: Vector2i) -> void:
	match city.collect(cell):
		".":
			score += PARCEL_POINTS
		"o":
			score += COFFEE_POINTS
			combo = 0
			for car in cars:
				car.pull_over(PULLOVER_TIME)
		_:
			return
	_update_hud()


func _bump_car(car: Node2D) -> void:
	car.tow()
	score += BUMP_POINTS[mini(combo, BUMP_POINTS.size() - 1)]
	combo += 1
	_update_hud()


func _crash() -> void:
	lives -= 1
	running = false
	_set_entities_active(false)
	_update_hud()

	if lives <= 0:
		_finish("SHIFT OVER")
		return

	message_label.text = "CRASHED!"
	await get_tree().create_timer(1.2).timeout
	_reset_positions()
	await _start_shift()


func _on_all_delivered() -> void:
	running = false
	_set_entities_active(false)
	_finish("ALL DELIVERED!")


func _start_shift() -> void:
	running = false
	_set_entities_active(false)
	message_label.text = "GO!"
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
	courier.set_process(active)
	for car in cars:
		car.set_process(active)


func _update_hud() -> void:
	score_label.text = "CASH $%d" % score
	lives_label.text = "SCOOTERS %d" % lives


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
