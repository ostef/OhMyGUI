#import "GL";

Approx_Max_Instances :: 10000;
Approx_Max_Shapes :: 5 * Approx_Max_Instances;
Approx_Max_Effects :: 5 * Approx_Max_Shapes;
Default_Shapes_Buffer_Size :: Approx_Max_Shapes * size_of(ShaderSDShape) + Approx_Max_Instances * size_of(ShaderSDInstance) + Approx_Max_Effects * size_of(ShaderEffect);

#scope_module

ShaderSDInstance :: struct {
    bounds : Vec4f;
    position : Vec2f;
    first_shape_index : u32;
    num_shapes : u32;
    first_effect_index : u32;
    num_effects : u32;
    padding : [2]u32;
}

ShaderSDShape :: struct {
    kind : u32;
    padding : [3]u32;
    params : [8]float;
}

ShaderEffect :: struct {
    kind : u32;
    padding : [3]u32;
    params : [8]float;
}

g_shape_shader : GLuint;
g_dummy_vao : GLuint;

g_num_frames_in_flight : int;
g_frame_in_flight : int;
g_shape_buffer_size : int;
g_shape_buffer_handles : []GLuint;
g_shape_buffer_ptrs : []*void;

g_uniform_buffer_offset_alignment : s32;
g_storage_buffer_offset_alignment : s32;

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

InitGL :: (num_frames_in_flight : int = 2, shape_buffer_size : int = Default_Shapes_Buffer_Size) -> bool {
    g_num_frames_in_flight = num_frames_in_flight;

    g_shape_shader = LoadShader("sd_shape.vert.glsl", "sd_shape.frag.glsl");
    if !g_shape_shader {
        return false;
    }

    glCreateVertexArrays(1, *g_dummy_vao);

    g_shape_buffer_handles = NewArray(num_frames_in_flight, GLuint);
    g_shape_buffer_size = shape_buffer_size;
    g_shape_buffer_ptrs = NewArray(num_frames_in_flight, *void);

    glCreateBuffers(xx g_shape_buffer_handles.count, g_shape_buffer_handles.data);
    for i : 0..g_num_frames_in_flight - 1 {
        handle := g_shape_buffer_handles[i];
        if handle == 0 {
            return false;
        }

        glNamedBufferStorage(handle, xx g_shape_buffer_size, null, GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT);

        g_shape_buffer_ptrs[i] = glMapNamedBufferRange(handle, 0, xx g_shape_buffer_size, GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT);
        if g_shape_buffer_ptrs[i] == null {
            return false;
        }
    }

    glGetIntegerv(GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT, *g_uniform_buffer_offset_alignment);
    assert(g_uniform_buffer_offset_alignment > 0);
    g_uniform_buffer_offset_alignment = max(g_uniform_buffer_offset_alignment, 16);

    glGetIntegerv(GL_SHADER_STORAGE_BUFFER_OFFSET_ALIGNMENT, *g_storage_buffer_offset_alignment);
    assert(g_storage_buffer_offset_alignment > 0);
    g_storage_buffer_offset_alignment = max(g_storage_buffer_offset_alignment, 16);

    print("Initialized GL backend\n");
    print("Num frames in flight: %\n", g_num_frames_in_flight);
    print("Shapes buffer: % bytes\n", g_shape_buffer_size);
    print("GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT = %\n", g_uniform_buffer_offset_alignment);
    print("GL_SHADER_STORAGE_BUFFER_OFFSET_ALIGNMENT = %\n", g_storage_buffer_offset_alignment);

    return true;
}

TerminateGL :: () {
    glDeleteProgram(g_shape_shader);
    g_shape_shader = 0;

    glDeleteVertexArrays(1, *g_dummy_vao);
    g_dummy_vao = 0;

    glDeleteBuffers(xx g_shape_buffer_handles.count, g_shape_buffer_handles.data);

    free(g_shape_buffer_handles.data);
    g_shape_buffer_handles = .[];

    free(g_shape_buffer_ptrs.data);
    g_shape_buffer_ptrs = .[];
}

RenderGL :: (viewport_w : u32, viewport_h : u32) {
    FlattenShapes :: (shape : *SDShape, buffer : *[..]ShaderSDShape) -> u32 {
        num_shapes : u32;

        shshape : ShaderSDShape;
        shshape.kind = xx shape.kind;

        if #complete shape.kind == {
        case .CirclePrimitive;
            shshape.params[0] = shape.circle_prim.radius;

        case .BoxPrimitive;
            shshape.params[0] = shape.box_prim.size.x;
            shshape.params[1] = shape.box_prim.size.y;
            shshape.params[2] = shape.box_prim.corner_radiuses.x;
            shshape.params[3] = shape.box_prim.corner_radiuses.y;
            shshape.params[4] = shape.box_prim.corner_radiuses.z;
            shshape.params[5] = shape.box_prim.corner_radiuses.w;

        case .TrianglePrimitive;
            shshape.params[0] = shape.triangle_prim.p0.x;
            shshape.params[1] = shape.triangle_prim.p0.y;
            shshape.params[2] = shape.triangle_prim.p1.x;
            shshape.params[3] = shape.triangle_prim.p1.y;
            shshape.params[4] = shape.triangle_prim.p2.x;
            shshape.params[5] = shape.triangle_prim.p2.y;

        case .TexturePrimitive;
            shshape.params[0] = shape.texture_prim.uvs.x;
            shshape.params[1] = shape.texture_prim.uvs.y;
            shshape.params[2] = shape.texture_prim.uvs.z;
            shshape.params[3] = shape.texture_prim.uvs.w;
            shshape.params[4] = shape.texture_prim.size.x;
            shshape.params[5] = shape.texture_prim.size.y;
            shshape.params[6] = shape.texture_prim.dist_range.x;
            shshape.params[7] = shape.texture_prim.dist_range.y;

        case .SmoothSubtractionOperation; #through;
        case .SmoothIntersectionOperation; #through;
        case .SmoothUnionOperation;
            shshape.params[0] = shape.smooth_union_op.k;
            #through;

        case .UnionOperation; #through;
        case .SubtractionOperation; #through;
        case .IntersectionOperation;
            num_shapes += FlattenShapes(shape.union_op.shape_a, buffer);
            num_shapes += FlattenShapes(shape.union_op.shape_b, buffer);

        case .RoundOperation;
            num_shapes += FlattenShapes(shape.round_op.shape, buffer);

            shshape.params[0] = shape.round_op.radius;

        case .OnionOperation;
            num_shapes += FlattenShapes(shape.onion_op.shape, buffer);

            shshape.params[0] = shape.onion_op.radius;

        case .MorphOperation;
            shshape.params[0] = shape.morph_op.t;
            num_shapes += FlattenShapes(shape.morph_op.shape_a, buffer);
            num_shapes += FlattenShapes(shape.morph_op.shape_b, buffer);

        case .TransformOperation;
            // For transform operations, we push 1 transformation to the coordinate
            // system, then we push the shape, then we push another transformation
            // back to the original coordinate system
            t := Invert(shape.transform_op.transform);
            shshape.params[0] = t.a;
            shshape.params[1] = t.b;
            shshape.params[2] = t.tx;
            shshape.params[3] = t.c;
            shshape.params[4] = t.d;
            shshape.params[5] = t.ty;

            array_add(buffer, shshape);
            num_shapes += 1;

            num_shapes += FlattenShapes(shape.transform_op.shape, buffer);

            t = shape.transform_op.transform;
            shshape.params[0] = t.a;
            shshape.params[1] = t.b;
            shshape.params[2] = t.tx;
            shshape.params[3] = t.c;
            shshape.params[4] = t.d;
            shshape.params[5] = t.ty;
        }

        array_add(buffer, shshape);
        num_shapes += 1;

        return num_shapes;
    }

    defer g_frame_in_flight = (g_frame_in_flight + 1) % g_num_frames_in_flight;
    defer context.omg.shapes_to_draw.count = 0;
    defer context.omg.texts_to_draw.count = 0;

    instances_buffer : [..]ShaderSDInstance;
    defer array_free(instances_buffer);
    shapes_buffer : [..]ShaderSDShape;
    defer array_free(shapes_buffer);
    effects_buffer : [..]ShaderEffect;
    defer array_free(effects_buffer);

    for context.omg.shapes_to_draw {
        instance := array_add(*instances_buffer);
        instance.position = it.position;
        instance.bounds = GetBounds(it.shape);
        instance.first_shape_index = xx shapes_buffer.count;
        instance.num_shapes = FlattenShapes(it.shape, *shapes_buffer);
        instance.first_effect_index = xx effects_buffer.count;
        instance.num_effects = xx it.effects.count;

        extended_bounds := instance.bounds;
        for * fx : it.effects {
            effect := array_add(*effects_buffer);
            effect.kind = xx fx.kind;

            new_bounds := GetBounds(instance.bounds, fx);
            extended_bounds = .{
                xy=min(new_bounds.xy, extended_bounds.xy),
                zw=max(new_bounds.zw, extended_bounds.zw),
            };

            if #complete fx.kind == {
            case .SolidColor;
                effect.params[0] = fx.solid_color.color.x;
                effect.params[1] = fx.solid_color.color.y;
                effect.params[2] = fx.solid_color.color.z;
                effect.params[3] = fx.solid_color.color.w;
                effect.params[4] = fx.solid_color.blur_factor;

            case .StrokeColor;
                effect.params[0] = fx.stroke_color.color.x;
                effect.params[1] = fx.stroke_color.color.y;
                effect.params[2] = fx.stroke_color.color.z;
                effect.params[3] = fx.stroke_color.color.w;
                effect.params[4] = fx.stroke_color.blur_factor;
                effect.params[5] = fx.stroke_color.inset;
                effect.params[6] = fx.stroke_color.size;

            case .InnerShadow; #through;
            case .OuterShadow;
                effect.params[0] = fx.outer_shadow.color.x;
                effect.params[1] = fx.outer_shadow.color.y;
                effect.params[2] = fx.outer_shadow.color.z;
                effect.params[3] = fx.outer_shadow.color.w;
                effect.params[4] = fx.outer_shadow.offset.x;
                effect.params[5] = fx.outer_shadow.offset.y;
                effect.params[6] = fx.outer_shadow.blur_factor;
            }
        }

        instance.bounds = extended_bounds;
    }

    instances_offset := 0;
    instances_size := instances_buffer.count * size_of(ShaderSDInstance);

    shapes_offset := align_forward(instances_offset + instances_size, g_storage_buffer_offset_alignment);
    shapes_size := shapes_buffer.count * size_of(ShaderSDShape);

    effects_offset := align_forward(shapes_offset + shapes_size, g_storage_buffer_offset_alignment);
    effects_size := effects_buffer.count * size_of(ShaderEffect);

    total_size := effects_offset + effects_size;

    buffer_handle := g_shape_buffer_handles[g_frame_in_flight];
    buffer_ptr := g_shape_buffer_ptrs[g_frame_in_flight];
    if total_size > g_shape_buffer_size {
        log_error("Too many shapes to draw % of % bytes, % instances, % shapes, % effects\n", total_size, g_shape_buffer_size, instances_buffer.count, shapes_buffer.count, effects_buffer.count);
        return;
    }

    memcpy(buffer_ptr + instances_offset, instances_buffer.data, instances_size);
    memcpy(buffer_ptr + shapes_offset, shapes_buffer.data, shapes_size);
    memcpy(buffer_ptr + effects_offset, effects_buffer.data, effects_size);

    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBlendEquation(GL_FUNC_ADD);

    glBindVertexArray(g_dummy_vao);

    if instances_buffer.count > 0 {
        glUseProgram(g_shape_shader);

        u_viewport_size := glGetUniformLocation(g_shape_shader, "u_viewport_size");
        if u_viewport_size >= 0 {
            glUniform2f(u_viewport_size, xx viewport_w, xx viewport_h);
        }

        glBindTextureUnit(0, context.omg.fonts[0].texture);
        glBindBufferRange(GL_SHADER_STORAGE_BUFFER, 0, buffer_handle, xx instances_offset, xx instances_size);
        glBindBufferRange(GL_SHADER_STORAGE_BUFFER, 1, buffer_handle, xx shapes_offset, xx shapes_size);
        glBindBufferRange(GL_SHADER_STORAGE_BUFFER, 2, buffer_handle, xx effects_offset, xx effects_size);

        glDrawArraysInstanced(GL_TRIANGLES, 0, 6, xx instances_buffer.count);
    }
}
