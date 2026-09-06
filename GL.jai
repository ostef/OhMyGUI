#import "OhMyGUI";
#import "GL";
#import "Basic";
#import "String";

GetLastFrameMemoryUsage :: inline () -> int {
    return g_last_frame_memory_usage;
}

GetLastFrameGPUTime :: inline () -> float {
    return g_last_frame_gpu_time;
}

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

g_shader_sdf : Shader;
g_shader_box : Shader;
g_shader_glyph : Shader;
g_shader_triangle : Shader;
g_shader_simple : Shader;

g_dummy_vao : GLuint;
g_vertex_vao : GLuint;

g_num_frames_in_flight : int;
g_frame_in_flight : int;
g_timestamp_queries : [][2]GLuint;

g_frame_data_buffer_size : int;
g_frame_data_buffer_handles : []GLuint;
g_frame_data_buffer_ptrs : []*void;

g_clip_boxes_buffer_size : int;
g_clip_boxes_buffer : GLuint;

g_vertices_buffer_size : int;
g_vertices_buffer : GLuint;

g_indices_buffer_size : int;
g_indices_buffer : GLuint;

g_uniform_buffer_offset_alignment : s32;
g_storage_buffer_offset_alignment : s32;

g_last_frame_gpu_time : float;
g_last_frame_memory_usage : int;

GLBufferBinding :: enum {
    ClipBoxes;
    Boxes;
    Glyphs;
    Triangles;
    ShapeDrawings;
    Shapes;
}

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
        glShaderStorageBlockBinding(program, clip_boxes_index, xx GLBufferBinding.ClipBoxes);
    }
    boxes_index := glGetProgramResourceIndex(program, GL_SHADER_STORAGE_BLOCK, "BoxData");
    if boxes_index != GL_INVALID_INDEX {
        glShaderStorageBlockBinding(program, boxes_index, xx GLBufferBinding.Boxes);
    }
    glyphs_index := glGetProgramResourceIndex(program, GL_SHADER_STORAGE_BLOCK, "GlyphData");
    if glyphs_index != GL_INVALID_INDEX {
        glShaderStorageBlockBinding(program, glyphs_index, xx GLBufferBinding.Glyphs);
    }
    triangles_index := glGetProgramResourceIndex(program, GL_SHADER_STORAGE_BLOCK, "TriangleData");
    if triangles_index != GL_INVALID_INDEX {
        glShaderStorageBlockBinding(program, triangles_index, xx GLBufferBinding.Triangles);
    }
    shape_drawings_index := glGetProgramResourceIndex(program, GL_SHADER_STORAGE_BLOCK, "ShapeDrawingData");
    if shape_drawings_index != GL_INVALID_INDEX {
        glShaderStorageBlockBinding(program, shape_drawings_index, xx GLBufferBinding.ShapeDrawings);
    }
    shapes_index := glGetProgramResourceIndex(program, GL_SHADER_STORAGE_BLOCK, "ShapeData");
    if shapes_index != GL_INVALID_INDEX {
        glShaderStorageBlockBinding(program, shapes_index, xx GLBufferBinding.Shapes);
    }

    return result;
}

#scope_export

Init :: (num_frames_in_flight := 2, frame_data_buffer_size := 1 * 1024 * 1024) -> bool {
    g_num_frames_in_flight = num_frames_in_flight;

    #import "File";

    Common_Shader :: #run ReadCompileTimeFile("Shaders/common.glsl");

    Box_Vertex_Shader :: #run join(Common_Shader, "#line 1\n", ReadCompileTimeFile("Shaders/box.vert.glsl"));
    Box_Fragment_Shader :: #run join(Common_Shader, "#line 1\n", ReadCompileTimeFile("Shaders/box.frag.glsl"));

    Glyph_Vertex_Shader :: #run join(Common_Shader, "#line 1\n", ReadCompileTimeFile("Shaders/glyph.vert.glsl"));
    Glyph_Fragment_Shader :: #run join(Common_Shader, "#line 1\n", ReadCompileTimeFile("Shaders/glyph.frag.glsl"));

    Triangle_Vertex_Shader :: #run join(Common_Shader, "#line 1\n", ReadCompileTimeFile("Shaders/triangle.vert.glsl"));
    Triangle_Fragment_Shader :: #run join(Common_Shader, "#line 1\n", ReadCompileTimeFile("Shaders/triangle.frag.glsl"));

    SDF_Vertex_Shader :: #run join(Common_Shader, "#line 1\n", ReadCompileTimeFile("Shaders/sdf.vert.glsl"));
    SDF_Fragment_Shader :: #run join(Common_Shader, "#line 1\n", ReadCompileTimeFile("Shaders/sdf.frag.glsl"));

    Simple_Vertex_Shader :: #run ReadCompileTimeFile("Shaders/simple.vert.glsl");
    Simple_Fragment_Shader :: #run ReadCompileTimeFile("Shaders/simple.frag.glsl");

    g_shader_simple = LoadShader("Simple", Simple_Vertex_Shader, Simple_Fragment_Shader);
    if !g_shader_simple.handle {
        return false;
    }

    g_shader_box = LoadShader("Box", Box_Vertex_Shader, Box_Fragment_Shader);
    if !g_shader_box.handle {
        return false;
    }

    g_shader_glyph = LoadShader("Glyph", Glyph_Vertex_Shader, Glyph_Fragment_Shader);
    if !g_shader_glyph.handle {
        return false;
    }

    g_shader_triangle = LoadShader("Triangle", Triangle_Vertex_Shader, Triangle_Fragment_Shader);
    if !g_shader_triangle.handle {
        return false;
    }

    g_shader_sdf = LoadShader("SDF", SDF_Vertex_Shader, SDF_Fragment_Shader);
    if !g_shader_sdf.handle {
        return false;
    }

    g_clip_boxes_buffer_size = 0;
    glGenBuffers(1, *g_clip_boxes_buffer);

    g_vertices_buffer_size = 0;
    glGenBuffers(1, *g_vertices_buffer);

    g_indices_buffer_size = 0;
    glGenBuffers(1, *g_indices_buffer);

    glGenVertexArrays(1, *g_vertex_vao);
    glBindVertexArray(g_vertex_vao);
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

    glCreateVertexArrays(1, *g_dummy_vao);

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

    white : u32 = 0xffffffff;
    g_white_texture = xx CreateRGBA8Texture("White Texture", *white, 1, 1);

    log("Initialized GL backend");
    log("Num frames in flight: %", g_num_frames_in_flight);
    log("Frame data buffer: % bytes", g_frame_data_buffer_size);
    log("GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT = %", g_uniform_buffer_offset_alignment);
    log("GL_SHADER_STORAGE_BUFFER_OFFSET_ALIGNMENT = %", g_storage_buffer_offset_alignment);

    return true;
}

Terminate :: () {
    glDeleteQueries(xx (g_timestamp_queries.count * 2), xx g_timestamp_queries.data);
    free(g_timestamp_queries.data);

    glDeleteProgram(g_shader_box.handle);
    g_shader_sdf.handle = 0;
    glDeleteProgram(g_shader_glyph.handle);
    g_shader_sdf.handle = 0;
    glDeleteProgram(g_shader_triangle.handle);
    g_shader_sdf.handle = 0;
    glDeleteProgram(g_shader_sdf.handle);
    g_shader_sdf.handle = 0;

    glDeleteVertexArrays(1, *g_dummy_vao);
    g_dummy_vao = 0;

    glDeleteBuffers(xx g_frame_data_buffer_handles.count, g_frame_data_buffer_handles.data);

    free(g_frame_data_buffer_handles.data);
    g_frame_data_buffer_handles = .[];

    free(g_frame_data_buffer_ptrs.data);
    g_frame_data_buffer_ptrs = .[];
}

Render :: (viewport_w : u32, viewport_h : u32) {
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

    defer g_frame_in_flight = (g_frame_in_flight + 1) % g_num_frames_in_flight;

    push_allocator(temp);

    RenderVtxDrawLists(viewport_w, viewport_h);

    glQueryCounter(g_timestamp_queries[g_frame_in_flight][1], GL_TIMESTAMP);
}

RenderVtxDrawLists :: (viewport_w : u32, viewport_h : u32) {
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBlendEquation(GL_FUNC_ADD);

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

    glBindVertexArray(g_vertex_vao);
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
        glBindBufferRange(GL_SHADER_STORAGE_BUFFER, xx GLBufferBinding.ClipBoxes, g_clip_boxes_buffer, xx clip_boxes_offset, xx (it.draw_list.clip_boxes.count * size_of(ClipBox)));
        clip_boxes_offset += it.draw_list.clip_boxes.count * size_of(ClipBox);

        SendDrawCommands(*it.draw_list, viewport_w, viewport_h);

        ClearDrawList(*it.draw_list);
    }
}

SendDrawCommands :: (draw_list : *VtxDrawList, viewport_w : u32, viewport_h : u32) {
    current_texture : GLuint = 0;

    glUseProgram(g_shader_simple.handle);

    if g_shader_simple.u_viewport_size >= 0 {
        glUniform2f(g_shader_simple.u_viewport_size, xx viewport_w, xx viewport_h);
    }

    for draw_list.draw_calls {
        if it.num_indices <= 0 {
            continue;
        }

        num_vertices : u32;

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

RenderDrawLists :: (viewport_w : u32, viewport_h : u32) {
    clip_boxes : [..]ShaderClipBox;
    boxes : [..]ShaderBoxDrawing;
    glyphs : [..]ShaderGlyphDrawing;
    triangles : [..]ShaderTriangleDrawing;
    shape_drawings : [..]ShaderShapeDrawing;
    shapes : [..]ShaderShape;

    for :Windows context.omg {
        CopyDrawListShaderData(
            *it.draw_list,
            *clip_boxes,
            *boxes,
            *glyphs,
            *triangles,
            *shape_drawings,
            *shapes
        );
    }

    clip_boxes_offset := 0;
    clip_boxes_size := clip_boxes.count * size_of(ShaderClipBox);

    boxes_offset := align_forward(clip_boxes_offset + clip_boxes_size, g_storage_buffer_offset_alignment);
    boxes_size := boxes.count * size_of(ShaderBoxDrawing);

    glyphs_offset := align_forward(boxes_offset + boxes_size, g_storage_buffer_offset_alignment);
    glyphs_size := glyphs.count * size_of(ShaderGlyphDrawing);

    triangles_offset := align_forward(glyphs_offset + glyphs_size, g_storage_buffer_offset_alignment);
    triangles_size := triangles.count * size_of(ShaderTriangleDrawing);

    shape_drawings_offset := align_forward(triangles_offset + triangles_size, g_storage_buffer_offset_alignment);
    shape_drawings_size := shape_drawings.count * size_of(ShaderShapeDrawing);

    shapes_offset := align_forward(shape_drawings_offset + shape_drawings_size, g_storage_buffer_offset_alignment);
    shapes_size := shapes.count * size_of(ShaderShape);

    total_size := shapes_offset + shapes_size;
    g_last_frame_memory_usage = total_size;

    buffer_handle := g_frame_data_buffer_handles[g_frame_in_flight];
    buffer_ptr := g_frame_data_buffer_ptrs[g_frame_in_flight];
    if total_size > g_frame_data_buffer_size {
        log_error("Too many things to draw % of % bytes: % clip boxes, % boxes, % glyphs, % triangles, % shape drawings, % shapes\n", total_size, g_frame_data_buffer_size, clip_boxes.count, boxes.count, glyphs.count, triangles.count, shape_drawings.count, shapes.count);
        return;
    } else if total_size > xx (g_frame_data_buffer_size * 0.75) {
        log_error("Exceeding 75\% of the frame data buffer capacity, % of % bytes (%\%): % clip boxes, % boxes, % glyphs, % triangles, % shape drawings, % shapes\n", total_size, g_frame_data_buffer_size, cast(int, total_size / cast(float, g_frame_data_buffer_size) * 100), clip_boxes.count, boxes.count, glyphs.count, triangles.count, shape_drawings.count, shapes.count);
    }

    memcpy(buffer_ptr + clip_boxes_offset, clip_boxes.data, clip_boxes_size);
    memcpy(buffer_ptr + boxes_offset, boxes.data, boxes_size);
    memcpy(buffer_ptr + glyphs_offset, glyphs.data, glyphs_size);
    memcpy(buffer_ptr + triangles_offset, triangles.data, triangles_size);
    memcpy(buffer_ptr + shape_drawings_offset, shape_drawings.data, shape_drawings_size);
    memcpy(buffer_ptr + shapes_offset, shapes.data, shapes_size);

    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    glEnable(GL_BLEND);
    // We already multiply RGB with the alpha in the shaders, so use ONE for the RGB factor
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glBlendEquation(GL_FUNC_ADD);

    glBindVertexArray(g_dummy_vao);

    glBindBufferRange(GL_SHADER_STORAGE_BUFFER, xx GLBufferBinding.ClipBoxes, buffer_handle, xx clip_boxes_offset, xx clip_boxes_size);
    glBindBufferRange(GL_SHADER_STORAGE_BUFFER, xx GLBufferBinding.Boxes, buffer_handle, xx boxes_offset, xx boxes_size);
    glBindBufferRange(GL_SHADER_STORAGE_BUFFER, xx GLBufferBinding.Glyphs, buffer_handle, xx glyphs_offset, xx glyphs_size);
    glBindBufferRange(GL_SHADER_STORAGE_BUFFER, xx GLBufferBinding.Triangles, buffer_handle, xx triangles_offset, xx triangles_size);
    glBindBufferRange(GL_SHADER_STORAGE_BUFFER, xx GLBufferBinding.ShapeDrawings, buffer_handle, xx shape_drawings_offset, xx shape_drawings_size);
    glBindBufferRange(GL_SHADER_STORAGE_BUFFER, xx GLBufferBinding.Shapes, buffer_handle, xx shapes_offset, xx shapes_size);

    for :Windows context.omg {
        defer ClearDrawList(*it.draw_list);

        SendDrawCommands(*it.draw_list, viewport_w, viewport_h);
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

CopyDrawListShaderData :: (
    draw_list : *DrawList,
    clip_boxes : *[..]ShaderClipBox,
    boxes : *[..]ShaderBoxDrawing,
    glyphs : *[..]ShaderGlyphDrawing,
    triangles : *[..]ShaderTriangleDrawing,
    shape_drawings : *[..]ShaderShapeDrawing,
    shapes : *[..]ShaderShape
) {
    draw_list.gpu_buffer_clip_boxes_offset = xx clip_boxes.count;
    draw_list.gpu_buffer_boxes_offset = xx boxes.count;
    draw_list.gpu_buffer_glyphs_offset = xx glyphs.count;
    draw_list.gpu_buffer_triangles_offset = xx triangles.count;
    draw_list.gpu_buffer_shape_drawings_offset = xx shape_drawings.count;
    draw_list.gpu_buffer_shapes_offset = xx shapes.count;
    draw_list.num_shapes = 0;

    for draw_list.clip_boxes {
        box := array_add(clip_boxes);
        box.bounds = it.bounds;
        box.corner_radiuses = it.corner_radiuses;
    }

    for draw_list.boxes {
        box := array_add(boxes);
        box.size_and_position.xy = it.size;
        box.size_and_position.zw = it.position;
        box.uv_bounds = it.uv_bounds;
        box.rotation = it.rotation;
        box.corner_radiuses = it.corner_radiuses;
        box.background_color = it.background_color;
        box.background_color2 = it.background_color2;
        box.background_gradient_vector = it.background_gradient_vector;
        box.background_gradient_offset = it.background_gradient_offset;
        box.border_color = it.border_color;
        box.border_color2 = it.border_color2;
        box.border_gradient_vector = it.border_gradient_vector;
        box.border_gradient_offset = it.border_gradient_offset;
        box.border_size_and_inset.x = it.border_size;
        box.border_size_and_inset.y = it.border_inset;
        box.outer_shadow_color = it.outer_shadow_color;
        box.outer_shadow_offset = it.outer_shadow_offset;
        box.outer_shadow_blur = it.outer_shadow_blur;
        box.inner_shadow_color = it.inner_shadow_color;
        box.inner_shadow_offset = it.inner_shadow_offset;
        box.inner_shadow_blur = it.inner_shadow_blur;
        box.clip_box_index = ifx it.clip_box_index >= 0
            then cast(s32, draw_list.gpu_buffer_clip_boxes_offset) + it.clip_box_index
            else -1;
    }

    for draw_list.glyphs {
        glyph := array_add(glyphs);
        glyph.bounds = it.bounds;
        glyph.uv_bounds = it.uv_bounds;
        glyph.sdf_range = it.sdf_range;
        glyph.outer_shadow_offset = it.outer_shadow_offset;
        glyph.inner_shadow_offset = it.inner_shadow_offset;
        glyph.gradient_vector = it.gradient_vector;
        glyph.gradient_offset = it.gradient_offset;
        glyph.color = it.color;
        glyph.color2 = it.color2;
        glyph.outer_shadow_color = it.outer_shadow_color;
        glyph.outer_shadow_blur = it.outer_shadow_blur;
        glyph.inner_shadow_color = it.inner_shadow_color;
        glyph.inner_shadow_blur = it.inner_shadow_blur;
        glyph.clip_box_index = ifx it.clip_box_index >= 0
            then cast(s32, draw_list.gpu_buffer_clip_boxes_offset) + it.clip_box_index
            else -1;
    }

    for draw_list.triangles {
        triangle := array_add(triangles);
        triangle.* = it;
        triangle.clip_box_index = ifx it.clip_box_index >= 0
            then cast(s32, draw_list.gpu_buffer_clip_boxes_offset) + it.clip_box_index
            else -1;
    }

    for draw_list.shapes {
        drawing := array_add(shape_drawings);
        drawing.first_shape_index = cast(u32, shapes.count);
        drawing.num_shapes = FlattenShapes(it.shape, shapes);
        draw_list.num_shapes += drawing.num_shapes;

        drawing.bounds = GetBounds(it.shape);
        drawing.position = it.position;
        drawing.background_color = it.background_color;
        drawing.background_color2 = it.background_color2;
        drawing.background_gradient_vector = it.background_gradient_vector;
        drawing.background_gradient_offset = it.background_gradient_offset;
        drawing.border_color = it.border_color;
        drawing.border_color2 = it.border_color2;
        drawing.border_gradient_vector = it.border_gradient_vector;
        drawing.border_gradient_offset = it.border_gradient_offset;
        drawing.border_size_and_inset.x = it.border_size;
        drawing.border_size_and_inset.y = it.border_inset;
        drawing.outer_shadow_color = it.outer_shadow_color;
        drawing.outer_shadow_offset = it.outer_shadow_offset;
        drawing.outer_shadow_blur = it.outer_shadow_blur;
        drawing.inner_shadow_color = it.inner_shadow_color;
        drawing.inner_shadow_offset = it.inner_shadow_offset;
        drawing.inner_shadow_blur = it.inner_shadow_blur;
        drawing.clip_box_index = ifx it.clip_box_index >= 0
            then cast(s32, draw_list.gpu_buffer_clip_boxes_offset) + it.clip_box_index
            else -1;
    }
}

SendDrawCommands :: (draw_list : *DrawList, viewport_w : u32, viewport_h : u32) {
    current_shader : GLuint = 0;
    current_texture : GLuint = 0;
    u_base_instance : GLint = -1;

    for draw_list.draw_calls {
        first_instance : u32;

        num_instances := it.last - it.first + 1;
        if num_instances <= 0 {
            continue;
        }

        num_vertices : u32;

        // msg := tprint("Draw Call, % (% instances, % first, % last)", it.kind, num_instances, it.first, it.last);
        // glDebugMessageInsert(GL_DEBUG_SOURCE_APPLICATION, GL_DEBUG_TYPE_MARKER, 0, GL_DEBUG_SEVERITY_NOTIFICATION, xx msg.count, xx msg.data);

        SetShader :: (shader : Shader) #expand {
            if `current_shader != shader.handle {
                glUseProgram(shader.handle);
                current_shader = shader.handle;

                if shader.u_viewport_size >= 0 {
                    glUniform2f(shader.u_viewport_size, xx `viewport_w, xx `viewport_h);
                }

                `u_base_instance = shader.u_base_instance;
            }
        }

        if it.kind == {
        case .Boxes;
            num_vertices = 6;
            first_instance = it.first + draw_list.gpu_buffer_boxes_offset;
            SetShader(g_shader_box);

        case .Glyphs;
            num_vertices = 6;
            first_instance = it.first + draw_list.gpu_buffer_glyphs_offset;
            SetShader(g_shader_glyph);

        case .Triangles;
            num_vertices = 3;
            first_instance = it.first + draw_list.gpu_buffer_triangles_offset;
            SetShader(g_shader_triangle);

        case .Shapes;
            num_vertices = 6;
            first_instance = it.first + draw_list.gpu_buffer_shape_drawings_offset;
            SetShader(g_shader_sdf);
        }

        if it_index == 0 || current_texture != it.texture {
            if !it.texture {
                glBindTextureUnit(0, g_white_texture);
            } else {
                glBindTextureUnit(0, xx it.texture);
            }

            current_texture = xx it.texture;
        }

        if u_base_instance >= 0 {
            glUniform1i(u_base_instance, xx first_instance);
        }

        glDrawArraysInstancedBaseInstance(GL_TRIANGLES, 0, num_vertices, xx num_instances, xx first_instance);
    }
}
