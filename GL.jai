#import "OhMyGUI";
#import "GL";
#import "Basic";
#import "String";

GetRendererFuncs :: inline () -> RendererFunctions {
    return .{
        CreateR8Texture=CreateR8Texture,
        CreateRGBA8Texture=CreateRGBA8Texture,
        DestroyTexture=DestroyTexture,
    };
}

#scope_module

g_white_texture : GLuint;

Shader :: struct {
    handle : GLuint;
    u_base_instance : GLint;
    u_viewport_size : GLint;
}

g_shader : Shader;

g_vao : GLuint;

g_clip_boxes_buffer : GLuint;
g_vertices_buffer : GLuint;
g_indices_buffer : GLuint;

LoadShader :: (name : string, vertex_source : string, fragment_source : string) -> Shader {
    status, log_length : GLint;

    vertex_shader := glCreateShader(GL_VERTEX_SHADER);
    defer glDeleteShader(vertex_shader);

    fragment_shader := glCreateShader(GL_FRAGMENT_SHADER);
    defer glDeleteShader(fragment_shader);

    vertex_name := tprint("Vertex Shader '%'", name);
    glObjectLabel(GL_SHADER, vertex_shader, xx vertex_name.count, vertex_name.data);

    fragment_name := tprint("Fragment Shader '%'", name);
    glObjectLabel(GL_SHADER, fragment_shader, xx fragment_name.count, fragment_name.data);

    vertex_length := cast(s32, vertex_source.count);
    glShaderSource(vertex_shader, 1, *vertex_source.data, *vertex_length);
    glCompileShader(vertex_shader);

    glGetShaderiv(vertex_shader, GL_COMPILE_STATUS, *status);
    glGetShaderiv(vertex_shader, GL_INFO_LOG_LENGTH, *log_length);
    if !status {
        log : *u8 = alloc(log_length + 1 ,, temp);
        glGetShaderInfoLog(vertex_shader, xx log_length, null, log);

        message := string.{log_length, log};

        log_error("Could not compile vertex shader '%': %", name, message);

        return .{};
    }

    fragment_length := cast(s32, fragment_source.count);
    glShaderSource(fragment_shader, 1, *fragment_source.data, *fragment_length);
    glCompileShader(fragment_shader);

    glGetShaderiv(fragment_shader, GL_COMPILE_STATUS, *status);
    glGetShaderiv(fragment_shader, GL_INFO_LOG_LENGTH, *log_length);
    if !status {
        log : *u8 = alloc(log_length + 1 ,, temp);
        glGetShaderInfoLog(fragment_shader, xx log_length, null, log);

        message := string.{log_length, log};

        log_error("Could not compile fragment shader '%': %", name, message);

        return .{};
    }

    program := glCreateProgram();

    program_name := tprint("Shader Program '%'", name);
    glObjectLabel(GL_PROGRAM, program, xx program_name.count, program_name.data);

    glAttachShader(program, vertex_shader);
    defer glDetachShader(program, vertex_shader);

    glAttachShader(program, fragment_shader);
    defer glDetachShader(program, fragment_shader);

    glLinkProgram(program);

    glGetProgramiv(program, GL_LINK_STATUS, *status);
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, *log_length);
    if !status {
        log : *u8 = alloc(log_length + 1 ,, temp);
        glGetProgramInfoLog(program, xx log_length, null, log);

        message := string.{log_length, log};

        log_error("Could not compile shader '%': %", name, message);

        return .{};
    }

    // Setup binding indices
    result : Shader;
    result.handle = program;
    result.u_base_instance = glGetUniformLocation(program, "u_base_instance");
    result.u_viewport_size = glGetUniformLocation(program, "u_viewport_size");

    clip_boxes_index := glGetProgramResourceIndex(program, GL_SHADER_STORAGE_BLOCK, "ClipBoxData");
    if clip_boxes_index != GL_INVALID_INDEX {
        glShaderStorageBlockBinding(program, clip_boxes_index, 0);
    }

    return result;
}

Vertex_Shader :: #string GLSL
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
GLSL

Fragment_Shader :: #string GLSL
#version 430 core

struct ClipBox {
    vec4 bounds;
    vec4 corner_radiuses;
};

layout(std430) readonly buffer ClipBoxData {
    ClipBox u_clip_boxes[];
};

uniform vec2 u_viewport_size;
uniform sampler2D u_texture;

in vec2 position;
in vec2 tex_coords;
in vec4 color;
flat in int clip_box_index;
in float sdf_texture_blur;
in float sdf_texture_range;

out vec4 out_color;

float FxSolidColor(float d, float blur) {
    float a = 1 - smoothstep(-blur, blur, d);
    return clamp(a, 0, 1);
}

float FxStrokeColor(float d, float blur, float size, float inset) {
    float a = FxSolidColor(-(d + inset + size), blur) * FxSolidColor(d + inset, blur);
    return clamp(a, 0, 1);
}

float PrimBox(vec2 p, vec2 size, vec4 corner_radiuses) {
    corner_radiuses.xy = p.x > 0.0 ? corner_radiuses.yw : corner_radiuses.xz;
    corner_radiuses.x  = p.y > 0.0 ? corner_radiuses.y  : corner_radiuses.x;
    vec2 q = abs(p) - size * 0.5 + corner_radiuses.x;

    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - corner_radiuses.x;
}

void main() {
    vec2 p = gl_FragCoord.xy;
    p.y = u_viewport_size.y - p.y;

    float aa = length(vec2(dFdx(p.x), dFdy(p.y))) * 0.5;

    vec4 sampled = texture(u_texture, tex_coords);

    if (sdf_texture_blur < 1.0f) {
        out_color = color * sampled;
    } else {
        float blur = max(sdf_texture_blur - 1.0f, 0.0f);
        float d = mix(sdf_texture_range, -sdf_texture_range, sampled.r);
        float a = FxSolidColor(d, aa + blur);
        out_color = color;
        out_color.a *= a;
    }

    if (clip_box_index >= 0) {
        ClipBox clip = u_clip_boxes[clip_box_index];
        vec2 position = (clip.bounds.xy + clip.bounds.zw) * 0.5;
        vec2 size = clip.bounds.zw - clip.bounds.xy;

        float d = PrimBox(p - position, size, clip.corner_radiuses);

        float a = FxSolidColor(d, aa);

        out_color.a *= a;
    }
}
GLSL

#scope_export

Init :: () {
    #import "File";

    g_shader = LoadShader("OhMyGUI", Vertex_Shader, Fragment_Shader);
    assert(g_shader.handle != 0, "Could not load OhMyGUI shader");

    glGenBuffers(1, *g_clip_boxes_buffer);
    glGenBuffers(1, *g_vertices_buffer);
    glGenBuffers(1, *g_indices_buffer);

    glGenVertexArrays(1, *g_vao);
    glBindVertexArray(g_vao);
    glBindBuffer(GL_ARRAY_BUFFER, g_vertices_buffer);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void, 0));

    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void, 8));

    glEnableVertexAttribArray(2);
    glVertexAttribPointer(2, 4, GL_UNSIGNED_BYTE, GL_TRUE, size_of(Vertex), cast(*void, 16));

    glEnableVertexAttribArray(3);
    glVertexAttribPointer(3, 1, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void, 20));

    glEnableVertexAttribArray(4);
    glVertexAttribPointer(4, 1, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void, 24));

    glEnableVertexAttribArray(5);
    glVertexAttribIPointer(5, 1, GL_INT, size_of(Vertex), cast(*void, 28));

    glBindVertexArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    white : u32 = 0xffffffff;
    g_white_texture = xx CreateRGBA8Texture("White Texture", *white, 1, 1);
}

Terminate :: () {
    glDeleteProgram(g_shader.handle);
    g_shader.handle = 0;

    glDeleteBuffers(1, *g_clip_boxes_buffer);
    glDeleteBuffers(1, *g_vertices_buffer);
    glDeleteBuffers(1, *g_indices_buffer);
    glDeleteVertexArrays(1, *g_vao);

    glDeleteTextures(1, *g_white_texture);
}

Render :: (viewport_w : u32, viewport_h : u32) {
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBlendEquation(GL_FUNC_ADD);

    push_allocator(temp);

    clip_boxes : [..]ClipBox;
    vertices : [..]Vertex;
    indices : [..]u32;

    for :Windows context.omg {
        it.draw_list.gpu_buffer_clip_boxes_offset = xx clip_boxes.count;
        it.draw_list.gpu_buffer_vertices_offset = xx vertices.count;
        it.draw_list.gpu_buffer_indices_offset = xx indices.count;

        array_add(*clip_boxes, ..it.draw_list.clip_boxes);
        array_add(*vertices, ..it.draw_list.vertices);
        array_add(*indices, ..it.draw_list.indices);
    }

    glBindBuffer(GL_SHADER_STORAGE_BUFFER, g_clip_boxes_buffer);
    defer glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

    clip_boxes_size := clip_boxes.count * size_of(ClipBox);
    glBufferData(GL_SHADER_STORAGE_BUFFER, xx clip_boxes_size, clip_boxes.data, GL_STREAM_DRAW);

    glBindVertexArray(g_vao);
    defer glBindVertexArray(0);

    glBindBuffer(GL_ARRAY_BUFFER, g_vertices_buffer);
    defer glBindBuffer(GL_ARRAY_BUFFER, 0);

    vertices_size := vertices.count * size_of(Vertex);
    glBufferData(GL_ARRAY_BUFFER, xx vertices_size, vertices.data, GL_STREAM_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_indices_buffer);
    defer glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

    indices_size := indices.count * size_of(u32);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, xx indices_size, indices.data, GL_STREAM_DRAW);

    clip_boxes_offset := 0;
    for :Windows context.omg {
        glBindBufferRange(GL_SHADER_STORAGE_BUFFER, 0, g_clip_boxes_buffer, xx clip_boxes_offset, xx (it.draw_list.clip_boxes.count * size_of(ClipBox)));
        clip_boxes_offset += it.draw_list.clip_boxes.count * size_of(ClipBox);

        SendDrawCommands(*it.draw_list, viewport_w, viewport_h);

        ClearDrawList(*it.draw_list);
    }
}

SendDrawCommands :: (draw_list : *DrawList, viewport_w : u32, viewport_h : u32) {
    current_texture : GLuint = 0;

    glUseProgram(g_shader.handle);

    if g_shader.u_viewport_size >= 0 {
        glUniform2f(g_shader.u_viewport_size, xx viewport_w, xx viewport_h);
    }

    for draw_list.draw_calls {
        if it.num_indices <= 0 {
            continue;
        }

        if it_index == 0 || current_texture != it.texture.handle {
            if !it.texture.handle {
                glBindTexture(GL_TEXTURE_2D, g_white_texture);
            } else {
                glBindTexture(GL_TEXTURE_2D, xx it.texture.handle);
            }

            current_texture = xx it.texture.handle;
        }

        indices_offset := (draw_list.gpu_buffer_indices_offset + it.index_offset) * size_of(u32);
        glDrawElementsBaseVertex(GL_TRIANGLES, xx it.num_indices, GL_UNSIGNED_INT, cast(*void, indices_offset), xx draw_list.gpu_buffer_vertices_offset);
    }
}

CreateR8Texture :: (name : string, data : *void, width : u32, height : u32) -> TextureHandle {
    result : GLuint;
    glCreateTextures(GL_TEXTURE_2D, 1, *result);
    glTextureStorage2D(result, 1, GL_R8, width, height);

    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTextureSubImage2D(result, 0, 0, 0, width, height, GL_RED, GL_UNSIGNED_BYTE, data);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 4);

    glTextureParameteri(result, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTextureParameteri(result, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTextureParameteri(result, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTextureParameteri(result, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glObjectLabel(GL_TEXTURE, result, xx name.count, name.data);

    return result;
}

CreateRGBA8Texture :: (name : string, data : *void, width : u32, height : u32) -> TextureHandle {
    result : GLuint;
    glCreateTextures(GL_TEXTURE_2D, 1, *result);
    glTextureStorage2D(result, 1, GL_RGBA8, width, height);
    glTextureSubImage2D(result, 0, 0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, data);

    glTextureParameteri(result, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTextureParameteri(result, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTextureParameteri(result, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTextureParameteri(result, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glObjectLabel(GL_TEXTURE, result, xx name.count, name.data);

    return result;
}

DestroyTexture :: (texture : TextureHandle) {
    gl_texture : GLuint = xx texture;
    glDeleteTextures(1, *gl_texture);
}
