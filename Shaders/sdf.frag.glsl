#define Eval_Stack_Size 32

struct Shape {
    uint kind;
    vec4 params0;
    vec4 params1;
};

#define Shape_CirclePrimitive 0
#define Shape_BoxPrimitive 1
#define Shape_TrianglePrimitive 2
#define Shape_TexturePrimitive 3

#define Shape_UnionOperation 200
#define Shape_SmoothUnionOperation 201
#define Shape_SubtractionOperation 202
#define Shape_SmoothSubtractionOperation 203
#define Shape_IntersectionOperation 204
#define Shape_SmoothIntersectionOperation 205
#define Shape_InflateOperation 206
#define Shape_OnionOperation 207
#define Shape_MorphOperation 208
#define Shape_TransformOperation 209

struct Effect {
    uint kind;
    uint params00;
    uint params01;
    uint params02;
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
uniform vec2 u_viewport_size;
uniform sampler2D u_texture;

layout(location=0) in vec2 in_position;
layout(location=1) in flat uint in_first_shape_index;
layout(location=2) in flat uint in_num_shapes;
layout(location=3) in flat uint in_first_effect_index;
layout(location=4) in flat uint in_num_effects;
layout(location=5) in flat uint in_first_clip_shape_index;
layout(location=6) in flat uint in_num_clip_shapes;

layout(location=0) out vec4 out_color;

float EvalSDF(vec2 p, uint first_shape_index, uint num_shapes) {
    float values[Eval_Stack_Size];
    uint value_index = 0;

    uint shape_index = first_shape_index;
    uint last_shape = first_shape_index + num_shapes;
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

        case Shape_TexturePrimitive: {
            vec4 uvs = shape.params0;
            vec2 size = shape.params1.xy;
            vec2 dist_range = shape.params1.zw;

            values[value_index] = PrimTexture(p, u_texture, size, uvs, dist_range);
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

        case Shape_InflateOperation: {
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
        return 0;
    }

    return values[value_index - 1];
}

vec4 EvalEffects(vec2 p, float d) {
    float aa = length(vec2(dFdx(p.x), dFdy(p.y))) * 0.5;

    vec4 result = vec4(0);

    uint effect_index = in_first_effect_index;
    uint last_effect = in_first_effect_index + in_num_effects;
    while (effect_index < last_effect) {
        Effect effect = u_effects[effect_index];
        effect_index += 1;

        switch (effect.kind) {
        case Effect_SolidColor: {
            vec4 color = ColorVec4(effect.params00);
            float blur_factor = effect.params1.x;
            float a = FxSolidColor(d, aa + blur_factor);
            result = mix(result, color, a);
        } break;

        case Effect_StrokeColor: {
            vec4 color = ColorVec4(effect.params00);
            float blur_factor = effect.params1.x;
            float inset = effect.params1.y;
            float size = effect.params1.z;
            float a = FxStrokeColor(d, aa + blur_factor, size, inset);
            result = mix(result, color, a);
        } break;

        case Effect_OuterShadow: {
            vec4 color = ColorVec4(effect.params00);
            vec2 offset = effect.params1.xy;
            float blur_factor = effect.params1.z;

            float shadow;
            if (offset != vec2(0)) {
                shadow = EvalSDF(p - offset, in_first_shape_index, in_num_shapes);
            } else {
                shadow = d;
            }

            float a = FxSolidColor(shadow, aa + blur_factor);

            result = mix(result, color, a);
        } break;

        case Effect_InnerShadow: {
            vec4 color = ColorVec4(effect.params00);
            vec2 offset = effect.params1.xy;
            float blur_factor = effect.params1.z;

            float shadow;
            if (offset != vec2(0)) {
                shadow = EvalSDF(p - offset, in_first_shape_index, in_num_shapes);
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
    vec2 p = gl_FragCoord.xy;
    p.y = u_viewport_size.y - p.y;

    float d = EvalSDF(p - in_position, in_first_shape_index, in_num_shapes);

    out_color = EvalEffects(p - in_position, d);

    float clip = EvalSDF(p, in_first_clip_shape_index, in_num_clip_shapes);
    float clip_a = FxSolidColor(clip, 0);

    out_color *= clip_a;
}
