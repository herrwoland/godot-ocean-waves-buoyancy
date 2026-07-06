shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled;
/**
 * Opaque stand-in for the (transparent) water surface, rendered only on the
 * rain heightfield's visual layer. GPUParticlesCollisionHeightField3D ignores
 * transparent materials, so rain would fall straight through the real water.
 * This mesh follows the same displacement maps so raindrops collide with the
 * actual wave shape.
 */

#define MAX_CASCADES 8

uniform vec4 map_scales[MAX_CASCADES]; // Packed: [uv scale, displacement scale, normal scale]
global uniform uint num_cascades;
global uniform sampler2DArray displacements;

void vertex() {
	vec2 uv = VERTEX.xz;
	vec3 displacement = vec3(0);
	for (uint i = 0U; i < num_cascades; ++i) {
		vec4 scales = map_scales[i];
		displacement += texture(displacements, vec3(uv*scales.xy, float(i))).xyz * scales.z;
	}
	VERTEX += displacement;
}

void fragment() {
	ALBEDO = vec3(0.0);
}
