extends Node2D

enum State { HOUSE, LEAVING, CHASE, FRIGHTENED, EATEN }

const SPEED := 120.0
const FRIGHT_SPEED := 75.0
const EATEN_SPEED := 280.0

const CABIN := Color("1d2330")
const HEADLIGHT := Color("fff6c0")
const TAILLIGHT := Color("ff4a3d")
const HAZARD := Color("ffb02e")
const WRECK := Color("50505c")

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
	var heading := Vector2(dir).angle() if dir != Vector2i.ZERO else 0.0
	var t := Transform2D(heading, Vector2(0.0, sin(_bob) * 0.8))

	if state == State.EATEN:
		_draw_towed(t)
		return

	var paint := body_color
	var pulled_over := state == State.FRIGHTENED
	if pulled_over:
		var flashing := _fright_left < 2.0 and fmod(_fright_left, 0.4) < 0.2
		paint = Color("d8d8dd") if flashing else Color("4a4a55")

	var hull := PackedVector2Array([
		Vector2(14.0, -4.0), Vector2(14.0, 4.0), Vector2(9.0, 7.0),
		Vector2(-11.0, 7.0), Vector2(-13.0, 4.0), Vector2(-13.0, -4.0),
		Vector2(-11.0, -7.0), Vector2(9.0, -7.0),
	])
	for i in hull.size():
		hull[i] = t * hull[i]
	draw_colored_polygon(hull, paint)

	# windscreen and roof, so the car reads as facing somewhere
	_draw_box(t, Vector2(3.0, 0.0), Vector2(4.0, 4.5), CABIN)
	_draw_box(t, Vector2(-6.5, 0.0), Vector2(3.5, 4.5), paint.darkened(0.3))

	if pulled_over:
		for corner in [Vector2(12.0, -5.0), Vector2(12.0, 5.0), Vector2(-11.0, -5.0), Vector2(-11.0, 5.0)]:
			draw_circle(t * corner, 2.2, HAZARD)
	else:
		draw_circle(t * Vector2(13.0, -4.0), 2.0, HEADLIGHT)
		draw_circle(t * Vector2(13.0, 4.0), 2.0, HEADLIGHT)
		draw_circle(t * Vector2(-12.0, -4.0), 1.8, TAILLIGHT)
		draw_circle(t * Vector2(-12.0, 4.0), 1.8, TAILLIGHT)


# Once bumped, the car is a dead chassis being hauled back to the depot.
func _draw_towed(t: Transform2D) -> void:
	var hull := PackedVector2Array([
		Vector2(10.0, -5.0), Vector2(10.0, 5.0),
		Vector2(-10.0, 5.0), Vector2(-10.0, -5.0),
	])
	for i in hull.size():
		hull[i] = t * hull[i]
	draw_colored_polygon(hull, WRECK)
	draw_circle(t * Vector2(0.0, 0.0), 2.5, HAZARD)


func _draw_box(t: Transform2D, centre: Vector2, half: Vector2, tint: Color) -> void:
	var box := PackedVector2Array([
		centre + Vector2(-half.x, -half.y), centre + Vector2(half.x, -half.y),
		centre + Vector2(half.x, half.y), centre + Vector2(-half.x, half.y),
	])
	for i in box.size():
		box[i] = t * box[i]
	draw_colored_polygon(box, tint)
