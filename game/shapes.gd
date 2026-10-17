class_name Shapes
extends RefCounted
## Stamp shape library.
##
## Each shape is drawn once as vector polygons in a unit box (0..1 on both
## axes). The logic grid never reads the polygons directly: `mask()` samples
## them at each cell centre, so the art and the rules can never disagree.
## All boxes are square so a 90° rotation maps grid cells onto grid cells.

const SHAPE_NAMES := [
	"square", "circle", "leaf", "petal", "sun", "tulip", "flower", "hedge",
	"apple", "cup", "plate", "pear", "slice", "toast", "bowl", "egg",
	"moon", "star", "cloud", "comet", "planet", "sparkle", "rocket",
	"triangle", "bar", "dot",
]

## Shapes that look the same after a 90° turn; never made rotatable.
const ROTATION_SYMMETRIC := ["square", "circle", "sun", "plate", "sparkle", "hedge", "dot"]

static var _poly_cache := {}
static var _merged_cache := {}
static var _inset_cache := {}
## Shapes whose merged outline filled in a hole (e.g. the cup handle).
static var _holed := {}
static var _mask_cache := {}


static func has_shape(shape_name: String) -> bool:
	return shape_name in SHAPE_NAMES


## Polygons for a shape in unit coordinates, rotated clockwise by `rot` degrees.
static func polygons(shape_name: String, rot: int = 0) -> Array:
	var key := "%s:%d" % [shape_name, rot]
	if _poly_cache.has(key):
		return _poly_cache[key]
	var base := _build(shape_name)
	var out := []
	var angle := deg_to_rad(rot)
	var c := Vector2(0.5, 0.5)
	for poly in base:
		if rot == 0:
			out.append(poly)
			continue
		var rp := PackedVector2Array()
		for p in poly:
			rp.append((p - c).rotated(angle) + c)
		out.append(rp)
	_poly_cache[key] = out
	return out


## The shape's parts merged into solid outlines (holes are filled), for
## drawing without seams or doubled translucency where parts overlap.
static func merged(shape_name: String, rot: int = 0) -> Array:
	var key := "%s:%d" % [shape_name, rot]
	if _merged_cache.has(key):
		return _merged_cache[key]
	var outs: Array = []
	for p in polygons(shape_name, rot):
		var cur: PackedVector2Array = p
		var i := 0
		while i < outs.size():
			var res := Geometry2D.merge_polygons(cur, outs[i])
			var solids := res.filter(func(q: PackedVector2Array) -> bool: return not Geometry2D.is_polygon_clockwise(q))
			if solids.size() == 1 and res.size() > 1:
				_holed[shape_name] = true
			if solids.size() == 1:
				cur = solids[0]
				outs.remove_at(i)
				i = 0
			else:
				i += 1
		outs.append(cur)
	_merged_cache[key] = outs
	return outs


## The merged outline shrunk inwards by `cells` grid cells, in unit
## coordinates, for the glossy inner highlight on a stamp of `size` cells.
static func inset(shape_name: String, rot: int, size: int, cells: float) -> Array:
	var key := "%s:%d:%d:%.2f" % [shape_name, rot, size, cells]
	if _inset_cache.has(key):
		return _inset_cache[key]
	var out: Array = []
	var outline := merged(shape_name, rot)
	# Insetting a filled-in outline would paint over the hole; use the parts.
	var source := polygons(shape_name, rot) if _holed.has(shape_name) else outline
	for poly in source:
		var scaled := PackedVector2Array()
		for p in poly:
			scaled.append(p * size)
		for q in Geometry2D.offset_polygon(scaled, -cells, Geometry2D.JOIN_ROUND):
			if Geometry2D.is_polygon_clockwise(q) or q.size() < 3:
				continue
			var unit := PackedVector2Array()
			for p in q:
				unit.append(p / size)
			if Geometry2D.triangulate_polygon(unit).size() > 0:
				out.append(unit)
	_inset_cache[key] = out
	return out


## Cells (local offsets inside a size×size box) covered by the shape.
static func mask(shape_name: String, size: int, rot: int = 0) -> Array[Vector2i]:
	rot = posmod(rot, 360)
	var key := "%s:%d:%d" % [shape_name, size, rot]
	if _mask_cache.has(key):
		return _mask_cache[key]
	var cells: Array[Vector2i] = []
	if rot == 0:
		var polys := polygons(shape_name, 0)
		for y in size:
			for x in size:
				var p := Vector2((x + 0.5) / size, (y + 0.5) / size)
				for poly in polys:
					if Geometry2D.is_point_in_polygon(p, poly):
						cells.append(Vector2i(x, y))
						break
	else:
		# Rotate the unrotated mask exactly instead of re-sampling, so edge
		# cells never flip because of floating point error.
		var prev := mask(shape_name, size, rot - 90)
		for c in prev:
			cells.append(Vector2i(size - 1 - c.y, c.x))
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y or (a.y == b.y and a.x < b.x))
	_mask_cache[key] = cells
	return cells


# --- geometry helpers -------------------------------------------------------

static func _ellipse(c: Vector2, r: Vector2, segments: int = 32, tilt: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(tilt))
	return pts


static func _circle(c: Vector2, r: float, segments: int = 32) -> PackedVector2Array:
	return _ellipse(c, Vector2(r, r), segments)


static func _rect(a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])


static func _star(c: Vector2, r_out: float, r_in: float, points: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var r := r_out if i % 2 == 0 else r_in
		var a := -PI / 2 + PI * i / points
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func _arc(c: Vector2, r: float, a0: float, a1: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a := lerpf(a0, a1, float(i) / steps)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## Outer circle minus an overlapping inner circle (a crescent).
static func _crescent(c: Vector2, r: float, c2: Vector2, r2: float) -> PackedVector2Array:
	var d := c.distance_to(c2)
	var a := (r * r - r2 * r2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(r * r - a * a, 0.0))
	var dir := (c2 - c) / d
	var mid := c + dir * a
	var p1 := mid + Vector2(-dir.y, dir.x) * h
	var p2 := mid - Vector2(-dir.y, dir.x) * h
	var t1 := (p1 - c).angle()
	var t2 := (p2 - c).angle()
	# Outer arc: the way round that does not face the inner circle.
	var away := (c - c2).angle()
	var outer := _arc_through(c, r, t1, t2, away, 40)
	# Inner arc: the part of the inner circle that lies inside the outer one.
	var u1 := (p1 - c2).angle()
	var u2 := (p2 - c2).angle()
	var inner := _arc_through(c2, r2, u2, u1, away, 32)
	var pts := PackedVector2Array()
	pts.append_array(outer)
	for i in range(1, inner.size() - 1):
		pts.append(inner[i])
	return pts


## Arc from angle a0 to a1 on circle (c, r) that passes through direction `via`.
static func _arc_through(c: Vector2, r: float, a0: float, a1: float, via: float, steps: int) -> PackedVector2Array:
	var ccw_end := a0 + fposmod(a1 - a0, TAU)
	var via_rel := fposmod(via - a0, TAU)
	if via_rel <= ccw_end - a0:
		return _arc(c, r, a0, ccw_end, steps)
	return _arc(c, r, a0, a0 - fposmod(a0 - a1, TAU), steps)


static func _teardrop(c: Vector2, half_w: float, half_h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 40:
		var t := TAU * i / 40
		pts.append(c + Vector2(half_w * sin(t) * sin(t / 2.0), -half_h * cos(t)))
	return pts


static func _build(shape_name: String) -> Array:
	match shape_name:
		"square":
			return [_rect(Vector2(0.06, 0.06), Vector2(0.94, 0.94))]
		"circle":
			return [_circle(Vector2(0.5, 0.5), 0.48)]
		"dot":
			return [_circle(Vector2(0.5, 0.5), 0.36)]
		"leaf":
			# A pointed leaf lying on the diagonal.
			var pts := PackedVector2Array()
			var a := Vector2(0.06, 0.94)
			var b := Vector2(0.94, 0.06)
			var axis: Vector2 = b - a
			var n := Vector2(-axis.y, axis.x).normalized()
			for i in 21:
				var t := i / 20.0
				pts.append(a + axis * t + n * 0.27 * sin(PI * t))
			for i in range(19, 0, -1):
				var t := i / 20.0
				pts.append(a + axis * t - n * 0.2 * sin(PI * t))
			return [pts]
		"petal":
			return [_teardrop(Vector2(0.5, 0.5), 0.44, 0.46)]
		"sun":
			var parts := [_circle(Vector2(0.5, 0.5), 0.3)]
			for i in 8:
				var ang := TAU * i / 8
				var dir := Vector2(cos(ang), sin(ang))
				var side := Vector2(-dir.y, dir.x) * 0.1
				var base := Vector2(0.5, 0.5) + dir * 0.25
				parts.append(PackedVector2Array([base + side, Vector2(0.5, 0.5) + dir * 0.49, base - side]))
			return parts
		"tulip":
			var pts := PackedVector2Array([Vector2(0.12, 0.08), Vector2(0.31, 0.3), Vector2(0.5, 0.04), Vector2(0.69, 0.3), Vector2(0.88, 0.08)])
			for i in 17:
				var ang := lerpf(0.0, PI, i / 16.0)
				pts.append(Vector2(0.5 + 0.38 * cos(ang), 0.52 + 0.42 * sin(ang)))
			return [pts]
		"flower":
			var parts := [_circle(Vector2(0.5, 0.5), 0.2)]
			for i in 5:
				var ang := -PI / 2 + TAU * i / 5
				parts.append(_circle(Vector2(0.5, 0.5) + Vector2(cos(ang), sin(ang)) * 0.28, 0.2))
			return parts
		"hedge":
			var parts := [_rect(Vector2(0.06, 0.2), Vector2(0.94, 0.8)), _rect(Vector2(0.2, 0.06), Vector2(0.8, 0.94))]
			for p in [Vector2(0.2, 0.2), Vector2(0.8, 0.2), Vector2(0.2, 0.8), Vector2(0.8, 0.8)]:
				parts.append(_circle(p, 0.14, 16))
			return parts
		"apple":
			return [
				_circle(Vector2(0.36, 0.6), 0.32),
				_circle(Vector2(0.64, 0.6), 0.32),
				_rect(Vector2(0.46, 0.04), Vector2(0.56, 0.32)),
				_ellipse(Vector2(0.7, 0.18), Vector2(0.16, 0.08), 20, -0.5),
			]
		"cup":
			var body := PackedVector2Array([Vector2(0.06, 0.2), Vector2(0.7, 0.2), Vector2(0.64, 0.9), Vector2(0.12, 0.9)])
			var handle := _arc(Vector2(0.68, 0.52), 0.26, -PI / 2, PI / 2, 16)
			var inner := _arc(Vector2(0.68, 0.52), 0.12, PI / 2, -PI / 2, 12)
			handle.append_array(inner)
			return [body, handle]
		"plate":
			var pts := PackedVector2Array()
			for i in 48:
				var ang := TAU * i / 48
				var r := 0.45 + 0.035 * cos(ang * 12)
				pts.append(Vector2(0.5, 0.5) + Vector2(cos(ang), sin(ang)) * r)
			return [pts]
		"pear":
			return [
				_circle(Vector2(0.5, 0.66), 0.3),
				_circle(Vector2(0.5, 0.36), 0.19),
				PackedVector2Array([Vector2(0.31, 0.38), Vector2(0.69, 0.38), Vector2(0.79, 0.62), Vector2(0.21, 0.62)]),
				_rect(Vector2(0.47, 0.04), Vector2(0.55, 0.2)),
			]
		"slice":
			return [PackedVector2Array([Vector2(0.06, 0.88), Vector2(0.94, 0.88), Vector2(0.94, 0.14)])]
		"toast":
			return [
				_rect(Vector2(0.1, 0.36), Vector2(0.9, 0.94)),
				_circle(Vector2(0.3, 0.34), 0.22),
				_circle(Vector2(0.7, 0.34), 0.22),
			]
		"bowl":
			var pts := _arc(Vector2(0.5, 0.36), 0.46, 0.0, PI, 24)
			return [pts, _rect(Vector2(0.02, 0.28), Vector2(0.98, 0.4))]
		"egg":
			var pts := PackedVector2Array()
			for i in 40:
				var t := TAU * i / 40
				var rx := 0.36 * (1.0 + 0.12 * sin(t))
				pts.append(Vector2(0.5 + rx * cos(t), 0.52 + 0.45 * sin(t)))
			return [pts]
		"moon":
			return [_crescent(Vector2(0.5, 0.5), 0.46, Vector2(0.7, 0.36), 0.36)]
		"star":
			return [_star(Vector2(0.5, 0.54), 0.5, 0.21, 5)]
		"cloud":
			return [
				_circle(Vector2(0.3, 0.58), 0.2),
				_circle(Vector2(0.52, 0.42), 0.27),
				_circle(Vector2(0.75, 0.6), 0.19),
				_rect(Vector2(0.12, 0.6), Vector2(0.92, 0.8)),
			]
		"comet":
			return [
				_circle(Vector2(0.7, 0.3), 0.24),
				PackedVector2Array([Vector2(0.52, 0.16), Vector2(0.86, 0.48), Vector2(0.06, 0.94)]),
			]
		"planet":
			return [
				_circle(Vector2(0.5, 0.5), 0.3),
				_ellipse(Vector2(0.5, 0.5), Vector2(0.5, 0.11), 32, -0.45),
			]
		"sparkle":
			return [_star(Vector2(0.5, 0.5), 0.5, 0.2, 4)]
		"rocket":
			return [PackedVector2Array([
				Vector2(0.5, 0.02), Vector2(0.66, 0.24), Vector2(0.66, 0.66), Vector2(0.86, 0.94),
				Vector2(0.6, 0.84), Vector2(0.4, 0.84), Vector2(0.14, 0.94), Vector2(0.34, 0.66), Vector2(0.34, 0.24),
			])]
		"triangle":
			return [PackedVector2Array([Vector2(0.5, 0.04), Vector2(0.96, 0.94), Vector2(0.04, 0.94)])]
		"bar":
			return [_rect(Vector2(0.36, 0.0), Vector2(0.64, 1.0))]
	push_error("Unknown stamp shape: %s" % shape_name)
	return [_rect(Vector2(0.1, 0.1), Vector2(0.9, 0.9))]
