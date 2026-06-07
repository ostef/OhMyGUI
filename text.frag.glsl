#version 460 core

uniform vec2 u_font_sdf_range;
uniform sampler2D u_font_texture;

layout(location=0) in in_tex_coords;

layout(location=0) out out_color;

void main() {
    float d = texture(u_font_texture, in_tex_coords).x;
    d = mix(u_font_sdf_range.x, u_font_sdf_range.y, d);
}
