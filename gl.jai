#import "GL";

GetLastFrameGPUTime :: inline () -> float {
    return g_last_frame_gpu_time;
}

#scope_module

g_color_texture : GLuint;
g_color_framebuffer : GLuint;
g_color_texture_width : u32;
g_color_texture_height : u32;

g_shader_shape : GLuint;
g_shader_box : GLuint;
g_shader_glyph : GLuint;
g_shader_triangle : GLuint;
g_dummy_vao : GLuint;

g_num_frames_in_flight : int;
g_frame_in_flight : int;
g_frame_data_buffer_size : int;
g_frame_data_buffer_handles : []GLuint;
g_frame_data_buffer_ptrs : []*void;
g_timestamp_queries : [][2]GLuint;

g_uniform_buffer_offset_alignment : s32;
g_storage_buffer_offset_alignment : s32;

g_last_frame_gpu_time : float;

LoadShader :: (vertex_filename : string, fragment_filename : string) -> GLuint {
    #import "File";

    status, log_length : GLint;

    vertex_source, vertex_ok := read_entire_file(vertex_filename);
    defer free(vertex_source.data);
    if !vertex_ok {
        return 0;
    }

    fragment_source, fragment_ok := read_entire_file(fragment_filename);
    defer free(fragment_source.data);
    if !fragment_ok {
        return 0;
    }

    vertex_shader := glCreateShader(GL_VERTEX_SHADER);
    defer glDeleteShader(vertex_shader);

    fragment_shader := glCreateShader(GL_FRAGMENT_SHADER);
    defer glDeleteShader(fragment_shader);

    vertex_length := cast(s32, vertex_source.count);
    glShaderSource(vertex_shader, 1, *vertex_source.data, *vertex_length);
    glCompileShader(vertex_shader);

    glGetShaderiv(vertex_shader, GL_COMPILE_STATUS, *status);
    glGetShaderiv(vertex_shader, GL_INFO_LOG_LENGTH, *log_length);
    if !status {
        log : *u8 = alloc(log_length + 1 ,, temp);
        glGetShaderInfoLog(vertex_shader, xx log_length, null, log);

        message := string.{log_length, log};

        log_error("Could not compile vertex shader '%': %", vertex_filename, message);

        return 0;
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

        log_error("Could not compile fragment shader '%': %", fragment_filename, message);

        return 0;
    }

    program := glCreateProgram();

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

        log_error("Could not compile shader: %", message);

        return 0;
    }

    return program;
}

#scope_export

InitGL :: (num_frames_in_flight := 2, frame_data_buffer_size := 1 * 1024 * 1024) -> bool {
    g_num_frames_in_flight = num_frames_in_flight;

    g_shader_shape = LoadShader("sdf.vert.glsl", "sdf.frag.glsl");
    if !g_shader_shape {
        return false;
    }

    g_shader_box = LoadShader("box.vert.glsl", "box.frag.glsl");
    if !g_shader_box {
        return false;
    }

    g_shader_glyph = LoadShader("glyph.vert.glsl", "glyph.frag.glsl");
    if !g_shader_glyph {
        return false;
    }

    g_shader_triangle = LoadShader("triangle.vert.glsl", "triangle.frag.glsl");
    if !g_shader_triangle {
        return false;
    }

    glCreateVertexArrays(1, *g_dummy_vao);

    g_frame_data_buffer_handles = NewArray(num_frames_in_flight, GLuint);
    g_frame_data_buffer_size = frame_data_buffer_size;
    g_frame_data_buffer_ptrs = NewArray(num_frames_in_flight, *void);

    glCreateBuffers(xx g_frame_data_buffer_handles.count, g_frame_data_buffer_handles.data);
    for i : 0..g_num_frames_in_flight - 1 {
        handle := g_frame_data_buffer_handles[i];
        if handle == 0 {
            return false;
        }

        glNamedBufferStorage(handle, xx g_frame_data_buffer_size, null, GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT);

        g_frame_data_buffer_ptrs[i] = glMapNamedBufferRange(handle, 0, xx g_frame_data_buffer_size, GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT);
        if g_frame_data_buffer_ptrs[i] == null {
            return false;
        }
    }

    glGetIntegerv(GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT, *g_uniform_buffer_offset_alignment);
    assert(g_uniform_buffer_offset_alignment > 0);
    g_uniform_buffer_offset_alignment = max(g_uniform_buffer_offset_alignment, 16);

    glGetIntegerv(GL_SHADER_STORAGE_BUFFER_OFFSET_ALIGNMENT, *g_storage_buffer_offset_alignment);
    assert(g_storage_buffer_offset_alignment > 0);
    g_storage_buffer_offset_alignment = max(g_storage_buffer_offset_alignment, 16);

    g_timestamp_queries = NewArray(num_frames_in_flight, [2]GLuint);
    glGenQueries(xx (g_timestamp_queries.count * 2), xx g_timestamp_queries.data);

    // Make first query result not cause an error
    for queries, query_backbuffer_index : g_timestamp_queries {
        for queries {
            glQueryCounter(it, GL_TIMESTAMP);

            name := tprint("Query 'Frame Time %, Backbuffer %'", ifx it_index == 0 then "Start" else "End", query_backbuffer_index);
            glObjectLabel(GL_QUERY, it, xx name.count, name.data);
        }
    }

    log("Initialized GL backend");
    log("Num frames in flight: %", g_num_frames_in_flight);
    log("Frame data buffer: % bytes", g_frame_data_buffer_size);
    log("GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT = %", g_uniform_buffer_offset_alignment);
    log("GL_SHADER_STORAGE_BUFFER_OFFSET_ALIGNMENT = %", g_storage_buffer_offset_alignment);

    return true;
}

TerminateGL :: () {
    glDeleteQueries(xx (g_timestamp_queries.count * 2), xx g_timestamp_queries.data);
    free(g_timestamp_queries.data);

    glDeleteProgram(g_shader_shape);
    g_shader_shape = 0;

    glDeleteVertexArrays(1, *g_dummy_vao);
    g_dummy_vao = 0;

    glDeleteBuffers(xx g_frame_data_buffer_handles.count, g_frame_data_buffer_handles.data);

    free(g_frame_data_buffer_handles.data);
    g_frame_data_buffer_handles = .[];

    free(g_frame_data_buffer_ptrs.data);
    g_frame_data_buffer_ptrs = .[];
}

RenderGL :: (viewport_w : u32, viewport_h : u32) {
    last_query_index := g_frame_in_flight - (g_num_frames_in_flight - 1);
    if last_query_index < 0 {
        last_query_index += g_num_frames_in_flight;
    }

    start_time, end_time : s64;
    glGetQueryObjecti64v(g_timestamp_queries[last_query_index][0], GL_QUERY_RESULT, *start_time);
    glGetQueryObjecti64v(g_timestamp_queries[last_query_index][1], GL_QUERY_RESULT, *end_time);

    elapsed := end_time - start_time;
    g_last_frame_gpu_time = cast(float, elapsed / 1_000_000_000.0);

    glQueryCounter(g_timestamp_queries[g_frame_in_flight][0], GL_TIMESTAMP);

    if g_color_texture_width != viewport_w || g_color_texture_height != viewport_h {
        glDeleteTextures(1, *g_color_texture);
        glDeleteFramebuffers(1, *g_color_framebuffer);

        glCreateTextures(GL_TEXTURE_2D, 1, *g_color_texture);
        glTextureStorage2D(g_color_texture, 1, GL_RGBA16F, viewport_w, viewport_h);
        g_color_texture_width = viewport_w;
        g_color_texture_height = viewport_h;

        glCreateFramebuffers(1, *g_color_framebuffer);
        glNamedFramebufferTexture(g_color_framebuffer, GL_COLOR_ATTACHMENT0, g_color_texture, 0);
        draw_buffer : GLenum = GL_COLOR_ATTACHMENT0;
        glNamedFramebufferDrawBuffers(g_color_framebuffer, 1, *draw_buffer);

        status := glCheckNamedFramebufferStatus(g_color_framebuffer, GL_DRAW_FRAMEBUFFER);
        assert(status == GL_FRAMEBUFFER_COMPLETE, "Failed to create framebuffer (%)", status);

    }

    defer g_frame_in_flight = (g_frame_in_flight + 1) % g_num_frames_in_flight;

    push_allocator(temp);

    clip_boxes : [..]ShaderClipBox;
    boxes : [..]ShaderBoxDrawing;
    glyphs : [..]ShaderGlyphDrawing;
    triangles : [..]ShaderTriangleDrawing;

    window := context.omg.windows;
    while window {
        defer window = window.next;

        CopyDrawListShaderData(*window.draw_list, *clip_boxes, *boxes, *glyphs, *triangles);
    }

    clip_boxes_offset := 0;
    clip_boxes_size := clip_boxes.count * size_of(ShaderClipBox);

    boxes_offset := align_forward(clip_boxes_offset + clip_boxes_size, g_storage_buffer_offset_alignment);
    boxes_size := boxes.count * size_of(ShaderBoxDrawing);

    glyphs_offset := align_forward(boxes_offset + boxes_size, g_storage_buffer_offset_alignment);
    glyphs_size := glyphs.count * size_of(ShaderGlyphDrawing);

    triangles_offset := align_forward(glyphs_offset + glyphs_size, g_storage_buffer_offset_alignment);
    triangles_size := triangles.count * size_of(ShaderTriangleDrawing);

    total_size := triangles_offset + triangles_size;

    buffer_handle := g_frame_data_buffer_handles[g_frame_in_flight];
    buffer_ptr := g_frame_data_buffer_ptrs[g_frame_in_flight];
    if total_size > g_frame_data_buffer_size {
        log_error("Too many things to draw % of % bytes, % clip boxes, % boxes, % glyphs, % triangles\n", total_size, g_frame_data_buffer_size, clip_boxes.count, boxes.count, glyphs.count, triangles.count);
        return;
    }

    memcpy(buffer_ptr + clip_boxes_offset, clip_boxes.data, clip_boxes_size);
    memcpy(buffer_ptr + boxes_offset, boxes.data, boxes_size);
    memcpy(buffer_ptr + glyphs_offset, glyphs.data, glyphs_size);
    memcpy(buffer_ptr + triangles_offset, triangles.data, triangles_size);

    glBindFramebuffer(GL_FRAMEBUFFER, g_color_framebuffer);

    glClear(GL_COLOR_BUFFER_BIT);

    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    glEnable(GL_BLEND);
    // We already multiply RGB with the alpha in the shaders, so use ONE for the RGB factor
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glBlendEquation(GL_FUNC_ADD);

    glBindVertexArray(g_dummy_vao);

    window = context.omg.windows;
    while window {
        defer {
            ClearDrawList(*window.draw_list);
            window = window.next;
        }

        SendDrawCommands(
            *window.draw_list,
            buffer_handle,
            xx clip_boxes_offset,
            xx boxes_offset,
            xx glyphs_offset,
            xx triangles_offset,
            viewport_w,
            viewport_h
        );
    }

    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
    glBlitFramebuffer(0, 0, xx viewport_w, xx viewport_h, 0, 0, xx viewport_w, xx viewport_h, GL_COLOR_BUFFER_BIT, GL_NEAREST);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);

    glQueryCounter(g_timestamp_queries[g_frame_in_flight][1], GL_TIMESTAMP);
}

// OldDraw :: () {
//     instances_buffer : [..]ShaderSDInstance;
//     shapes_buffer : [..]ShaderSDShape;
//     effects_buffer : [..]ShaderEffect;
//     draw_calls : [..]DrawCall;

//     PrepareRenderingBuffers(*instances_buffer, *shapes_buffer, *effects_buffer, *draw_calls);

//     instances_offset := 0;
//     instances_size := instances_buffer.count * size_of(ShaderSDInstance);

//     shapes_offset := align_forward(instances_offset + instances_size, g_storage_buffer_offset_alignment);
//     shapes_size := shapes_buffer.count * size_of(ShaderSDShape);

//     effects_offset := align_forward(shapes_offset + shapes_size, g_storage_buffer_offset_alignment);
//     effects_size := effects_buffer.count * size_of(ShaderEffect);

//     total_size := effects_offset + effects_size;

//     buffer_handle := g_frame_data_buffer_handles[g_frame_in_flight];
//     buffer_ptr := g_frame_data_buffer_ptrs[g_frame_in_flight];
//     if total_size > g_frame_data_buffer_size {
//         log_error("Too many shapes to draw % of % bytes, % instances, % shapes, % effects\n", total_size, g_frame_data_buffer_size, instances_buffer.count, shapes_buffer.count, effects_buffer.count);
//         return;
//     }

//     memcpy(buffer_ptr + instances_offset, instances_buffer.data, instances_size);
//     memcpy(buffer_ptr + shapes_offset, shapes_buffer.data, shapes_size);
//     memcpy(buffer_ptr + effects_offset, effects_buffer.data, effects_size);

//     glBindFramebuffer(GL_FRAMEBUFFER, g_color_framebuffer);

//     glClear(GL_COLOR_BUFFER_BIT);

//     glDisable(GL_DEPTH_TEST);
//     glDisable(GL_CULL_FACE);
//     glEnable(GL_BLEND);
//     // We already multiply RGB with the alpha in the shaders, so use ONE for the RGB factor
//     glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
//     glBlendEquation(GL_FUNC_ADD);

//     glBindVertexArray(g_dummy_vao);

//     if instances_buffer.count > 0 {
//         glUseProgram(g_shader_shape);

//         u_viewport_size := glGetUniformLocation(g_shader_shape, "u_viewport_size");
//         if u_viewport_size >= 0 {
//             glUniform2f(u_viewport_size, xx viewport_w, xx viewport_h);
//         }

//         glBindBufferRange(GL_SHADER_STORAGE_BUFFER, 0, buffer_handle, xx instances_offset, xx instances_size);
//         glBindBufferRange(GL_SHADER_STORAGE_BUFFER, 1, buffer_handle, xx shapes_offset, xx shapes_size);
//         glBindBufferRange(GL_SHADER_STORAGE_BUFFER, 2, buffer_handle, xx effects_offset, xx effects_size);

//         for draw_calls {
//             glBindTextureUnit(0, xx it.texture);

//             glDrawArraysInstancedBaseInstance(GL_TRIANGLES, 0, 6, it.num_instances, it.base_instance);
//         }
//     }
// }
