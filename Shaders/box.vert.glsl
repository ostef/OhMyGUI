layout(std430) readonly buffer BoxData {
    Box u_boxes[];
};

uniform int u_base_instance;
uniform vec2 u_viewport_size;

layout(location=0) out flat uint out_box_index;

void main() {
    out_box_index = gl_InstanceID + gl_BaseInstance;
    Box box = u_boxes[out_box_index];

    vec2 position = box.size_and_position.zw;
    vec2 size = box.size_and_position.xy;
    vec4 bounds = vec4(position - size * 0.5, position + size * 0.5);

    // Inflate bounds so we can draw the border
    bounds.xy -= max(-box.border_size_and_inset.y, 0);
    bounds.zw += max(-box.border_size_and_inset.y, 0);

    vec2 p0 = bounds.xy - position;
    vec2 p1 = bounds.zy - position;
    vec2 p2 = bounds.zw - position;
    vec2 p3 = bounds.xw - position;

    float c = cos(box.rotation);
    float s = sin(box.rotation);
    p0 = position + vec2(p0.x * c - p0.y * s, p0.x * s + p0.y * c);
    p1 = position + vec2(p1.x * c - p1.y * s, p1.x * s + p1.y * c);
    p2 = position + vec2(p2.x * c - p2.y * s, p2.x * s + p2.y * c);
    p3 = position + vec2(p3.x * c - p3.y * s, p3.x * s + p3.y * c);

    // Inflate rect so we can draw the outer shadow
    p0 -= max(box.outer_shadow_blur, 0);
    p1 += vec2(max(box.outer_shadow_blur, 0), -max(box.outer_shadow_blur, 0));
    p2 += max(box.outer_shadow_blur, 0);
    p3 += vec2(-max(box.outer_shadow_blur, 0), max(box.outer_shadow_blur, 0));

    p0 = min(p0, p0 + box.outer_shadow_offset);
    p1 = vec2(max(p1.x, p1.x + box.outer_shadow_offset.x), min(p1.y, p1.y + box.outer_shadow_offset.y));
    p2 = max(p2, p2 + box.outer_shadow_offset);
    p3 = vec2(min(p3.x, p3.x + box.outer_shadow_offset.x), max(p3.y, p3.y + box.outer_shadow_offset.y));

    const vec2 positions[] = vec2[](
        p0, p1, p2,
        p0, p2, p3
    );

    gl_Position.xy = (positions[gl_VertexID] / u_viewport_size) * 2 - vec2(1);
    gl_Position.y *= -1;
    gl_Position.z = 0;
    gl_Position.w = 1;
}
