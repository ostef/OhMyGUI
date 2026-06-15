layout(binding=4, std430) readonly buffer DrawingData {
    ShapeDrawing u_shape_drawings[];
};
uniform vec2 u_viewport_size;

layout(location=0) out flat uint out_shape_drawing_index;

void main() {
    out_shape_drawing_index = gl_InstanceID + gl_BaseInstance;
    ShapeDrawing drawing = u_shape_drawings[out_shape_drawing_index];

    const vec2 positions[] = vec2[](
        vec2(drawing.bounds.z, drawing.bounds.w), vec2(drawing.bounds.x, drawing.bounds.w), vec2(drawing.bounds.x, drawing.bounds.y),
        vec2(drawing.bounds.z, drawing.bounds.w), vec2(drawing.bounds.x, drawing.bounds.y), vec2(drawing.bounds.z, drawing.bounds.y)
    );

    gl_Position.xy = ((positions[gl_VertexID] + drawing.position) / u_viewport_size) * 2 - vec2(1);
    gl_Position.y *= -1;
    gl_Position.z = 0;
    gl_Position.w = 1;
}
