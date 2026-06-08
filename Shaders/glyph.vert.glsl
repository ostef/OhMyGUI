layout(binding=2, std430) readonly buffer GlyphData {
    Glyph u_glyphs[];
};

uniform vec2 u_viewport_size;

layout(location=0) out flat uint out_glyph_index;

void main() {
    out_glyph_index = gl_InstanceID + gl_BaseInstance;
    Glyph glyph = u_glyphs[out_glyph_index];

    vec4 bounds = glyph.bounds;

    // Inflate bounds so we can draw the outer shadow
    bounds.xy -= max(glyph.outer_shadow_blur, 0);
    bounds.zw += max(glyph.outer_shadow_blur, 0);
    bounds.xy = min(bounds.xy, bounds.xy + glyph.outer_shadow_offset);
    bounds.zw = min(bounds.zw, bounds.zw + glyph.outer_shadow_offset);

    const vec2 positions[] = vec2[](
        vec2(bounds.z, bounds.w), vec2(bounds.x, bounds.w), vec2(bounds.x, bounds.y),
        vec2(bounds.z, bounds.w), vec2(bounds.x, bounds.y), vec2(bounds.z, bounds.y)
    );

    gl_Position.xy = (positions[gl_VertexID] / u_viewport_size) * 2 - vec2(1);
    gl_Position.y *= -1;
    gl_Position.z = 0;
    gl_Position.w = 1;
}

