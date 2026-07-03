layout(std430) readonly buffer ShapeDrawingData {
    ShapeDrawing u_shape_drawings[];
};

uniform int u_base_instance;
uniform vec2 u_viewport_size;

layout(location=0) out flat uint out_shape_drawing_index;

void main() {
    out_shape_drawing_index = gl_InstanceID + gl_BaseInstance;
    ShapeDrawing drawing = u_shape_drawings[out_shape_drawing_index];

    vec4 bounds = drawing.bounds;

    // Inflate bounds so we can draw the border
    bounds.xy -= max(-drawing.border_size_and_inset.y, 0);
    bounds.zw += max(-drawing.border_size_and_inset.y, 0);

    // Inflate bounds so we can draw the outer shadow
    bounds.xy -= max(drawing.outer_shadow_blur, 0);
    bounds.zw += max(drawing.outer_shadow_blur, 0);
    bounds.xy = min(bounds.xy, bounds.xy + drawing.outer_shadow_offset);
    bounds.zw = max(bounds.zw, bounds.zw + drawing.outer_shadow_offset);

    const vec2 positions[] = vec2[](
        vec2(bounds.z, bounds.w), vec2(bounds.x, bounds.w), vec2(bounds.x, bounds.y),
        vec2(bounds.z, bounds.w), vec2(bounds.x, bounds.y), vec2(bounds.z, bounds.y)
    );

    gl_Position.xy = ((positions[gl_VertexID] + drawing.position) / u_viewport_size) * 2 - vec2(1);
    gl_Position.y *= -1;
    gl_Position.z = 0;
    gl_Position.w = 1;
}
