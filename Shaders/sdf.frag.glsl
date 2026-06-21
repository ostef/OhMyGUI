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
#define Shape_SubtractionOperation 201
#define Shape_IntersectionOperation 202
#define Shape_InflateOperation 203
#define Shape_OnionOperation 204
#define Shape_MorphOperation 205
#define Shape_TransformOperation 206

layout(binding=0, std430) readonly buffer ClipData {
    ClipBox u_clip_boxes[];
};
layout(binding=4, std430) readonly buffer DrawingData {
    ShapeDrawing u_shape_drawings[];
};
layout(binding=5, std430) readonly buffer ShapeData {
    Shape u_shapes[];
};
uniform vec2 u_viewport_size;

layout(location=0) in flat uint in_shape_drawing_index;

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

        case Shape_UnionOperation: {
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
            float k = shape.params0.x;
            value_index -= 2;

            values[value_index] = OpSmoothSubtraction(a, b, k);
            value_index += 1;
        } break;

        case Shape_IntersectionOperation: {
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

void main() {
    vec2 p = gl_FragCoord.xy;
    p.y = u_viewport_size.y - p.y;

    float aa = length(vec2(dFdx(p.x), dFdy(p.y))) * 0.5;

    ShapeDrawing drawing = u_shape_drawings[in_shape_drawing_index];

    float border_size = drawing.border_size_and_inset.x;
    float border_inset = drawing.border_size_and_inset.y;
    vec4 background_color = ColorVec4(drawing.background_color);
    vec4 border_color = ColorVec4(drawing.border_color);
    vec4 outer_shadow_color = ColorVec4(drawing.outer_shadow_color);
    vec2 outer_shadow_offset = drawing.outer_shadow_offset;
    float outer_shadow_blur = drawing.outer_shadow_blur;

    float d = EvalSDF(p - drawing.position, drawing.first_shape_index, drawing.num_shapes);

    out_color = vec4(0);

    if (outer_shadow_color.a > 0) {
        float shadow_d;
        if (outer_shadow_offset != vec2(0)) {
            shadow_d = EvalSDF(p - drawing.position - outer_shadow_offset, drawing.first_shape_index, drawing.num_shapes);
        } else {
            shadow_d = d;
        }

        float outer_shadow = FxSolidColor(shadow_d, aa + outer_shadow_blur);
        out_color = BlendEffect(out_color, outer_shadow_color, outer_shadow);
    }

    float background = FxSolidColor(d, aa);
    out_color = BlendEffect(out_color, background_color, background);

    float border = FxStrokeColor(d, aa, border_size, border_inset);
    out_color = BlendEffect(out_color, border_color, border);

    if (drawing.clip_box_index >= 0) {
        ClipBox clip = u_clip_boxes[drawing.clip_box_index];
        vec2 clip_size = clip.bounds.zw - clip.bounds.xy;
        vec2 clip_position = (clip.bounds.xy + clip.bounds.zw) * 0.5;
        float clip_d = PrimBox(p - clip_position, clip_size, clip.corner_radiuses);
        float clip_a = FxSolidColor(clip_d, aa);

        out_color *= clip_a;
    }
}
