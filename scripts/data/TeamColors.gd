extends RefCounted
class_name TeamColors
## Central team colours — palette-swap targets + minimap. Ready for more teams.


const PLAYER_TEAM := 0
const AI_TEAM := 1

## Matches the PR #10 palette team blue baked into sprites (40, 86, 160).
const PLAYER := Color(40.0 / 255.0, 86.0 / 255.0, 160.0 / 255.0, 1.0)
## AoE-style enemy red (also present in the shared palette as 188, 42, 36).
const AI := Color(188.0 / 255.0, 42.0 / 255.0, 36.0 / 255.0, 1.0)

const MINIMAP_UNIT := {
	PLAYER_TEAM: Color(0.25, 0.55, 0.95),
	AI_TEAM: Color(0.95, 0.25, 0.2),
}
const MINIMAP_BUILD := {
	PLAYER_TEAM: Color(0.35, 0.65, 1.0),
	AI_TEAM: Color(1.0, 0.35, 0.25),
}

const SHADER_PATH := "res://assets/shaders/team_recolour.gdshader"

static var _shader: Shader
static var _materials: Dictionary = {} ## team_id -> ShaderMaterial


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


## Assign palette-swap material (does not touch modulate — callers clear tint).
static func apply(canvas: CanvasItem, team: int) -> void:
	if canvas == null or not is_instance_valid(canvas):
		return
	canvas.material = material_for(team)
