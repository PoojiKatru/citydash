extends Node2D

signal pellets_cleared

const ROAD := Color("17171c")
const LANE_PAINT := Color("6d6a3f")
const BUILDING_TONES := [Color("3a3f4b"), Color("32363f"), Color("434857"), Color("2d313a")]
const ROOFLINE := Color("5c6373")
const WINDOW_LIT := Color("c9a24a")
const WINDOW_DARK := Color("222633")
const PARCEL := Color("f0602a")
const PARCEL_TAPE := Color("ffe9d6")
const PARCEL_EDGE := Color("7a2f12")
const SHUTTER := Color("d8a13a")
const CUP := Color("f4f4f4")
const CUP_LID := Color("c0392b")

var pellets := {}  # Vector2i -> "." or "o"


func reset_pellets() -> void:
	pellets.clear()
	for y in MazeData.ROWS:
		for x in MazeData.COLS:
			var symbol: String = MazeData.LAYOUT[y][x]
			if symbol == "." or symbol == "o":
				pellets[Vector2i(x, y)] = symbol
	queue_redraw()


# Returns "." or "o" if something was picked up here, "" otherwise.
func eat(cell: Vector2i) -> String:
	if not pellets.has(cell):
		return ""
	var kind: String = pellets[cell]
	pellets.erase(cell)
	queue_redraw()
	if pellets.is_empty():
		pellets_cleared.emit()
	return kind


func _draw() -> void:
	var t := float(MazeData.TILE)
	draw_rect(Rect2(Vector2.ZERO, Vector2(MazeData.COLS, MazeData.ROWS) * t), ROAD)

	for y in MazeData.ROWS:
		for x in MazeData.COLS:
			var cell := Vector2i(x, y)
			match MazeData.LAYOUT[y][x]:
				"#":
					_draw_building(cell)
				"=":
					_draw_shutter(cell)
				_:
					_draw_lane_markings(cell)

	for cell: Vector2i in pellets:
		if pellets[cell] == "o":
			_draw_coffee(MazeData.cell_to_world(cell))
		else:
			_draw_parcel(MazeData.cell_to_world(cell))


func _draw_building(cell: Vector2i) -> void:
	var t := float(MazeData.TILE)
	var origin := Vector2(cell) * t
	# Tones are grouped in coarse patches so a block reads as one building.
	var tone: Color = BUILDING_TONES[(cell.x / 4 * 3 + cell.y / 4 * 5) % BUILDING_TONES.size()]
	draw_rect(Rect2(origin, Vector2(t, t)), tone)

	for i in 4:
		var col := i % 2
		var row := i / 2
		var lit := (cell.x * 31 + cell.y * 17 + i * 7) % 6 < 2
		var spot := origin + Vector2(6.0 + col * 13.0, 6.0 + row * 13.0)
		draw_rect(Rect2(spot, Vector2(7.0, 7.0)), WINDOW_LIT if lit else WINDOW_DARK)

	# A roofline only where the building actually meets the street.
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if _is_building(cell + d):
			continue
		var a := origin
		var b := origin + Vector2(t, t)
		if d == Vector2i.UP:
			b = origin + Vector2(t, 0.0)
		elif d == Vector2i.DOWN:
			a = origin + Vector2(0.0, t)
		elif d == Vector2i.LEFT:
			b = origin + Vector2(0.0, t)
		else:
			a = origin + Vector2(t, 0.0)
		draw_line(a, b, ROOFLINE, 2.0)


func _draw_shutter(cell: Vector2i) -> void:
	var t := float(MazeData.TILE)
	var origin := Vector2(cell) * t
	for i in 4:
		draw_rect(Rect2(origin + Vector2(2.0, 11.0 + i * 3.0), Vector2(t - 4.0, 2.0)), SHUTTER)


# Dashes run down the middle of a street, but never through a junction.
func _draw_lane_markings(cell: Vector2i) -> void:
	var horizontal := not _is_solid(cell + Vector2i.LEFT) and not _is_solid(cell + Vector2i.RIGHT)
	var vertical := not _is_solid(cell + Vector2i.UP) and not _is_solid(cell + Vector2i.DOWN)
	if horizontal == vertical:
		return
	var centre := MazeData.cell_to_world(cell)
	var half := Vector2(9.0, 0.0) if horizontal else Vector2(0.0, 9.0)
	draw_line(centre - half, centre + half, LANE_PAINT, 2.0)


func _draw_parcel(centre: Vector2) -> void:
	var box := Rect2(centre - Vector2(5.5, 5.5), Vector2(11.0, 11.0))
	draw_rect(box, PARCEL)
	draw_rect(box, PARCEL_EDGE, false, 1.0)
	draw_line(centre - Vector2(0.0, 5.5), centre + Vector2(0.0, 5.5), PARCEL_TAPE, 2.0)


func _draw_coffee(centre: Vector2) -> void:
	var body := PackedVector2Array([
		centre + Vector2(-6.0, -4.0),
		centre + Vector2(6.0, -4.0),
		centre + Vector2(4.0, 8.0),
		centre + Vector2(-4.0, 8.0),
	])
	draw_colored_polygon(body, CUP)
	draw_rect(Rect2(centre + Vector2(-7.0, -8.0), Vector2(14.0, 4.0)), CUP_LID)


func _is_building(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= MazeData.COLS or cell.y < 0 or cell.y >= MazeData.ROWS:
		return true
	return MazeData.LAYOUT[cell.y][cell.x] == "#"


func _is_solid(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= MazeData.COLS or cell.y < 0 or cell.y >= MazeData.ROWS:
		return true
	var symbol: String = MazeData.LAYOUT[cell.y][cell.x]
	return symbol == "#" or symbol == "="
