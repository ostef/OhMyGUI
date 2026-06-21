#version 460 core

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

struct Triangle {
    vec2 p0;
    vec2 p1;
    vec2 p2;
    uint c0;
    uint c1;
    uint c2;
    int clip_box_index;
};

struct ShapeDrawing {
    vec4 bounds;
    vec2 position;
    uint first_shape_index;
    uint num_shapes;
    int clip_box_index;
    uint background_color;
    vec2 border_size_and_inset;
    uint border_color;
    uint outer_shadow_color;
    vec2 outer_shadow_offset;
    float outer_shadow_blur;
};

vec4 ColorVec4(uint rgba) {
    float r = float((rgba >> 24) & uint(0xff));
    float g = float((rgba >> 16) & uint(0xff));
    float b = float((rgba >> 8)  & uint(0xff));
    float a = float((rgba >> 0)  & uint(0xff));

    return vec4(r, g, b, a) * (1 / 255.0);
}

float InverseLerp(float a, float b, float t) {
    return (t - a) / (b - a);
}

float PrimCircle(vec2 p, float radius) {
    return length(p) - radius;
}

float PrimBox(vec2 p, vec2 size, vec4 corner_radiuses) {
    corner_radiuses.xy = p.x > 0.0 ? corner_radiuses.yw : corner_radiuses.xz;
    corner_radiuses.x  = p.y > 0.0 ? corner_radiuses.y  : corner_radiuses.x;
    vec2 q = abs(p) - size * 0.5 + corner_radiuses.x;

    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - corner_radiuses.x;
}

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

float OpUnion(float a, float b) {
    return min(a, b);
}

// https://iquilezles.org/articles/smin/
// Quadratic polynomial smooth union
float OpSmoothUnion(float a, float b, float k) {
    if (abs(k) < 0.00001) {
        return min(a, b);
    }

    k *= 4.0;
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * (1.0 / 4.0);
}

float OpIntersection(float a, float b) {
    return max(a, b);
}

float OpSmoothIntersection(float a, float b, float k) {
    return -OpSmoothUnion(-a, -b, k);
}

float OpSubtraction(float a, float b) {
    return max(a, -b);
}

float OpSmoothSubtraction(float a, float b, float k) {
    return -OpSmoothUnion(-a, b, k);
}

float OpRound(float a, float radius) {
    return a - radius;
}

float OpOnion(float a, float radius) {
    return abs(a) - radius;
}

float FxSolidColor(float d, float blur) {
    float a = 1 - smoothstep(-blur, blur, d);
    return clamp(a, 0, 1);
}

float FxStrokeColor(float d, float blur, float size, float inset) {
    float a = FxSolidColor(-(d + inset + size), blur) * FxSolidColor(d + inset, blur);
    return clamp(a, 0, 1);
}

vec4 BlendEffect(vec4 a, vec4 b, float alpha) {
    return mix(a, vec4(b.rgb, 1), b.a * alpha);
}

float SampleClipBox(ClipBox clip, vec2 p, float aa) {
    vec2 clip_size = clip.bounds.zw - clip.bounds.xy;
    vec2 clip_position = (clip.bounds.xy + clip.bounds.zw) * 0.5;
    float clip_d = PrimBox(p - clip_position, clip_size, clip.corner_radiuses);
    return FxSolidColor(clip_d, aa);
}

