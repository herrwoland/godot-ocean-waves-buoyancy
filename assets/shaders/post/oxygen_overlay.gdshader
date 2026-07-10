shader_type canvas_item;
/**
 * No-HUD oxygen feedback: as breath runs out the world desaturates, cools
 * toward blue and a vignette closes in. Sits on a CanvasLayer below the PS1
 * post-process so it gets dithered along with the scene. intensity 0 = identity.
 */

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float flash_rate : hint_range(0.0, 5.0) = 0.0; // red pulses per second
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0; // 0 disables the drowning flash

void fragment() {
	vec3 col = texture(screen_texture, SCREEN_UV).rgb;
	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(grey) * vec3(0.8, 0.88, 1.0), intensity * 0.42);

	vec2 offset = SCREEN_UV - 0.5;
	float vignette = smoothstep(0.72, 0.18, length(offset) * (0.8 + intensity * 1.4));
	col *= mix(1.0, vignette, intensity * 0.5);

	// Drowning warning: a red vignette pulsing faster as air runs out.
	if (flash_amount > 0.0) {
		float pulse = 0.5 + 0.5 * sin(TIME * 6.2831853 * flash_rate);
		float ring = smoothstep(0.2, 0.65, length(offset));
		col = mix(col, vec3(0.55, 0.02, 0.02), ring * pulse * flash_amount * 0.5);
	}

	COLOR = vec4(col, 1.0);
}
