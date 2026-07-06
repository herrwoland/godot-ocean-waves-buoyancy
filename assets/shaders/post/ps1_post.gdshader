shader_type canvas_item;
/**
 * PS1-style post-process: pixelates the screen to a low target resolution,
 * quantizes colors (posterize, ~15-bit look at 32 levels) and applies ordered
 * Bayer dithering to fake the missing color depth, like PS1-era hardware did.
 * Lives on a fullscreen ColorRect in a CanvasLayer below the UI.
 */

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform vec2 target_resolution = vec2(320.0, 180.0);
uniform int color_levels : hint_range(2, 64) = 32;
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;

const mat4 BAYER = mat4(
	vec4( 0.0,  8.0,  2.0, 10.0),
	vec4(12.0,  4.0, 14.0,  6.0),
	vec4( 3.0, 11.0,  1.0,  9.0),
	vec4(15.0,  7.0, 13.0,  5.0));

void fragment() {
	// Snap to the center of a low-res "pixel" and sample the screen there.
	vec2 pixel_uv = (floor(SCREEN_UV * target_resolution) + 0.5) / target_resolution;
	vec3 color = texture(screen_texture, pixel_uv).rgb;

	// Ordered dithering: per low-res pixel threshold offset, scaled to one quantization step.
	ivec2 pix = ivec2(floor(SCREEN_UV * target_resolution));
	float threshold = (BAYER[pix.x % 4][pix.y % 4] + 0.5) / 16.0 - 0.5;
	float levels = float(color_levels - 1);
	color += threshold * dither_strength / levels;

	// Posterize.
	color = clamp(floor(color * levels + 0.5) / levels, 0.0, 1.0);
	COLOR = vec4(color, 1.0);
}
