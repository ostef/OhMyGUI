// Simplified and "baked" version of the general SDF renderer for text

layout(std430) readonly buffer ClipBoxData {
    ClipBox u_clip_boxes[];
};
layout(std430) readonly buffer GlyphData {
    Glyph u_glyphs[];
};

uniform vec2 u_viewport_size;
uniform sampler2D u_texture;

layout(location=0) in flat uint in_glyph_index;

layout(location=0) out vec4 out_color;

void main() {
    vec2 p = gl_FragCoord.xy;
    p.y = u_viewport_size.y - p.y;

    Glyph glyph = u_glyphs[in_glyph_index];

    vec2 glyph_size = glyph.bounds.zw - glyph.bounds.xy;
    vec2 glyph_position = (glyph.bounds.xy + glyph.bounds.zw) * 0.5;
    vec4 foreground_color = ColorVec4(glyph.color);
    vec4 foreground_color2 = ColorVec4(glyph.color2);
    vec4 outer_shadow_color = ColorVec4(glyph.outer_shadow_color);
    vec4 inner_shadow_color = ColorVec4(glyph.inner_shadow_color);

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
        out_color = BlendEffect(out_color, outer_shadow_color, outer_shadow);
    }

    float foreground = FxSolidColor(d, aa);
    foreground_color = FxGradientColorInBox(p, glyph_position, glyph_size, glyph.gradient_offset, glyph.gradient_vector, foreground_color, foreground_color2);

    out_color = BlendEffect(out_color, foreground_color, foreground);

    if (inner_shadow_color.a > 0) {
        float shadow_d;
        if (glyph.inner_shadow_offset != vec2(0)) {
            shadow_d = PrimTexture(p - glyph_position - glyph.inner_shadow_offset, u_texture, glyph_size, glyph.uv_bounds, glyph.sdf_range);
        } else {
            shadow_d = d;
        }

        float inner_shadow = FxInnerShadow(shadow_d, aa + glyph.inner_shadow_blur, foreground);
        out_color = BlendEffect(out_color, inner_shadow_color, inner_shadow);
    }

    if (glyph.clip_box_index >= 0) {
        ClipBox clip = u_clip_boxes[glyph.clip_box_index];
        out_color *= SampleClipBox(clip, p, aa);
    }
}
