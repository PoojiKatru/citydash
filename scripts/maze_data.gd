extends RefCounted
class_name MazeData

# One place for the maze shape so every script agrees on it.
#   #  wall
#   .  pellet
#   o  power pellet
#   =  ghost house door
#   P  player spawn
#   G  ghost spawn
#      (space) empty floor

const TILE := 32
const COLS := 19
const ROWS := 21

const LAYOUT := [
	"###################",
	"#........#........#",
	"#o##.###.#.###.##o#",
	"#.................#",
	"#.##.#.#####.#.##.#",
	"#....#...#...#....#",
	"####.### # ###.####",
	"   #.#   G   #.#   ",
	"####.# ##=## #.####",
	"    .  #GGG#  .    ",
	"####.# ##### #.####",
	"   #.#       #.#   ",
	"####.# ##### #.####",
	"#........#........#",
	"#.##.###.#.###.##.#",
	"#o.#.....P.....#.o#",
	"##.#.#.#####.#.#.##",
	"#....#...#...#....#",
	"#.######.#.######.#",
	"#.................#",
	"###################",
]


static func cell_at(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= ROWS:
		return "#"
	return LAYOUT[cell.y][cell.x]


# The tunnel row wraps around, so x is allowed to run off either edge.
static func wrap(cell: Vector2i) -> Vector2i:
	return Vector2i(wrapi(cell.x, 0, COLS), cell.y)


static func is_wall(cell: Vector2i) -> bool:
	var c := cell_at(wrap(cell))
	return c == "#" or c == "="


static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE * 0.5, cell.y * TILE + TILE * 0.5)


static func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


static func find_all(symbol: String) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for y in ROWS:
		for x in COLS:
			if LAYOUT[y][x] == symbol:
				found.append(Vector2i(x, y))
	return found
