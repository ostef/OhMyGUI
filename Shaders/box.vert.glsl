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

    // Inflate bounds so we can draw the outer shadow
    bounds.xy -= max(box.outer_shadow_blur, 0);
    bounds.zw += max(box.outer_shadow_blur, 0);
    bounds.xy = min(bounds.xy, bounds.xy + box.outer_shadow_offset);
    bounds.zw = max(bounds.zw, bounds.zw + box.outer_shadow_offset);

    const vec2 positions[] = vec2[](
        vec2(bounds.z, bounds.w), vec2(bounds.x, bounds.w), vec2(bounds.x, bounds.y),
        vec2(bounds.z, bounds.w), vec2(bounds.x, bounds.y), vec2(bounds.z, bounds.y)
    );

    gl_Position.xy = (positions[gl_VertexID] / u_viewport_size) * 2 - vec2(1);
    gl_Position.y *= -1;
    gl_Position.z = 0;
    gl_Position.w = 1;
}
