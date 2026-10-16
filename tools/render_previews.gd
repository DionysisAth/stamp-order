extends SceneTree
## Renders every level's target as PNG contact sheets for quick review:
##   godot --headless --script res://tools/render_previews.gd -- <out_dir>
## Each sheet is 5 columns × 4 rows, row-major in level order. The left half
## of each tile is the drawn art, the right half the logic grid.

const PX := 8


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://build/previews")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var levels_node: Node = root.get_node("Levels")
	for w in levels_node.worlds:
		var tile := BoardState.SIZE * PX
		var sheet := Image.create(5 * (tile * 2 + 12) + 12, 4 * (tile + 12) + 12, false, Image.FORMAT_RGB8)
		sheet.fill(Color("8a6a4a"))
		var i := 0
		for level: Level in w["levels"]:
			var ox := 12 + (i % 5) * (tile * 2 + 12)
			var oy := 12 + (i / 5) * (tile + 12)
			_draw_art(sheet, level, ox, oy)
			_draw_grid(sheet, level, ox + tile, oy)
			i += 1
		var path := out_dir.path_join("world_%d.png" % w["number"])
		sheet.save_png(path)
		print("wrote ", path)
	quit()


func _draw_art(img: Image, level: Level, ox: int, oy: int) -> void:
	var tile := BoardState.SIZE * PX
	img.fill_rect(Rect2i(ox, oy, tile, tile), Palettes.PAPER)
	for p in level.solution_presses():
		var s := level.stamps[p[0]]
		var col := Palettes.color(level.palette, s.color)
		var o := Vector2(s.origin(p[1]))
		var polys := Shapes.polygons(s.shape, p[2])
		var x0 := int(o.x * PX)
		var y0 := int(o.y * PX)
		var span := s.size * PX
		for py in span:
			for px in span:
				var u := Vector2((px + 0.5) / span, (py + 0.5) / span)
				for poly in polys:
					if Geometry2D.is_point_in_polygon(u, poly):
						var X := ox + x0 + px
						var Y := oy + y0 + py
						if X < ox + tile and Y < oy + tile:
							img.set_pixel(X, Y, col)
						break


func _draw_grid(img: Image, level: Level, ox: int, oy: int) -> void:
	var t := level.target()
	for y in BoardState.SIZE:
		for x in BoardState.SIZE:
			var col := Palettes.color(level.palette, t.get_at(x, y))
			img.fill_rect(Rect2i(ox + x * PX, oy + y * PX, PX - 1, PX - 1), col)
