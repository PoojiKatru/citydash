extends Node2D

const WALL_COLOR := Color("2121de")
const WALL_EDGE := Color("4a4aff")
const DOOR_COLOR := Color("ffb8ff")


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
				var door := Rect2(origin + Vector2(0, 13), Vector2(MazeData.TILE, 6))
				draw_rect(door, DOOR_COLOR)
