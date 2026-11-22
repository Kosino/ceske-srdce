extends Object
class_name FormationData
## AoE II-style group formations. Spacing = NÁVRH.

const LINE := "line"
const SCATTERED := "scattered"
const BOX := "box" # wedge/box grid

const NAMES := {
	LINE: "Řada",
	SCATTERED: "Rozptyl",
	BOX: "Box",
}

## NÁVRH (Honza schvaluje): spacing between unit centers in px.
const SPACING := {
	LINE: 36.0,
	SCATTERED: 56.0,
	BOX: 40.0,
}


static func display_name(kind: String) -> String:
	return str(NAMES.get(kind, kind))


static func spacing(kind: String) -> float:
	return float(SPACING.get(kind, SPACING[LINE]))


## Offsets relative to the click destination; `facing` = move direction.
static func offsets(kind: String, count: int, facing: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if count <= 0:
		return out
	var f := facing.normalized()
	if f.length_squared() < 0.0001:
		f = Vector2.RIGHT
	var right := Vector2(-f.y, f.x)
	var gap := spacing(kind)
	match kind:
		SCATTERED:
			_fill_scattered(out, count, f, right, gap)
		BOX:
			_fill_box(out, count, f, right, gap)
		_:
			_fill_line(out, count, right, gap)
	return out


static func _fill_line(out: Array[Vector2], count: int, right: Vector2, gap: float) -> void:
	var start := -0.5 * float(count - 1) * gap
	for i in count:
		out.append(right * (start + float(i) * gap))


static func _fill_scattered(out: Array[Vector2], count: int, forward: Vector2, right: Vector2, gap: float) -> void:
	var start := -0.5 * float(count - 1) * gap
	for i in count:
		# Deterministic depth jitter (no RNG) so tests stay stable.
		var depth := float((i * 37) % 5) - 2.0
		out.append(right * (start + float(i) * gap) + forward * (depth * gap * 0.35))


static func _fill_box(out: Array[Vector2], count: int, forward: Vector2, right: Vector2, gap: float) -> void:
	var cols := int(ceil(sqrt(float(count))))
	var rows := int(ceil(float(count) / float(cols)))
	var i := 0
	for r in rows:
		var row_count := mini(cols, count - i)
		var row_start := -0.5 * float(row_count - 1) * gap
		var back := -forward * (float(r) * gap)
		for c in row_count:
			out.append(right * (row_start + float(c) * gap) + back)
			i += 1
