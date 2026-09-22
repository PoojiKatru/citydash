extends Node2D

enum State { HOUSE, LEAVING, CHASE, FRIGHTENED, EATEN }

const SPEED := 120.0
const FRIGHT_SPEED := 75.0
const EATEN_SPEED := 280.0

# Set by main.gd before the ghost is added to the board.
var personality := 0
var body_color := Color.RED
var home_corner := Vector2i(1, 1)
var release_delay := 0.0
var start_cell := Vector2i.ZERO
var player: Node2D = null

var state: State = State.CHASE
var cell: Vector2i
var to_cell: Vector2i
var dir := Vector2i.LEFT

@onready var door_cell: Vector2i = MazeData.find_all("=")[0]
@onready var exit_cell: Vector2i = door_cell + Vector2i.UP
@onready var house_cell: Vector2i = door_cell + Vector2i.DOWN

var _timer := 0.0
var _bob := 0.0
var _fright_left := 0.0


func spawn() -> void:
	cell = start_cell
	to_cell = start_cell
	position = MazeData.cell_to_world(start_cell)
	dir = Vector2i.LEFT
	_timer = 0.0
	_fright_left = 0.0
	state = State.HOUSE if start_cell.y > door_cell.y else State.CHASE
	if state == State.CHASE:
		_pick_direction()
	queue_redraw()


func is_frightened() -> bool:
	return state == State.FRIGHTENED


# A ghost sitting in the house or already eaten cannot hurt or be eaten.
func is_catchable() -> bool:
	return state != State.HOUSE and state != State.EATEN


func frighten(seconds: float) -> void:
	# Ghosts still squeezing out of the house are left alone: the door is
	# one-way, so turning one around there would trap it inside for good.
	if state == State.EATEN or state == State.HOUSE or state == State.LEAVING:
		return
	_fright_left = seconds
	if state != State.FRIGHTENED:
		state = State.FRIGHTENED
		# Turn tail, like the arcade does when a power pellet goes.
		var swap := cell
		cell = to_cell
		to_cell = swap
		dir = -dir


func get_eaten() -> void:
	state = State.EATEN
	_fright_left = 0.0


func _process(delta: float) -> void:
	_bob = fmod(_bob + delta * 6.0, TAU)
	match state:
		State.HOUSE:
			_timer += delta
			position = MazeData.cell_to_world(cell) + Vector2(0.0, sin(_bob) * 4.0)
			if _timer >= release_delay:
				position = MazeData.cell_to_world(cell)
				state = State.LEAVING
				dir = Vector2i.UP
				_pick_direction()
		State.FRIGHTENED:
			_fright_left -= delta
			if _fright_left <= 0.0:
				state = State.CHASE
			_move(FRIGHT_SPEED * delta)
		State.EATEN:
			_move(EATEN_SPEED * delta)
		_:
			_move(SPEED * delta)
	queue_redraw()


func _move(step: float) -> void:
	while step > 0.0:
		var target := MazeData.cell_to_world(to_cell)
		var to_target := target - position
		var dist := to_target.length()
		if dist > step:
			position += to_target / dist * step
			return
		step -= dist
		cell = MazeData.wrap_cell(to_cell)
		position = MazeData.cell_to_world(cell)
		_on_cell_reached()
		if state == State.HOUSE:
			return


func _on_cell_reached() -> void:
	if state == State.LEAVING and cell == exit_cell:
		state = State.CHASE
	elif state == State.EATEN and cell == house_cell:
		state = State.HOUSE
		_timer = 0.0
		release_delay = 1.5
		to_cell = cell
		return
	_pick_direction()


# Ghosts never turn back on themselves; at every junction they take the exit
# that lands them closest to their target tile.
func _pick_direction() -> void:
	var options: Array[Vector2i] = []
	for d in [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]:
		if d == -dir or _blocked(cell + d):
			continue
		options.append(d)

	if options.is_empty():
		dir = -dir
	elif state == State.FRIGHTENED:
		dir = options.pick_random()
	else:
		var target := _target_cell()
		var best := options[0]
		var best_dist := INF
		for d in options:
			var dist := Vector2(MazeData.wrap_cell(cell + d) - target).length_squared()
			if dist < best_dist:
				best_dist = dist
				best = d
		dir = best
	to_cell = cell + dir


func _blocked(c: Vector2i) -> bool:
	var symbol := MazeData.cell_at(MazeData.wrap_cell(c))
	if symbol == "=":
		return state != State.LEAVING and state != State.EATEN
	return symbol == "#"


func _target_cell() -> Vector2i:
	if state == State.LEAVING:
		return exit_cell
	if state == State.EATEN:
		return house_cell
	if player == null:
		return home_corner

	var p: Vector2i = player.cell
	var heading: Vector2i = player.dir
	match personality:
		1:
			return p + heading * 4   # pink cuts the corner ahead of you
		2:
			return p - heading * 4   # cyan sits on your tail
		3:
			# orange loses its nerve once it gets close
			return home_corner if Vector2(p - cell).length() < 8.0 else p
		_:
			return p                 # red just comes straight for you


func _draw() -> void:
	var r := MazeData.TILE * 0.42
	if state == State.EATEN:
		_draw_eyes(r)
		return

	var skin := body_color
	if state == State.FRIGHTENED:
		var flashing := _fright_left < 2.0 and fmod(_fright_left, 0.4) < 0.2
		skin = Color.WHITE if flashing else Color("2121de")

	var body := PackedVector2Array()
	var arc_steps := 16
	for i in arc_steps + 1:
		var a := lerpf(PI, TAU, float(i) / arc_steps)
		body.append(Vector2(cos(a), sin(a)) * r)

	var hem := r * 0.85
	body.append(Vector2(r, hem))
	var feet := 6
	for i in range(1, feet + 1):
		var x := lerpf(r, -r, float(i) / feet)
		body.append(Vector2(x, hem - (5.0 if i % 2 == 1 else 0.0)))
	draw_colored_polygon(body, skin)

	if state == State.FRIGHTENED:
		draw_circle(Vector2(-r * 0.3, -r * 0.15), r * 0.14, Color.WHITE)
		draw_circle(Vector2(r * 0.3, -r * 0.15), r * 0.14, Color.WHITE)
	else:
		_draw_eyes(r)


func _draw_eyes(r: float) -> void:
	var look := Vector2(dir) * r * 0.14
	for side in [-1.0, 1.0]:
		var centre := Vector2(side * r * 0.33, -r * 0.15)
		draw_circle(centre, r * 0.28, Color.WHITE)
		draw_circle(centre + look, r * 0.13, Color("2121de"))
