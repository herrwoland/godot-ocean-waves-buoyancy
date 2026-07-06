shader_type canvas_item;
/**
 * No-HUD oxygen feedback: as breath runs out the world desaturates, cools
 * toward blue and a vignette closes in. Sits on a CanvasLayer below the PS1
 * post-process so it gets dithered along with the scene. intensity 0 = identity.
 */

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 col = texture(screen_texture, SCREEN_UV).rgb;
	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(grey) * vec3(0.8, 0.88, 1.0), intensity * 0.85);

	vec2 offset = SCREEN_UV - 0.5;
	float vignette = smoothstep(0.72, 0.18, length(offset) * (0.8 + intensity * 1.4));
	col *= mix(1.0, vignette, intensity);

	COLOR = vec4(col, 1.0);
}
