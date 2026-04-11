#import "GL";

Max_Instances :: 10000;
Max_Shapes :: 5 * Max_Instances;
Default_Shapes_Buffer_Size :: Max_Shapes * size_of(ShaderSDShape) + Max_Instances * size_of(ShaderSDInstance);

#scope_module

ShaderSDInstance :: struct {
    bounds : Vec4f;
    position : Vec2f;
    first_shape_index : u32;
    num_shapes : u32;
}

ShaderSDShape :: struct {
    kind : u32;
    padding : [3]u32;
    params : [8]float;
}

g_shader : GLuint;
g_dummy_vao : GLuint;

g_num_frames_in_flight : int;
g_frame_in_flight : int;
g_shape_buffer_size : int;
g_shape_buffer_handles : []GLuint;
g_shape_buffer_ptrs : []*void;

g_uniform_buffer_offset_alignment : s32;
g_storage_buffer_offset_alignment : s32;

Vertex_Shader :: #string GLSL
#version 460 core

struct Instance {
    vec4 bounds;
    vec2 position;
    uint first_shape_index;
    uint num_shapes;
};

layout(binding=0, std430) readonly buffer InstanceData {
    Instance u_instances[];
};
uniform vec2 u_viewport_size;

layout(location=0) out flat uint out_first_shape_index;
layout(location=1) out flat uint out_num_shapes;
layout(location=2) out vec2 out_position;

void main() {
    Instance inst = u_instances[gl_InstanceID];
    out_first_shape_index = inst.first_shape_index;
    out_num_shapes = inst.num_shapes;
    out_position = inst.position;

    const vec2 positions[] = vec2[](
        vec2(inst.bounds.z, inst.bounds.w), vec2(inst.bounds.x, inst.bounds.w), vec2(inst.bounds.x, inst.bounds.y),
        vec2(inst.bounds.z, inst.bounds.w), vec2(inst.bounds.x, inst.bounds.y), vec2(inst.bounds.z, inst.bounds.y)
    );

    gl_Position.xy = ((positions[gl_VertexID] + inst.position) / u_viewport_size) * 2 - vec2(1);
    gl_Position.z = 0;
    gl_Position.w = 1;
}
GLSL

Fragment_Shader :: #string GLSL
#version 460 core

struct Shape {
    uint kind;
    vec4 params0;
    vec4 params1;
};

#define Eval_Stack_Size 32
#define Shape_CirclePrimitive 0
#define Shape_BoxPrimitive 1
#define Shape_TrianglePrimitive 2
#define Shape_UnionOperation 200
#define Shape_SmoothUnionOperation 201
#define Shape_SubtractionOperation 202
#define Shape_IntersectionOperation 203
#define Shape_RoundOperation 204
#define Shape_OnionOperation 205
#define Shape_TransformOperation 206

layout(binding=1, std430) readonly buffer ShapeData {
    Shape u_shapes[];
};

layout(location=0) in flat uint in_first_shape_index;
layout(location=1) in flat uint in_num_shapes;
layout(location=2) in vec2 in_position;

layout(location=0) out vec4 out_color;

float PrimCircle(vec2 p, float radius) {
    return length(p) - radius;
}

float PrimBox(vec2 p, vec2 size, vec4 corner_radiuses) {
    corner_radiuses.xy = p.x > 0.0 ? corner_radiuses.xy : corner_radiuses.zw;
    corner_radiuses.x  = p.y > 0.0 ? corner_radiuses.x  : corner_radiuses.y;
    vec2 q = abs(p) - size * 0.5 + corner_radiuses.x;

    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - corner_radiuses.x;
}

float PrimTriangle(vec2 p, vec2 p0, vec2 p1, vec2 p2) {
    vec2 e0 = p1 - p0;
    vec2 e1 = p2 - p1;
    vec2 e2 = p0 - p2;
    vec2 v0 = p - p0;
    vec2 v1 = p - p1;
    vec2 v2 = p - p2;

    vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
    vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
    vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);

    float s = sign(e0.x * e2.y - e0.y * e2.x);
    vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
                     vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
                     vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));

    return -sqrt(d.x) * sign(d.y);
}

float OpUnion(float a, float b) {
    return min(a, b);
}

// https://iquilezles.org/articles/smin/
// Quadratic polynomial smooth union
float OpSmoothUnion(float a, float b, float k) {
    k *= 4.0;
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * (1.0 / 4.0);
}

float OpIntersection(float a, float b) {
    return max(a, b);
}

float OpSubtraction(float a, float b) {
    return max(a, -b);
}

float OpRound(float a, float radius) {
    return a - radius;
}

float OpOnion(float a, float radius) {
    return abs(a) - radius;
}

float EvalSDF(vec2 p) {
    float values[Eval_Stack_Size];
    uint value_index = 0;

    uint shape_index = in_first_shape_index;
    uint last_shape = in_first_shape_index + in_num_shapes;
    while (shape_index < last_shape && value_index < Eval_Stack_Size) {
        Shape shape = u_shapes[shape_index];
        shape_index += 1;

        switch (shape.kind) {
        case Shape_CirclePrimitive: {
            float radius = shape.params0.x;
            values[value_index] = PrimCircle(p, radius);
            value_index += 1;
        } break;

        case Shape_BoxPrimitive: {
            vec2 size = shape.params0.xy;
            vec4 corner_radiuses = vec4(shape.params0.zw, shape.params1.xy);
            values[value_index] = PrimBox(p, size, corner_radiuses);
            value_index += 1;
        } break;

        case Shape_TrianglePrimitive: {
            vec2 p0 = shape.params0.xy;
            vec2 p1 = shape.params0.zw;
            vec2 p2 = shape.params1.xy;
            values[value_index] = PrimTriangle(p, p0, p1, p2);
            value_index += 1;
        } break;

        case Shape_UnionOperation: {
            float a = values[value_index - 1];
            float b = values[value_index - 2];
            value_index -= 2;

            values[value_index] = OpUnion(a, b);
            value_index += 1;
        } break;

        case Shape_SmoothUnionOperation: {
            float a = values[value_index - 1];
            float b = values[value_index - 2];
            float k = shape.params0.x;
            value_index -= 2;

            values[value_index] = OpSmoothUnion(a, b, k);
            value_index += 1;
        } break;

        case Shape_SubtractionOperation: {
            float a = values[value_index - 1];
            float b = values[value_index - 2];
            value_index -= 2;

            values[value_index] = OpSubtraction(a, b);
            value_index += 1;
        } break;

        case Shape_IntersectionOperation: {
            float a = values[value_index - 1];
            float b = values[value_index - 2];
            value_index -= 2;

            values[value_index] = OpIntersection(a, b);
            value_index += 1;
        } break;

        case Shape_RoundOperation: {
            float a = values[value_index - 1];
            value_index -= 1;

            values[value_index] = OpRound(a, shape.params0.x);
            value_index += 1;
        } break;

        case Shape_OnionOperation: {
            float a = values[value_index - 1];
            value_index -= 1;

            values[value_index] = OpOnion(a, shape.params0.x);
            value_index += 1;
        } break;

        case Shape_TransformOperation: {
            mat3 transform = mat3(
                shape.params0.x, shape.params0.w, 0,
                shape.params0.y, shape.params1.x, 0,
                shape.params0.z, shape.params1.y, 1
            );

            p = (transform * vec3(p, 1)).xy;
        } break;
        }
    }

    if (value_index == 0) {
        return 1.0e9;
    }

    return values[value_index - 1];
}

void main() {
    vec2 p = gl_FragCoord.xy - in_position;
    float d = EvalSDF(p);
    float aa = length(vec2(dFdx(d), dFdy(d)));
    float alpha = clamp(1 - smoothstep(-aa, aa, d), 0, 1);

    out_color = mix(vec4(1,1,1,1), vec4(1,0,0,1), alpha);
}
GLSL

#scope_export

InitGL :: (num_frames_in_flight : int = 2, shape_buffer_size : int = Default_Shapes_Buffer_Size) -> bool {
    g_num_frames_in_flight = num_frames_in_flight;

    glCreateVertexArrays(1, *g_dummy_vao);

    status, log_length : GLint;

    vertex_shader := glCreateShader(GL_VERTEX_SHADER);
    defer glDeleteShader(vertex_shader);

    fragment_shader := glCreateShader(GL_FRAGMENT_SHADER);
    defer glDeleteShader(fragment_shader);

    vertex_source := Vertex_Shader;
    glShaderSource(vertex_shader, 1, *vertex_source.data, null);
    glCompileShader(vertex_shader);

    glGetShaderiv(vertex_shader, GL_COMPILE_STATUS, *status);
    glGetShaderiv(vertex_shader, GL_INFO_LOG_LENGTH, *log_length);
    if !status {
        log : *u8 = alloc(log_length + 1 ,, temp);
        glGetShaderInfoLog(vertex_shader, xx log_length, null, log);

        message := string.{log_length, log};

        log_error("Could not compile vertex shader: %", message);

        return false;
    }

    fragment_source := Fragment_Shader;
    glShaderSource(fragment_shader, 1, *fragment_source.data, null);
    glCompileShader(fragment_shader);

    glGetShaderiv(fragment_shader, GL_COMPILE_STATUS, *status);
    glGetShaderiv(fragment_shader, GL_INFO_LOG_LENGTH, *log_length);
    if !status {
        log : *u8 = alloc(log_length + 1 ,, temp);
        glGetShaderInfoLog(fragment_shader, xx log_length, null, log);

        message := string.{log_length, log};

        log_error("Could not compile fragment shader: %", message);

        return false;
    }

    g_shader = glCreateProgram();

    glAttachShader(g_shader, vertex_shader);
    defer glDetachShader(g_shader, vertex_shader);

    glAttachShader(g_shader, fragment_shader);
    defer glDetachShader(g_shader, fragment_shader);

    glLinkProgram(g_shader);

    glGetProgramiv(g_shader, GL_LINK_STATUS, *status);
    glGetProgramiv(g_shader, GL_INFO_LOG_LENGTH, *log_length);
    if !status {
        log : *u8 = alloc(log_length + 1 ,, temp);
        glGetProgramInfoLog(g_shader, xx log_length, null, log);

        message := string.{log_length, log};

        log_error("Could not compile shader: %", message);

        return false;
    }

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

    glGetIntegerv(GL_SHADER_STORAGE_BUFFER_OFFSET_ALIGNMENT, *g_storage_buffer_offset_alignment);
    assert(g_storage_buffer_offset_alignment > 0);

    print("Initialized GL backend\n");
    print("Num frames in flight: %\n", g_num_frames_in_flight);
    print("Shapes buffer: % bytes\n", g_shape_buffer_size);
    print("GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT = %\n", g_uniform_buffer_offset_alignment);
    print("GL_SHADER_STORAGE_BUFFER_OFFSET_ALIGNMENT = %\n", g_storage_buffer_offset_alignment);

    return true;
}

TerminateGL :: () {
    glDeleteProgram(g_shader);
    g_shader = 0;

    glDeleteVertexArrays(1, *g_dummy_vao);
    g_dummy_vao = 0;

    glDeleteBuffers(xx g_shape_buffer_handles.count, g_shape_buffer_handles.data);

    free(g_shape_buffer_handles.data);
    g_shape_buffer_handles = .[];

    free(g_shape_buffer_ptrs.data);
    g_shape_buffer_ptrs = .[];
}

RenderGL :: (viewport_w : u32, viewport_h : u32) {
    AlignBuffer :: (buffer : *[..]u8, align : int) {
        padding := buffer.count;
        padding = align_forward(padding, align);
        padding -= buffer.count;
        for 0..padding - 1 {
            array_add(buffer, 0);
        }
    }

    PushBytes :: (buffer : *[..]u8, num_bytes : int) -> offset : int, ptr : *u8 {
        offset := buffer.count;
        if buffer.count + num_bytes > buffer.allocated {
            array_reserve(buffer, buffer.count + num_bytes);
        }

        buffer.count += num_bytes;

        return offset, buffer.data + offset;
    }

    Push :: (buffer : *[..]u8, value : $T) {
        bytes := ([]u8).{count=size_of(T), data=cast(*u8, *value)};
        array_add(buffer, ..bytes);
    }

    FlattenShapes :: (shape : *SDShape, buffer : *[..]u8) -> u32 {
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

            Push(buffer, shshape);
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

        Push(buffer, shshape);
        num_shapes += 1;

        return num_shapes;
    }

    defer g_frame_in_flight = (g_frame_in_flight + 1) % g_num_frames_in_flight;
    defer g_shapes_to_draw.count = 0;

    buffer : [..]u8;
    defer array_free(buffer);

    instances_size := g_shapes_to_draw.count * size_of(ShaderSDInstance);
    instances_offset := PushBytes(*buffer, instances_size);
    AlignBuffer(*buffer, g_storage_buffer_offset_alignment);

    num_instances : int;
    num_shapes : int;
    shapes_offset := buffer.count;
    for g_shapes_to_draw {
        instance : ShaderSDInstance;
        instance.first_shape_index = xx num_shapes;
        instance.num_shapes = FlattenShapes(it.shape, *buffer);
        instance.position = it.position;
        instance.bounds = GetBounds(it.shape);

        memcpy(buffer.data + instances_offset + num_instances * size_of(ShaderSDInstance), *instance, size_of(ShaderSDInstance));

        num_shapes += instance.num_shapes;
        num_instances += 1;
    }

    shapes_size := num_shapes * size_of(ShaderSDShape);

    buffer_handle := g_shape_buffer_handles[g_frame_in_flight];
    buffer_ptr := g_shape_buffer_ptrs[g_frame_in_flight];
    if buffer.count > g_shape_buffer_size {
        log_error("Too many shapes to draw % of % bytes, % shapes, % instances\n", buffer.count, g_shape_buffer_size, num_shapes, num_instances);
        return;
    }

    memcpy(buffer_ptr, buffer.data, buffer.count);

    glUseProgram(g_shader);

    u_viewport_size := glGetUniformLocation(g_shader, "u_viewport_size");
    if u_viewport_size >= 0 {
        glUniform2f(u_viewport_size, xx viewport_w, xx viewport_h);
    }

    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBlendEquation(GL_FUNC_ADD);

    glBindBufferRange(GL_SHADER_STORAGE_BUFFER, 0, buffer_handle, xx instances_offset, xx instances_size);
    glBindBufferRange(GL_SHADER_STORAGE_BUFFER, 1, buffer_handle, xx shapes_offset, xx shapes_size);

    glBindVertexArray(g_dummy_vao);

    glDrawArraysInstanced(GL_TRIANGLES, 0, 6, xx num_instances);
}
