#version 460 core

uniform sampler2D u_texture;

layout(location=0) in vec2 in_uv;
layout(location=1) in vec4 in_uvs;

layout(location=0) out vec4 out_color;

void main() {
    float d = -(texture(u_texture, in_uv).x - 0.5);
    float aa = length(vec2(dFdx(d), dFdy(d)));
    float a = 1 - smoothstep(-aa, aa, d);
    a = clamp(a, 0, 1);

    out_color = vec4(0,0,0,a);
}
