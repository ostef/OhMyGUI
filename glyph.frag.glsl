#version 460 core

// Simplified and "baked" version of the general SDF renderer for text

struct ClipBox {
    vec4 bounds;
    vec4 corner_radiuses;
};

struct Glyph {
    vec4 bounds;
    vec4 uv_bounds;
    vec2 sdf_range;
    uint color;
    uint outer_shadow_color;
    vec2 outer_shadow_offset;
    float outer_shadow_blur;
    int clip_box_index;
};

layout(binding=0, std430) readonly buffer ClipData {
    ClipBox u_clip_boxes[];
};
layout(binding=2, std430) readonly buffer GlyphData {
    Glyph u_glyphs[];
};

uniform vec2 u_viewport_size;
uniform sampler2D u_texture;

layout(location=0) in flat uint in_glyph_index;

layout(location=0) out vec4 out_color;

vec4 ColorVec4(uint rgba) {
    float r = float((rgba >> 24) & uint(0xff));
    float g = float((rgba >> 16) & uint(0xff));
    float b = float((rgba >> 8)  & uint(0xff));
    float a = float((rgba >> 0)  & uint(0xff));

    return vec4(r, g, b, a) * (1 / 255.0);
}

float FxSolidColor(float d, float blur) {
    float a = 1 - smoothstep(-blur, blur, d);
    return clamp(a, 0, 1);
}

float InverseLerp(float a, float b, float t) {
    return (t - a) / (b - a);
}

float PrimBox(vec2 p, vec2 size, vec4 corner_radiuses) {
    corner_radiuses.xy = p.x > 0.0 ? corner_radiuses.yw : corner_radiuses.xz;
    corner_radiuses.x  = p.y > 0.0 ? corner_radiuses.y  : corner_radiuses.x;
    vec2 q = abs(p) - size * 0.5 + corner_radiuses.x;

    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - corner_radiuses.x;
}

float PrimTexture(vec2 p, in sampler2D tex, vec2 size, vec4 uv_bounds, vec2 range) {
    vec2 uv = vec2(
        InverseLerp(-size.x * 0.5, size.x * 0.5, p.x),
        InverseLerp(-size.y * 0.5, size.y * 0.5, p.y)
    );
    uv = clamp(uv, 0, 1);
    uv = vec2(
        mix(uv_bounds.x, uv_bounds.z, uv.x),
        mix(uv_bounds.y, uv_bounds.w, uv.y)
    );

    return mix(range.x, range.y, texture(tex, uv).x);
}

void main() {
    vec2 p = gl_FragCoord.xy;
    p.y = u_viewport_size.y - p.y;

    Glyph glyph = u_glyphs[in_glyph_index];

    vec2 glyph_size = glyph.bounds.zw - glyph.bounds.xy;
    vec2 glyph_position = (glyph.bounds.xy + glyph.bounds.zw) * 0.5;
    vec4 foreground_color = ColorVec4(glyph.color);
    vec4 outer_shadow_color = ColorVec4(glyph.outer_shadow_color);

    float d = PrimTexture(p - glyph_position, u_texture, glyph_size, glyph.uv_bounds, glyph.sdf_range);

    float aa = length(vec2(dFdx(p.x), dFdy(p.y))) * 0.5;

    out_color = vec4(0);

    if (outer_shadow_color.a > 0) {
        float shadow_d;
        if (glyph.outer_shadow_offset != vec2(0)) {
            shadow_d = PrimTexture(p - glyph_position - glyph.outer_shadow_offset, u_texture, glyph_size, glyph.uv_bounds, glyph.sdf_range);
        } else {
            shadow_d = d;
        }

        float outer_shadow = FxSolidColor(shadow_d, aa + glyph.outer_shadow_blur);
        out_color = mix(out_color, outer_shadow_color, outer_shadow);
    }

    float foreground = FxSolidColor(d, aa);
    out_color = mix(out_color, foreground_color, foreground);

    if (glyph.clip_box_index >= 0) {
        ClipBox clip = u_clip_boxes[glyph.clip_box_index];
        vec2 clip_size = clip.bounds.zw - clip.bounds.xy;
        vec2 clip_position = (clip.bounds.xy + clip.bounds.zw) * 0.5;
        float clip_d = PrimBox(p - clip_position, clip_size, clip.corner_radiuses);
        float clip_a = FxSolidColor(clip_d, 0);

        out_color *= clip_a;
    }
}
