extends Node2D

signal pellets_cleared

const WALL_COLOR := Color("2121de")
const WALL_EDGE := Color("4a4aff")
const DOOR_COLOR := Color("ffb8ff")
const PELLET_COLOR := Color("ffb897")
const INSET := 4.0

var pellets := {}  # Vector2i -> "." or "o"


func reset_pellets() -> void:
	pellets.clear()
	for y in MazeData.ROWS:
		for x in MazeData.COLS:
			var symbol: String = MazeData.LAYOUT[y][x]
			if symbol == "." or symbol == "o":
				pellets[Vector2i(x, y)] = symbol
	queue_redraw()


# Returns "." or "o" if something was eaten here, "" otherwise.
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
	for y in MazeData.ROWS:
		for x in MazeData.COLS:
			var cell := Vector2i(x, y)
			var symbol: String = MazeData.LAYOUT[y][x]
			if symbol == "#":
				_draw_wall(cell)
			elif symbol == "=":
				var origin := Vector2(cell) * MazeData.TILE
				draw_rect(Rect2(origin + Vector2(0, 13), Vector2(MazeData.TILE, 6)), DOOR_COLOR)

	for cell: Vector2i in pellets:
		var centre := MazeData.cell_to_world(cell)
		var radius := 7.0 if pellets[cell] == "o" else 3.0
		draw_circle(centre, radius, PELLET_COLOR)


# Walls are inset blocks that grow into their neighbours, so a run of wall
# tiles reads as one thick shape instead of a row of loose squares.
func _draw_wall(cell: Vector2i) -> void:
	var t := float(MazeData.TILE)
	var origin := Vector2(cell) * t
	var inner := Rect2(origin + Vector2(INSET, INSET), Vector2.ONE * (t - INSET * 2.0))
	draw_rect(inner, WALL_COLOR)

	if _is_wall_tile(cell + Vector2i.RIGHT):
		draw_rect(Rect2(origin + Vector2(t - INSET, INSET), Vector2(INSET * 2.0, inner.size.y)), WALL_COLOR)
	if _is_wall_tile(cell + Vector2i.DOWN):
		draw_rect(Rect2(origin + Vector2(INSET, t - INSET), Vector2(inner.size.x, INSET * 2.0)), WALL_COLOR)

	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if _is_wall_tile(cell + d):
			continue
		var a := inner.position
		var b := inner.end
		if d == Vector2i.UP:
			b = inner.position + Vector2(inner.size.x, 0.0)
		elif d == Vector2i.DOWN:
			a = inner.position + Vector2(0.0, inner.size.y)
		elif d == Vector2i.LEFT:
			b = inner.position + Vector2(0.0, inner.size.y)
		else:
			a = inner.position + Vector2(inner.size.x, 0.0)
		draw_line(a, b, WALL_EDGE, 2.0)


func _is_wall_tile(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= MazeData.COLS or cell.y < 0 or cell.y >= MazeData.ROWS:
		return false
	return MazeData.LAYOUT[cell.y][cell.x] == "#"
