extends Node2D

signal pellets_cleared

const WALL_COLOR := Color("2121de")
const WALL_EDGE := Color("4a4aff")
const DOOR_COLOR := Color("ffb8ff")
const PELLET_COLOR := Color("ffb897")

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
			var symbol: String = MazeData.LAYOUT[y][x]
			var origin := Vector2(x * MazeData.TILE, y * MazeData.TILE)
			if symbol == "#":
				var block := Rect2(origin + Vector2(3, 3), Vector2.ONE * (MazeData.TILE - 6))
				draw_rect(block, WALL_COLOR)
				draw_rect(block, WALL_EDGE, false, 2.0)
			elif symbol == "=":
				draw_rect(Rect2(origin + Vector2(0, 13), Vector2(MazeData.TILE, 6)), DOOR_COLOR)

	for cell: Vector2i in pellets:
		var centre := MazeData.cell_to_world(cell)
		var radius := 7.0 if pellets[cell] == "o" else 3.0
		draw_circle(centre, radius, PELLET_COLOR)
