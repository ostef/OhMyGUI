#version 460 core

struct Glyph {
    vec4 bounds;
    vec4 uvs;
};

layout(binding=0, std430) readonly buffer Glyphs {
    Glyph u_glyphs[];
};
uniform vec2 u_viewport_size;

layout(location=0) out vec2 out_uv;
layout(location=1) out vec4 out_uvs;

void main() {
    Glyph glyph = u_glyphs[gl_InstanceID];

    const vec2 positions[] = vec2[](
        vec2(glyph.bounds.z, glyph.bounds.w), vec2(glyph.bounds.x, glyph.bounds.w), vec2(glyph.bounds.x, glyph.bounds.y),
        vec2(glyph.bounds.z, glyph.bounds.w), vec2(glyph.bounds.x, glyph.bounds.y), vec2(glyph.bounds.z, glyph.bounds.y)
    );

    gl_Position.xy = (positions[gl_VertexID] / u_viewport_size) * 2 - vec2(1);
    gl_Position.y *= -1;
    gl_Position.z = 0;
    gl_Position.w = 1;

    const vec2 uvs[] = vec2[](
        vec2(glyph.uvs.z, glyph.uvs.w), vec2(glyph.uvs.x, glyph.uvs.w), vec2(glyph.uvs.x, glyph.uvs.y),
        vec2(glyph.uvs.z, glyph.uvs.w), vec2(glyph.uvs.x, glyph.uvs.y), vec2(glyph.uvs.z, glyph.uvs.y)
    );

    out_uv = uvs[gl_VertexID];
    out_uvs = glyph.uvs;
}
