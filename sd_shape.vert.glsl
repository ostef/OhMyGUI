#version 460 core

struct Instance {
    vec4 bounds;
    vec2 position;
    uint first_shape_index;
    uint num_shapes;
    uint first_effect_index;
    uint num_effects;
};

layout(binding=0, std430) readonly buffer InstanceData {
    Instance u_instances[];
};
uniform vec2 u_viewport_size;

layout(location=0) out vec2 out_position;
layout(location=1) out flat uint out_first_shape_index;
layout(location=2) out flat uint out_num_shapes;
layout(location=3) out flat uint out_first_effect_index;
layout(location=4) out flat uint out_num_effects;

void main() {
    Instance inst = u_instances[gl_InstanceID];
    out_position = inst.position;
    out_first_shape_index = inst.first_shape_index;
    out_num_shapes = inst.num_shapes;
    out_first_effect_index = inst.first_effect_index;
    out_num_effects = inst.num_effects;

    const vec2 positions[] = vec2[](
        vec2(inst.bounds.z, inst.bounds.w), vec2(inst.bounds.x, inst.bounds.w), vec2(inst.bounds.x, inst.bounds.y),
        vec2(inst.bounds.z, inst.bounds.w), vec2(inst.bounds.x, inst.bounds.y), vec2(inst.bounds.z, inst.bounds.y)
    );

    gl_Position.xy = ((positions[gl_VertexID] + inst.position) / u_viewport_size) * 2 - vec2(1);
    gl_Position.y *= -1;
    gl_Position.z = 0;
    gl_Position.w = 1;
}
