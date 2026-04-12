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
    params0 : [4]float;
    params1 : [4]float;
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
    gl_Position.z = 0;
    gl_Position.w = 1;
}
GLSL

Fragment_Shader :: #string GLSL
#version 460 core

#define Eval_Stack_Size 32

struct Shape {
    uint kind;
    vec4 params0;
    vec4 params1;
};

#define Shape_CirclePrimitive 0
#define Shape_BoxPrimitive 1
#define Shape_TrianglePrimitive 2

#define Shape_UnionOperation 200
#define Shape_SmoothUnionOperation 201
#define Shape_SubtractionOperation 202
#define Shape_SmoothSubtractionOperation 203
#define Shape_IntersectionOperation 204
#define Shape_SmoothIntersectionOperation 205
#define Shape_RoundOperation 206
#define Shape_OnionOperation 207
#define Shape_MorphOperation 208
#define Shape_TransformOperation 209

struct Effect {
    uint kind;
    vec4 params0;
    vec4 params1;
};

#define Effect_SolidColor 0
#define Effect_StrokeColor 1
#define Effect_OuterShadow 2
#define Effect_InnerShadow 3

layout(binding=1, std430) readonly buffer ShapeData {
    Shape u_shapes[];
};
layout(binding=2, std430) readonly buffer EffectData {
    Effect u_effects[];
};

layout(location=0) in vec2 in_position;
layout(location=1) in flat uint in_first_shape_index;
layout(location=2) in flat uint in_num_shapes;
layout(location=3) in flat uint in_first_effect_index;
layout(location=4) in flat uint in_num_effects;

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

float OpSmoothIntersection(float a, float b, float k) {
    return -OpSmoothUnion(-a, -b, k);
}

float OpSubtraction(float a, float b) {
    return max(a, -b);
}

float OpSmoothSubtraction(float a, float b, float k) {
    return -OpSmoothUnion(-a, b, k);
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
            float a = values[value_index - 2];
            float b = values[value_index - 1];
            value_index -= 2;

            values[value_index] = OpUnion(a, b);
            value_index += 1;
        } break;

        case Shape_SmoothUnionOperation: {
            float a = values[value_index - 2];
            float b = values[value_index - 1];
            float k = shape.params0.x;
            value_index -= 2;

            values[value_index] = OpSmoothUnion(a, b, k);
            value_index += 1;
        } break;

        case Shape_SubtractionOperation: {
            float a = values[value_index - 2];
            float b = values[value_index - 1];
            value_index -= 2;

            values[value_index] = OpSubtraction(a, b);
            value_index += 1;
        } break;

        case Shape_SmoothSubtractionOperation: {
            float a = values[value_index - 2];
            float b = values[value_index - 1];
            float k = shape.params0.x;
            value_index -= 2;

            values[value_index] = OpSmoothSubtraction(a, b, k);
            value_index += 1;
        } break;

        case Shape_IntersectionOperation: {
            float a = values[value_index - 2];
            float b = values[value_index - 1];
            value_index -= 2;

            values[value_index] = OpIntersection(a, b);
            value_index += 1;
        } break;

        case Shape_SmoothIntersectionOperation: {
            float a = values[value_index - 2];
            float b = values[value_index - 1];
            float k = shape.params0.x;
            value_index -= 2;

            values[value_index] = OpSmoothIntersection(a, b, k);
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

        case Shape_MorphOperation: {
            float a = values[value_index - 2];
            float b = values[value_index - 1];
            float t = shape.params0.x;
            value_index -= 2;

            values[value_index] = mix(a, b, t);
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

float FxSolidColor(float d, float edge) {
    float a = 1 - smoothstep(-edge, edge, d);
    return clamp(a, 0, 1);
}

float FxStrokeColor(float d, float edge, float size, float inset) {
    float a = smoothstep(-inset - edge, -inset + edge, d + size) - smoothstep(-inset - edge, -inset + edge, d);
    return clamp(a, 0, 1);
}

vec4 EvalEffects(vec2 p, float d) {
    float aa = length(vec2(dFdx(d), dFdy(d)));

    vec4 result = vec4(0);

    uint effect_index = in_first_effect_index;
    uint last_effect = in_first_effect_index + in_num_effects;
    while (effect_index < last_effect) {
        Effect effect = u_effects[effect_index];
        effect_index += 1;

        switch (effect.kind) {
        case Effect_SolidColor: {
            vec4 color = effect.params0;
            float blur_factor = effect.params1.x;
            float a = FxSolidColor(d, aa + blur_factor);
            result = mix(result, color, a);
        } break;

        case Effect_StrokeColor: {
            vec4 color = effect.params0;
            float blur_factor = effect.params1.x;
            float inset = effect.params1.y;
            float size = effect.params1.z;
            float a = FxStrokeColor(d, aa + blur_factor, size, inset);
            result = mix(result, color, a);
        } break;

        case Effect_OuterShadow: {
            vec4 color = effect.params0;
            vec2 offset = effect.params1.xy;
            float blur_factor = effect.params1.z;

            float shadow;
            if (offset != vec2(0)) {
                shadow = EvalSDF(p - offset);
            } else {
                shadow = d;
            }

            float a = FxSolidColor(shadow, aa + blur_factor);

            result = mix(result, color, a);
        } break;

        case Effect_InnerShadow: {
            vec4 color = effect.params0;
            vec2 offset = effect.params1.xy;
            float blur_factor = effect.params1.z;

            float shadow;
            if (offset != vec2(0)) {
                shadow = EvalSDF(p - offset);
            } else {
                shadow = d;
            }

            float a = FxSolidColor(-shadow, aa + blur_factor) * FxSolidColor(d, aa);

            result = mix(result, color, a);
        } break;
        }
    }

    return result;
}

void main() {
    vec2 p = gl_FragCoord.xy - in_position;

    float d = EvalSDF(p);

    out_color = EvalEffects(p, d);
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
    defer g_shapes_to_draw.count = 0;

    instances_buffer : [..]ShaderSDInstance;
    defer array_free(instances_buffer);
    shapes_buffer : [..]ShaderSDShape;
    defer array_free(shapes_buffer);
    effects_buffer : [..]ShaderEffect;
    defer array_free(effects_buffer);

    for g_shapes_to_draw {
        instance := array_add(*instances_buffer);
        instance.position = it.position;
        instance.bounds = GetBounds(it.shape);
        instance.first_shape_index = xx shapes_buffer.count;
        instance.num_shapes = FlattenShapes(it.shape, *shapes_buffer);
        instance.first_effect_index = xx effects_buffer.count;
        instance.num_effects = xx it.effects.count;

        for fx : it.effects {
            effect := array_add(*effects_buffer);
            effect.kind = xx fx.kind;

            if #complete fx.kind == {
            case .SolidColor;
                effect.params0[0] = fx.solid_color.color.x;
                effect.params0[1] = fx.solid_color.color.y;
                effect.params0[2] = fx.solid_color.color.z;
                effect.params0[3] = fx.solid_color.color.w;
                effect.params1[0] = fx.solid_color.blur_factor;

            case .StrokeColor;
                effect.params0[0] = fx.stroke_color.color.x;
                effect.params0[1] = fx.stroke_color.color.y;
                effect.params0[2] = fx.stroke_color.color.z;
                effect.params0[3] = fx.stroke_color.color.w;
                effect.params1[0] = fx.stroke_color.blur_factor;
                effect.params1[1] = fx.stroke_color.inset;
                effect.params1[2] = fx.stroke_color.size;

            case .InnerShadow; #through;
            case .OuterShadow;
                effect.params0[0] = fx.outer_shadow.color.x;
                effect.params0[1] = fx.outer_shadow.color.y;
                effect.params0[2] = fx.outer_shadow.color.z;
                effect.params0[3] = fx.outer_shadow.color.w;
                effect.params1[0] = fx.outer_shadow.offset.x;
                effect.params1[1] = fx.outer_shadow.offset.y;
                effect.params1[2] = fx.outer_shadow.blur_factor;
            }
        }
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
    glBindBufferRange(GL_SHADER_STORAGE_BUFFER, 2, buffer_handle, xx effects_offset, xx effects_size);

    glBindVertexArray(g_dummy_vao);

    glDrawArraysInstanced(GL_TRIANGLES, 0, 6, xx instances_buffer.count);
}
