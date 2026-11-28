shader_type canvas_item;
render_mode unshaded, blend_mix;

/// AoE II-style palette swap: only replace dedicated team-index pixels from the
/// shared 32-colour PR #10 palette. Other colours pass through unchanged.
/// Source PNGs paint team cloth/banners/shields as TEAM_SRC_0 (player blue).

uniform vec4 team_color : source_color = vec4(0.15686, 0.33725, 0.62745, 1.0);
/// Exact palette match (1/255 ≈ 0.004); keep tiny slack for filter rounding.
uniform float match_threshold = 0.008;

/// Canonical team blue baked into finished sprites (40, 86, 160).
const vec3 TEAM_SRC_0 = vec3(40.0 / 255.0, 86.0 / 255.0, 160.0 / 255.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float is_team = step(distance(c.rgb, TEAM_SRC_0), match_threshold) * step(0.01, c.a);
	COLOR = mix(c, vec4(team_color.rgb, c.a), is_team);
}
