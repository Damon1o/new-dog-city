extends RefCounted
## HQ puzzle floors (spec 04): floor id -> {type, grid, params, par_time}, built by
## scripts/world/hq_floor.gd. Grid: 15 x 10, one char per 64 px tile.
##   # wall   . floor   S start   D exit door (open while the puzzle is solved)
##   sort     1-9 crates   _ pad row
##   logic    a b c plates (A B C = plate with a crate on it)   x crate   & | ! gate tiles;
##            params.gates: gate -> its inputs, params.door: the gate that feeds the door
##   program  k key   g gate (bark opens it); Byte starts facing up, 1-4 = forward/left/right/bark
## params.hint shows after 3 resets on that floor.

const PUZZLES := {
	"nyc_1": {"type": "sort", "par_time": 120.0, "params": {"hint": "Get under a crate to shove it up onto its pad."},
		"grid": [
			"###############",
			"#.............#",
			"#....____.....#",
			"#.............#",
			"#.............D",
			"#..1.....3....#",
			"#.....2.......#",
			"#.......4.....#",
			"#......S......#",
			"###############",
		]},
	"nyc_2": {"type": "logic", "par_time": 90.0,
		"params": {"gates": {"&": ["a", "!"], "!": ["b"]}, "door": "&",
			"hint": "AND needs both inputs. NOT flips b: get the crate off b and onto a."},
		"grid": [
			"#######D#######",
			"#........&.!..#",
			"#.............#",
			"#.............#",
			"#.............#",
			"#...a.....B...#",
			"#.............#",
			"#.............#",
			"#......S......#",
			"###############",
		]},
	"nyc_3": {"type": "program", "par_time": 90.0,
		"params": {"hint": "The long way round needs more than 8 steps. Bark the gate open instead."},
		"grid": [
			"###############",
			"###############",
			"###############",
			"###############",
			"#####D#########",
			"###.gk.....####",
			"###.######.####",
			"###S.......####",
			"###############",
			"###############",
		]},
}
