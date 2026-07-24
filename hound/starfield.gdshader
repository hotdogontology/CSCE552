shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;


float random_value(vec2 coordinates) {
	return fract(
		sin(dot(coordinates, vec2(12.9898, 78.233))) * 43758.5453
	);
}


void fragment() {
	vec2 star_grid = UV * vec2(240.0, 120.0);
	vec2 star_cell = floor(star_grid);
	vec2 position_in_cell = fract(star_grid) - vec2(0.5);

	float star_chance = random_value(star_cell);
	vec2 star_offset = vec2(
		random_value(star_cell + vec2(17.0, 31.0)),
		random_value(star_cell + vec2(47.0, 13.0))
	) - vec2(0.5);
	float distance_from_star = length(
		position_in_cell - star_offset * 0.75
	);
	float star_shape = 1.0 - smoothstep(0.015, 0.07, distance_from_star);
	float star = step(0.985, star_chance) * star_shape;
	float brightness = mix(0.35, 1.0, random_value(star_cell + vec2(9.0)));

	vec3 background_color = vec3(0.002, 0.004, 0.012);
	vec3 star_color = vec3(0.75, 0.85, 1.0) * star * brightness;
	ALBEDO = background_color + star_color;
	EMISSION = background_color + star_color;
}
