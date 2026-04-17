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
uniform vec2 u_viewport_size;

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
    vec2 p = gl_FragCoord.xy;
    p.y = u_viewport_size.y - p.y;
    p -= in_position;

    float d = EvalSDF(p);

    out_color = EvalEffects(p, d);
}
