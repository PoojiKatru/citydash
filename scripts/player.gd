extends Node2D

signal entered_cell(cell: Vector2i)

const SPEED := 150.0
const BODY := Color("e63946")
const RIDER := Color("caff2f")
const HELMET := Color("f4f4f4")
const HEADLIGHT := Color("fff6c0")
const CARGO := Color("f0602a")
const CARGO_EDGE := Color("7a2f12")

var cell: Vector2i       # the tile we are standing on / just left
var to_cell: Vector2i    # the tile we are sliding into (== cell when stopped)
var dir := Vector2i.ZERO
var next_dir := Vector2i.ZERO

var _facing := 0.0
var _wobble := 0.0


func spawn_at(start: Vector2i) -> void:
	cell = start
	to_cell = start
	dir = Vector2i.ZERO
	next_dir = Vector2i.ZERO
	_facing = 0.0
	position = MazeData.cell_to_world(start)
	queue_redraw()


func _process(delta: float) -> void:
	_read_input()
	_move(SPEED * delta)
	if dir != Vector2i.ZERO:
		_facing = Vector2(dir).angle()
		_wobble = fmod(_wobble + delta * 14.0, TAU)
	queue_redraw()


func _read_input() -> void:
	var wanted := Vector2i.ZERO
	if Input.is_action_pressed("ui_up"):
		wanted = Vector2i.UP
	elif Input.is_action_pressed("ui_down"):
		wanted = Vector2i.DOWN
	elif Input.is_action_pressed("ui_left"):
		wanted = Vector2i.LEFT
	elif Input.is_action_pressed("ui_right"):
		wanted = Vector2i.RIGHT

	if wanted == Vector2i.ZERO:
		return

	if dir != Vector2i.ZERO and wanted == -dir:
		# Doubling back works mid-corridor, the way the arcade does it.
		var swap := cell
		cell = to_cell
		to_cell = swap
		dir = wanted
		next_dir = Vector2i.ZERO
	else:
		next_dir = wanted


func _move(step: float) -> void:
	if dir == Vector2i.ZERO:
		_pick_direction()
		if dir == Vector2i.ZERO:
			return

	while step > 0.0:
		var target := MazeData.cell_to_world(to_cell)
		var to_target := target - position
		var dist := to_target.length()
		if dist > step:
			position += to_target / dist * step
			return
		position = target
		step -= dist
		_arrive()
		if dir == Vector2i.ZERO:
			return


func _arrive() -> void:
	cell = MazeData.wrap_cell(to_cell)
	position = MazeData.cell_to_world(cell)
	to_cell = cell
	entered_cell.emit(cell)
	_pick_direction()


# At a tile centre: take the queued turn if it is open, otherwise keep going
# straight, otherwise stop against the wall.
func _pick_direction() -> void:
	if next_dir != Vector2i.ZERO and not MazeData.is_wall(cell + next_dir):
		dir = next_dir
		next_dir = Vector2i.ZERO
	if dir == Vector2i.ZERO or MazeData.is_wall(cell + dir):
		dir = Vector2i.ZERO
		to_cell = cell
		return
	to_cell = cell + dir


func _draw() -> void:
	# A scooter seen from above, leaning very slightly as it rides.
	var lean := sin(_wobble) * 1.5 if dir != Vector2i.ZERO else 0.0
	var t := Transform2D(_facing, Vector2(0.0, lean))
	var hull := PackedVector2Array([
		Vector2(14.0, 0.0), Vector2(7.0, -6.0), Vector2(-9.0, -5.0),
		Vector2(-12.0, 0.0), Vector2(-9.0, 5.0), Vector2(7.0, 6.0),
	])
	for i in hull.size():
		hull[i] = t * hull[i]
	draw_colored_polygon(hull, BODY)

	# the delivery box strapped on the back
	var crate := PackedVector2Array([
		Vector2(-10.0, -4.0), Vector2(-3.0, -4.0), Vector2(-3.0, 4.0), Vector2(-10.0, 4.0),
	])
	for i in crate.size():
		crate[i] = t * crate[i]
	draw_colored_polygon(crate, CARGO)
	draw_polyline(crate + PackedVector2Array([crate[0]]), CARGO_EDGE, 1.0)

	draw_circle(t * Vector2(1.0, 0.0), 4.0, RIDER)
	draw_circle(t * Vector2(4.5, 0.0), 2.6, HELMET)
	draw_circle(t * Vector2(12.0, 0.0), 1.8, HEADLIGHT)
