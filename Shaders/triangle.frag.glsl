#version 460 core

struct ClipBox {
    vec4 bounds;
    vec4 corner_radiuses;
};

struct Triangle {
    vec2 p0;
    vec2 p1;
    vec2 p2;
    uint c0;
    uint c1;
    uint c2;
    int clip_box_index;
};

layout(binding=0, std430) readonly buffer ClipData {
    ClipBox u_clip_boxes[];
};
layout(binding=3, std430) readonly buffer TriangleData {
    Triangle u_triangles[];
};

uniform vec2 u_viewport_size;

layout(location=0) in flat uint in_triangle_index;
layout(location=1) in vec4 in_color;

layout(location=0) out vec4 out_color;

float PrimTriangle(vec2 p, vec2 p0, vec2 p1, vec2 p2) {
    vec2 e0 = p1 - p0;
    vec2 e1 = p2 - p1;
    vec2 e2 = p0 - p2;
    vec2 v0 = p - p0;
    vec2 v1 = p - p1;
    vec2 v2 = p - p2;

    vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
    vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
    vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);

    float s = sign(e0.x * e2.y - e0.y * e2.x);
    vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
                     vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
                     vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));

    return -sqrt(d.x) * sign(d.y);
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

// Do not use blur for anti aliasing, for triangles it is important that AA is on
// the outside of the shape
float FxSolidColorWithAA(float d, float aa) {
    float a = 1 - smoothstep(0, 2 * aa, d);
    return clamp(a, 0, 1);
}

void main() {
    vec2 p = gl_FragCoord.xy;
    p.y = u_viewport_size.y - p.y;

    float aa = length(vec2(dFdx(p.x), dFdy(p.y))) * 0.5;

    Triangle triangle = u_triangles[in_triangle_index];

    float d = PrimTriangle(p, triangle.p0, triangle.p1, triangle.p2);

    out_color = vec4(0);

    float background = FxSolidColorWithAA(d, aa);
    out_color = mix(out_color, in_color, background);

    if (triangle.clip_box_index >= 0) {
        ClipBox clip = u_clip_boxes[triangle.clip_box_index];
        vec2 clip_size = clip.bounds.zw - clip.bounds.xy;
        vec2 clip_position = (clip.bounds.xy + clip.bounds.zw) * 0.5;
        float clip_d = PrimBox(p - clip_position, clip_size, clip.corner_radiuses);
        float clip_a = FxSolidColor(clip_d, aa);

        out_color *= clip_a;
    }
}
