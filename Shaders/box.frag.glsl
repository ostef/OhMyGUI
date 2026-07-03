// Simplified and "baked" version of the general SDF renderer for node boxes

layout(std430) readonly buffer ClipBoxData {
    ClipBox u_clip_boxes[];
};
layout(std430) readonly buffer BoxData {
    Box u_boxes[];
};

uniform vec2 u_viewport_size;

layout(location=0) in flat uint in_box_index;

layout(location=0) out vec4 out_color;

void main() {
    vec2 p = gl_FragCoord.xy;
    p.y = u_viewport_size.y - p.y;

    float aa = length(vec2(dFdx(p.x), dFdy(p.y))) * 0.5;

    Box box = u_boxes[in_box_index];

    vec2 box_size = box.size_and_position.xy;
    vec2 box_position = box.size_and_position.zw;
    vec4 box_corner_radiuses = box.corner_radiuses;
    float border_size = box.border_size_and_inset.x;
    float border_inset = box.border_size_and_inset.y;
    vec4 background_color = ColorVec4(box.background_color);
    vec4 border_color = ColorVec4(box.border_color);
    vec4 outer_shadow_color = ColorVec4(box.outer_shadow_color);
    vec2 outer_shadow_offset = box.outer_shadow_offset;
    float outer_shadow_blur = box.outer_shadow_blur;
    vec4 inner_shadow_color = ColorVec4(box.inner_shadow_color);
    vec2 inner_shadow_offset = box.inner_shadow_offset;
    float inner_shadow_blur = box.inner_shadow_blur;

    float d = PrimBox(p - box_position, box_size, box_corner_radiuses);

    out_color = vec4(0);

    if (outer_shadow_color.a > 0) {
        float shadow_d;
        if (outer_shadow_offset != vec2(0)) {
            shadow_d = PrimBox(p - box_position - outer_shadow_offset, box_size, box_corner_radiuses);
        } else {
            shadow_d = d;
        }

        float outer_shadow = FxOuterShadow(shadow_d, aa + outer_shadow_blur, background_color.a, border_color.a, border_size, border_inset);
        out_color = BlendEffect(out_color, outer_shadow_color, outer_shadow);
    }

    float background = FxSolidColor(d, aa);
    out_color = BlendEffect(out_color, background_color, background);

    if (inner_shadow_color.a > 0) {
        float shadow_d;
        if (inner_shadow_offset != vec2(0)) {
            shadow_d = PrimBox(p - box_position - inner_shadow_offset, box_size, box_corner_radiuses);
        } else {
            shadow_d = d;
        }

        float inner_shadow = FxInnerShadow(shadow_d, aa + inner_shadow_blur, background);
        out_color = BlendEffect(out_color, inner_shadow_color, inner_shadow);
    }

    float border = FxStrokeColor(d, aa, border_size, border_inset);
    out_color = BlendEffect(out_color, border_color, border);

    if (box.clip_box_index >= 0) {
        ClipBox clip = u_clip_boxes[box.clip_box_index];
        out_color *= SampleClipBox(clip, p, aa);
    }
}
