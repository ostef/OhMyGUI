#version 430 core

layout(std430) readonly buffer ClipBoxData {
    vec4 u_clip_boxes[];
};

uniform vec2 u_viewport_size;
uniform sampler2D u_texture;

in vec2 position;
in vec2 tex_coords;
in vec4 color;
flat in int clip_box_index;
in float sdf_texture_blur;
in float sdf_texture_range;

out vec4 out_color;

float FxSolidColor(float d, float blur) {
    float a = 1 - smoothstep(-blur, blur, d);
    return clamp(a, 0, 1);
}

float FxStrokeColor(float d, float blur, float size, float inset) {
    float a = FxSolidColor(-(d + inset + size), blur) * FxSolidColor(d + inset, blur);
    return clamp(a, 0, 1);
}

float BoxSDF(vec2 p, vec4 bounds) {
    vec2 size = bounds.zw - bounds.xy;
    vec2 position = (bounds.xy + bounds.zw) * 0.5;

    vec2 q = abs(p - position) - size * 0.5;

    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0));
}

void main() {
    vec2 p = gl_FragCoord.xy;
    p.y = u_viewport_size.y - p.y;

    float aa = length(vec2(dFdx(p.x), dFdy(p.y))) * 0.5;

    vec4 sampled = texture(u_texture, tex_coords);

    if (sdf_texture_blur < 1.0f) {
        out_color = color * sampled;
    } else {
        float blur = max(sdf_texture_blur - 1.0f, 0.0f);
        float d = mix(sdf_texture_range, -sdf_texture_range, sampled.r);
        float a = FxSolidColor(d, aa + blur);
        out_color = color;
        out_color.a = a;
    }

    if (clip_box_index >= 0) {
        vec4 clip = u_clip_boxes[clip_box_index];
        float d = BoxSDF(p, clip);

        float a = FxSolidColor(d, aa);

        out_color.a *= a;
    }
}
