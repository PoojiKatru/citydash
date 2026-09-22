extends Node2D

enum State { DEPOT, EXITING, DRIVING, PULLED_OVER, TOWED }

const SPEED := 120.0
const PULLOVER_SPEED := 75.0
const TOW_SPEED := 280.0

const CABIN := Color("1d2330")
const HEADLIGHT := Color("fff6c0")
const TAILLIGHT := Color("ff4a3d")
const HAZARD := Color("ffb02e")
const WRECK := Color("50505c")

# Set by main.gd before the car is added to the board.
var personality := 0
var body_color := Color.RED
var patrol_corner := Vector2i(1, 1)
var release_delay := 0.0
var start_cell := Vector2i.ZERO
var courier: Node2D = null

var state: State = State.DRIVING
var cell: Vector2i
var to_cell: Vector2i
var dir := Vector2i.LEFT

@onready var shutter_cell: Vector2i = CityData.find_all("=")[0]
@onready var exit_cell: Vector2i = shutter_cell + Vector2i.UP
@onready var depot_cell: Vector2i = shutter_cell + Vector2i.DOWN

var _timer := 0.0
var _bob := 0.0
var _pullover_left := 0.0


func spawn() -> void:
	cell = start_cell
	to_cell = start_cell
	position = CityData.cell_to_world(start_cell)
	dir = Vector2i.LEFT
	_timer = 0.0
	_pullover_left = 0.0
	state = State.DEPOT if start_cell.y > shutter_cell.y else State.DRIVING
	if state == State.DRIVING:
		_pick_direction()
	queue_redraw()


func is_pulled_over() -> bool:
	return state == State.PULLED_OVER


# A car sitting in the house or already eaten cannot hurt or be eaten.
func is_on_the_road() -> bool:
	return state != State.DEPOT and state != State.TOWED


func pull_over(seconds: float) -> void:
	# Cars still squeezing out of the house are left alone: the door is
	# one-way, so turning one around there would trap it inside for good.
	if state == State.TOWED or state == State.DEPOT or state == State.EXITING:
		return
	_pullover_left = seconds
	if state != State.PULLED_OVER:
		state = State.PULLED_OVER
		# Swing around the moment the coffee lands.
		var swap := cell
		cell = to_cell
		to_cell = swap
		dir = -dir


func tow() -> void:
	state = State.TOWED
	_pullover_left = 0.0


func _process(delta: float) -> void:
	_bob = fmod(_bob + delta * 6.0, TAU)
	match state:
		State.DEPOT:
			_timer += delta
			position = CityData.cell_to_world(cell) + Vector2(0.0, sin(_bob) * 4.0)
			if _timer >= release_delay:
				position = CityData.cell_to_world(cell)
				state = State.EXITING
				dir = Vector2i.UP
				_pick_direction()
		State.PULLED_OVER:
			_pullover_left -= delta
			if _pullover_left <= 0.0:
				state = State.DRIVING
			_move(PULLOVER_SPEED * delta)
		State.TOWED:
			_move(TOW_SPEED * delta)
		_:
			_move(SPEED * delta)
	queue_redraw()


func _move(step: float) -> void:
	while step > 0.0:
		var target := CityData.cell_to_world(to_cell)
		var to_target := target - position
		var dist := to_target.length()
		if dist > step:
			position += to_target / dist * step
			return
		step -= dist
		cell = CityData.wrap_cell(to_cell)
		position = CityData.cell_to_world(cell)
		_on_cell_reached()
		if state == State.DEPOT:
			return


func _on_cell_reached() -> void:
	if state == State.EXITING and cell == exit_cell:
		state = State.DRIVING
	elif state == State.TOWED and cell == depot_cell:
		state = State.DEPOT
		_timer = 0.0
		release_delay = 1.5
		to_cell = cell
		return
	_pick_direction()


# Cars never turn back on themselves; at every junction they take the exit
# that lands them closest to their target tile.
func _pick_direction() -> void:
	var options: Array[Vector2i] = []
	for d in [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]:
		if d == -dir or _blocked(cell + d):
			continue
		options.append(d)

	if options.is_empty():
		dir = -dir
	elif state == State.PULLED_OVER:
		dir = options.pick_random()
	else:
		var target := _target_cell()
		var best := options[0]
		var best_dist := INF
		for d in options:
			var dist := Vector2(CityData.wrap_cell(cell + d) - target).length_squared()
			if dist < best_dist:
				best_dist = dist
				best = d
		dir = best
	to_cell = cell + dir


func _blocked(c: Vector2i) -> bool:
	var symbol := CityData.cell_at(CityData.wrap_cell(c))
	if symbol == "=":
		return state != State.EXITING and state != State.TOWED
	return symbol == "#"


func _target_cell() -> Vector2i:
	if state == State.EXITING:
		return exit_cell
	if state == State.TOWED:
		return depot_cell
	if courier == null:
		return patrol_corner

	var p: Vector2i = courier.cell
	var heading: Vector2i = courier.dir
	match personality:
		1:
			return p + heading * 4   # pink cuts the corner ahead of you
		2:
			return p - heading * 4   # cyan sits on your tail
		3:
			# orange loses its nerve once it gets close
			return patrol_corner if Vector2(p - cell).length() < 8.0 else p
		_:
			return p                 # red just comes straight for you


func _draw() -> void:
	var heading := Vector2(dir).angle() if dir != Vector2i.ZERO else 0.0
	var t := Transform2D(heading, Vector2(0.0, sin(_bob) * 0.8))

	if state == State.TOWED:
		_draw_towed(t)
		return

	var paint := body_color
	var pulled_over := state == State.PULLED_OVER
	if pulled_over:
		var flashing := _pullover_left < 2.0 and fmod(_pullover_left, 0.4) < 0.2
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
