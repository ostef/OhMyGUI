#version 460 core

struct Triangle {
    vec2 p0;
    vec2 p1;
    vec2 p2;
    uint c0;
    uint c1;
    uint c2;
    int clip_box_index;
};

layout(binding=3, std430) readonly buffer TriangleData {
    Triangle u_triangles[];
};

uniform vec2 u_viewport_size;

layout(location=0) out flat uint out_triangle_index;
layout(location=1) out vec4 out_color;

vec4 ColorVec4(uint rgba) {
    float r = float((rgba >> 24) & uint(0xff));
    float g = float((rgba >> 16) & uint(0xff));
    float b = float((rgba >> 8)  & uint(0xff));
    float a = float((rgba >> 0)  & uint(0xff));

    return vec4(r, g, b, a) * (1 / 255.0);
}

void main() {
    out_triangle_index = gl_InstanceID + gl_BaseInstance;
    Triangle triangle = u_triangles[out_triangle_index];

    // Expand the triangle because we want AA to be on the outside, since we often
    // stick triangles next to each other.
    // We probably should do the same with other primitive types
    vec2 center = (triangle.p0 + triangle.p1 + triangle.p2) / 3;
    vec2 center_p0 = normalize(center - triangle.p0) * 3;
    vec2 center_p1 = normalize(center - triangle.p1) * 3;
    vec2 center_p2 = normalize(center - triangle.p2) * 3;

    const vec2 positions[] = vec2[](
        triangle.p0 - center_p0, triangle.p1 - center_p1, triangle.p2 - center_p2
    );

    gl_Position.xy = (positions[gl_VertexID] / u_viewport_size) * 2 - vec2(1);
    gl_Position.y *= -1;
    gl_Position.z = 0;
    gl_Position.w = 1;

    const uint colors[] = uint[](
        triangle.c0, triangle.c1, triangle.c2
    );

    out_color = ColorVec4(colors[gl_VertexID]);
}
