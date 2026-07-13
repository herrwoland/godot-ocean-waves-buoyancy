shader_type sky;
render_mode use_debanding;
/**
 * Stormy sky: a dark churning cloud deck built from warped FBM noise.
 * Two layers (high deck + faster low scud), thickness-based darkening,
 * faint sun glow, horizon haze and occasional distant lightning that
 * lights the cloud undersides.
 */

group_uniforms Clouds;
uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;
uniform float cloud_scale : hint_range(0.01, 1.0) = 0.12;
uniform float coverage : hint_range(0.0, 1.0) = 0.8;
uniform float density : hint_range(0.5, 16.0) = 7.0;
uniform float warp_strength : hint_range(0.0, 1.0) = 0.3;
uniform vec2 wind_direction = vec2(1.0, 0.35);
uniform float wind_speed : hint_range(0.0, 0.2) = 0.015;
uniform float scud_speed_mult : hint_range(1.0, 5.0) = 2.2; // low ragged clouds move faster than the deck
group_uniforms;

group_uniforms Palette;
uniform vec3 cloud_lit_color : source_color = vec3(0.30, 0.31, 0.33);
uniform vec3 cloud_dark_color : source_color = vec3(0.035, 0.04, 0.055);
uniform vec3 zenith_color : source_color = vec3(0.05, 0.06, 0.08);
uniform vec3 horizon_color : source_color = vec3(0.30, 0.31, 0.32);
uniform vec3 ground_color : source_color = vec3(0.02, 0.03, 0.04);
group_uniforms;

group_uniforms Effects;
uniform float sun_glow : hint_range(0.0, 2.0) = 0.35;
uniform float lightning_strength : hint_range(0.0, 1.0) = 0.35; // 0 disables distant lightning
uniform float exposure : hint_range(0.0, 4.0) = 1.0;
group_uniforms;

group_uniforms Sunset;
uniform vec3 sunset_color : source_color = vec3(0.9, 0.45, 0.2);
uniform float sunset_strength : hint_range(0.0, 2.0) = 1.0; // 0 disables the sunset band
uniform float sunset_spread : hint_range(1.0, 8.0) = 2.5; // higher = band hugs the sun azimuth tighter
group_uniforms;

float fbm(vec2 uv) {
	float value = 0.0;
	float amplitude = 0.55;
	for (int i = 0; i < 3; i++) {
		value += texture(noise_texture, uv).r * amplitude;
		uv = uv * 2.13 + vec2(17.3, 9.1);
		amplitude *= 0.5;
	}
	return value;
}

void sky() {
	vec3 dir = EYEDIR;
	float horizon_fade = pow(1.0 - abs(dir.y), 6.0);

	// Setting-sun band: warm light bleeding along the horizon around the sun's
	// azimuth, only when the sun actually sits low in the sky.
	float sunset = 0.0;
	vec2 dir_xz = vec2(dir.x, dir.z);
	vec2 sun_xz = vec2(LIGHT0_DIRECTION.x, LIGHT0_DIRECTION.z);
	if (sunset_strength > 0.0 && length(dir_xz) > 1e-4 && length(sun_xz) > 1e-4) {
		float azimuth = max(dot(normalize(dir_xz), normalize(sun_xz)), 0.0);
		float sun_low = smoothstep(0.45, 0.02, max(LIGHT0_DIRECTION.y, 0.0));
		sunset = sunset_strength * sun_low * horizon_fade * pow(azimuth, sunset_spread);
	}

	// --- below the horizon: dark sea haze (the water mesh covers most of it) ---
	if (dir.y <= 0.0) {
		vec3 sea_col = mix(ground_color, horizon_color, horizon_fade);
		sea_col = mix(sea_col, sunset_color, clamp(sunset, 0.0, 1.0) * 0.55);
		COLOR = sea_col * exposure;
	} else {
	// Project the view ray onto a virtual cloud plane. The +0.12 bias fakes
	// planetary curvature, compressing the clouds toward the horizon.
	vec2 base_uv = dir.xz / (dir.y + 0.12) * cloud_scale;
	vec2 wind = normalize(wind_direction) * wind_speed * TIME;

	// Domain warp makes the deck churn instead of sliding rigidly.
	vec2 warp = vec2(fbm(base_uv * 0.6 + wind * 0.5), fbm(base_uv * 0.6 - wind * 0.7)) - 0.5;
	vec2 uv = base_uv + warp * warp_strength;

	// Main high deck + faster ragged low scud layer.
	float deck = fbm(uv + wind);
	float scud = fbm(uv * 1.9 - wind * scud_speed_mult + vec2(4.7, 1.3));
	float clouds = deck * 0.7 + scud * 0.45;

	float cover = smoothstep(1.0 - coverage, 1.0 - coverage + 0.35, clouds);
	float thickness = clamp((clouds - (1.0 - coverage)) * density * 0.35, 0.0, 1.0);

	// Thin edges catch the pale light; thick cores go near-black.
	vec3 cloud_col = mix(cloud_lit_color, cloud_dark_color, thickness);

	// The sun barely pushes through as a dim smudge.
	float sun_amount = pow(max(dot(dir, LIGHT0_DIRECTION), 0.0), 24.0);
	cloud_col += LIGHT0_COLOR * sun_amount * sun_glow * (1.0 - thickness);

	// Low sun catches the thin edges and undersides of the deck near the horizon.
	cloud_col += sunset_color * sunset * (1.0 - thickness) * 0.6;

	// Distant lightning: brief random flashes from a random horizon direction,
	// reflected most by the thickest cloud undersides.
	if (lightning_strength > 0.0) {
		float cell = floor(TIME * 0.35); // one chance roughly every 3 seconds
		float rnd = fract(sin(cell * 127.1) * 43758.5453);
		float phase = fract(TIME * 0.35);
		float flash = rnd > 0.8 ? exp(-40.0 * phase) + 0.6 * exp(-40.0 * abs(phase - 0.12)) : 0.0;
		float light_dir = rnd * 6.2831;
		float facing = 0.5 + 0.5 * dot(normalize(dir.xz), vec2(cos(light_dir), sin(light_dir)));
		cloud_col += vec3(0.7, 0.75, 0.9) * flash * lightning_strength * facing * thickness;
	}

	// Rare gaps in the deck show a joyless zenith, and horizon haze flattens it all.
	vec3 sky_col = mix(zenith_color, horizon_color, horizon_fade);
	vec3 col = mix(sky_col, cloud_col, cover);
	col = mix(col, horizon_color, horizon_fade * 0.85);

	// The sunset band burns through the haze itself.
	col = mix(col, sunset_color, clamp(sunset, 0.0, 1.0) * 0.7);

	COLOR = col * exposure;
	}
}
