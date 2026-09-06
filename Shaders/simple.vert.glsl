#version 330 core

layout(location=0) in vec2 v_position;
layout(location=1) in vec2 v_tex_coords;
layout(location=2) in vec4 v_color;
layout(location=3) in float v_sdf_texture_blur;
layout(location=4) in float v_sdf_texture_range;
layout(location=5) in int v_clip_box_index;

uniform vec2 u_viewport_size;

out vec2 position;
out vec2 tex_coords;
out vec4 color;
flat out int clip_box_index;
out float sdf_texture_blur;
out float sdf_texture_range;

void main() {
    gl_Position.xy = (v_position / u_viewport_size) * 2 - vec2(1);
    gl_Position.y *= -1;
    gl_Position.z = 0;
    gl_Position.w = 1;

    position = v_position;
    tex_coords = v_tex_coords;
    color = v_color.abgr;
    clip_box_index = v_clip_box_index;
    sdf_texture_blur = v_sdf_texture_blur;
    sdf_texture_range = v_sdf_texture_range;
}
