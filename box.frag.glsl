#version 460 core

// Simplified and "baked" version of the general SDF renderer for node boxes

struct ClipBox {
    vec4 bounds;
    vec4 corner_radiuses;
};

struct Box {
    vec4 size_and_position;
    vec4 corner_radiuses;
    int clip_box_index;
    uint background_color;
    vec2 border_size_and_inset;
    uint border_color;
    uint outer_shadow_color;
    vec2 outer_shadow_offset;
    float outer_shadow_blur;
};

layout(binding=0, std430) readonly buffer ClipData {
    ClipBox u_clip_boxes[];
};
layout(binding=1, std430) readonly buffer BoxData {
    Box u_boxes[];
};

uniform vec2 u_viewport_size;

layout(location=0) in flat uint in_box_index;

layout(location=0) out vec4 out_color;

vec4 ColorVec4(uint rgba) {
    float r = float((rgba >> 24) & uint(0xff));
    float g = float((rgba >> 16) & uint(0xff));
    float b = float((rgba >> 8)  & uint(0xff));
    float a = float((rgba >> 0)  & uint(0xff));

    return vec4(r, g, b, a) * (1 / 255.0);
}

float PrimBox(vec2 p, vec2 size, vec4 corner_radiuses) {
    corner_radiuses.xy = p.x > 0.0 ? corner_radiuses.yw : corner_radiuses.xz;
    corner_radiuses.x  = p.y > 0.0 ? corner_radiuses.y  : corner_radiuses.x;
    vec2 q = abs(p) - size * 0.5 + corner_radiuses.x;

    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - corner_radiuses.x;
}

float FxSolidColor(float d, float blur) {
    float a = 1 - smoothstep(-blur, blur, d);
    return clamp(a, 0, 1);
}

float FxStrokeColor(float d, float blur, float size, float inset) {
    float a = FxSolidColor(-(d + inset + size), blur) * FxSolidColor(d + inset, blur);
    return clamp(a, 0, 1);
}

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

    float d = PrimBox(p - box_position, box_size, box_corner_radiuses);

    out_color = vec4(0);

    if (outer_shadow_color.a > 0) {
        float shadow_d;
        if (outer_shadow_offset != vec2(0)) {
            shadow_d = PrimBox(p - box_position - outer_shadow_offset, box_size, box_corner_radiuses);
        } else {
            shadow_d = d;
        }

        float outer_shadow = FxSolidColor(shadow_d, aa + outer_shadow_blur);
        out_color = mix(out_color, outer_shadow_color, outer_shadow);
    }

    float background = FxSolidColor(d, aa);
    out_color = mix(out_color, background_color, background);

    float border = FxStrokeColor(d, aa, border_size, border_inset);
    out_color = mix(out_color, border_color, border);

    if (box.clip_box_index >= 0) {
        ClipBox clip = u_clip_boxes[box.clip_box_index];
        vec2 clip_size = clip.bounds.zw - clip.bounds.xy;
        vec2 clip_position = (clip.bounds.xy + clip.bounds.zw) * 0.5;
        float clip_d = PrimBox(p - clip_position, clip_size, clip.corner_radiuses);
        float clip_a = FxSolidColor(clip_d, aa);

        out_color *= clip_a;
    }
}
