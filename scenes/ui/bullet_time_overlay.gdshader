shader_type canvas_item;
// Full-screen bullet-time look: desaturated warm tint, slight chromatic
// aberration towards the edges and a vignette. Faded in by "intensity".

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint : source_color = vec3(1.0, 0.86, 0.62);
uniform float desaturation : hint_range(0.0, 1.0) = 0.65;
uniform float aberration = 0.006;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_center = uv - vec2(0.5);
	float dist = length(from_center);

	vec3 original = texture(screen_texture, uv).rgb;
	vec3 shifted;
	shifted.r = texture(screen_texture, uv - from_center * aberration).r;
	shifted.g = original.g;
	shifted.b = texture(screen_texture, uv + from_center * aberration).b;

	float luma = dot(shifted, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(shifted, vec3(luma) * tint, desaturation);
	float vignette = smoothstep(0.85, 0.25, dist);
	graded *= mix(1.0, vignette, vignette_strength);

	COLOR = vec4(mix(original, graded, intensity), 1.0);
}
