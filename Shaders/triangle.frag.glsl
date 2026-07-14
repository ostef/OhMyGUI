layout(std430) readonly buffer ClipBoxData {
    ClipBox u_clip_boxes[];
};
layout(std430) readonly buffer TriangleData {
    Triangle u_triangles[];
};

uniform vec2 u_viewport_size;
uniform sampler2D u_texture;

layout(location=0) in flat uint in_triangle_index;
layout(location=1) in vec2 in_uv;
layout(location=2) in vec4 in_color;

layout(location=0) out vec4 out_color;

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

    vec4 image_color = texture(u_texture, in_uv);

    float background = 1; //FxSolidColorWithAA(d, aa);
    out_color = BlendEffect(out_color, image_color * in_color, background);

    if (triangle.clip_box_index >= 0) {
        ClipBox clip = u_clip_boxes[triangle.clip_box_index];
        out_color *= SampleClipBox(clip, p, aa);
    }
}
