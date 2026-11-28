extends RefCounted
class_name TeamColors
## Central team colours — palette-swap targets + minimap. Ready for more teams.


const PLAYER_TEAM := 0
const AI_TEAM := 1

## Matches the PR #10 palette team blue baked into sprites (40, 86, 160).
const PLAYER := Color(40.0 / 255.0, 86.0 / 255.0, 160.0 / 255.0, 1.0)
## AoE-style enemy red (also present in the shared palette as 188, 42, 36).
const AI := Color(188.0 / 255.0, 42.0 / 255.0, 36.0 / 255.0, 1.0)

## Soft AI tint when sprite has no team-blue pixels (art debt — shader would be a no-op).
const AI_TINT_UNIT := Color(1.0, 0.55, 0.55, 1.0)
const AI_TINT_BUILDING := Color(0.75, 0.45, 0.45, 1.0)

const MINIMAP_UNIT := {
	PLAYER_TEAM: Color(0.25, 0.55, 0.95),
	AI_TEAM: Color(0.95, 0.25, 0.2),
}
const MINIMAP_BUILD := {
	PLAYER_TEAM: Color(0.35, 0.65, 1.0),
	AI_TEAM: Color(1.0, 0.35, 0.25),
}

const SHADER_PATH := "res://assets/shaders/team_recolour.gdshader"
## Aligned with shader match_threshold (~2/255).
const TEAM_BLUE_MATCH := 2.0 / 255.0

static var _shader: Shader
static var _materials: Dictionary = {} ## team_id -> ShaderMaterial
static var _team_blue_cache: Dictionary = {} ## texture key -> bool


static func color_for(team: int) -> Color:
	if team == PLAYER_TEAM:
		return PLAYER
	return AI


static func minimap_unit(team: int) -> Color:
	return MINIMAP_UNIT.get(team, MINIMAP_UNIT[AI_TEAM]) as Color


static func minimap_build(team: int) -> Color:
	return MINIMAP_BUILD.get(team, MINIMAP_BUILD[AI_TEAM]) as Color


static func material_for(team: int) -> ShaderMaterial:
	if _materials.has(team):
		return _materials[team] as ShaderMaterial
	if _shader == null:
		_shader = load(SHADER_PATH) as Shader
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("team_color", color_for(team))
	_materials[team] = mat
	return mat


## True if texture contains dedicated team-blue pixels (cached per texture).
static func texture_has_team_blue(tex: Texture2D) -> bool:
	if tex == null:
		return false
	var key: String = tex.resource_path
	if key.is_empty():
		key = str(tex.get_instance_id())
	if _team_blue_cache.has(key):
		return bool(_team_blue_cache[key])
	var found := false
	var img: Image = tex.get_image()
	## CompressedTexture2D may lack a CPU image — fall back to source PNG on disk.
	if img == null and not tex.resource_path.is_empty():
		var abs_path := ProjectSettings.globalize_path(tex.resource_path)
		if FileAccess.file_exists(abs_path):
			img = Image.load_from_file(abs_path)
	if img != null:
		if img.is_compressed():
			img = img.duplicate()
			img.decompress()
		var w := img.get_width()
		var h := img.get_height()
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				if c.a < 0.01:
					continue
				if (
					absf(c.r - PLAYER.r) <= TEAM_BLUE_MATCH
					and absf(c.g - PLAYER.g) <= TEAM_BLUE_MATCH
					and absf(c.b - PLAYER.b) <= TEAM_BLUE_MATCH
				):
					found = true
					break
			if found:
				break
	_team_blue_cache[key] = found
	return found


## Modulate for AI sprites without team-blue; WHITE when shader can recolour.
static func modulate_for(canvas: CanvasItem, team: int, building: bool = false) -> Color:
	if team == PLAYER_TEAM:
		return Color.WHITE
	var tex: Texture2D = null
	if canvas is Sprite2D:
		tex = (canvas as Sprite2D).texture
	if texture_has_team_blue(tex):
		return Color.WHITE
	return AI_TINT_BUILDING if building else AI_TINT_UNIT


## Assign palette-swap material + tint fallback (also used after monk conversion).
static func apply(canvas: CanvasItem, team: int, building: bool = false) -> void:
	if canvas == null or not is_instance_valid(canvas):
		return
	canvas.material = material_for(team)
	canvas.modulate = modulate_for(canvas, team, building)
