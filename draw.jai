TextureHandle :: u64;

ClipBox :: struct {
    bounds : Vec4f;
    corner_radiuses : Vec4f;
}

DrawCall :: struct {
    Texture :: struct {
        handle : TextureHandle;
        has_white_px : bool;
    }

    texture : Texture;
    index_offset : u32;
    num_indices : u32;
}

Vertex :: struct {
    position : Vec2f;
    tex_coords : Vec2f;
    color : RGBA8;
    sdf_texture_blur : float;
    sdf_texture_range : float;
    clip_box_index : s32;
}

DrawList :: struct {
    draw_calls : [..]DrawCall;
    clip_boxes : [..]ClipBox;
    clip_box_stack : [..]s32;
    vertices : [..]Vertex;
    indices : [..]u32;
    path : [..]PathPoint;
    anti_alias_margin := 1.0;

    gpu_buffer_clip_boxes_offset : u32;
    gpu_buffer_vertices_offset : u32;
    gpu_buffer_indices_offset : u32;
}

InitDrawList :: (draw_list : *DrawList) {
    draw_list.draw_calls.allocator = context.allocator;
    draw_list.clip_boxes.allocator = context.allocator;
    draw_list.clip_box_stack.allocator = context.allocator;
    draw_list.vertices.allocator = context.allocator;
    draw_list.indices.allocator = context.allocator;
    draw_list.path.allocator = context.allocator;
}

DestroyDrawList :: (draw_list : *DrawList) {
    array_reset(*draw_list.draw_calls);
    array_reset(*draw_list.clip_boxes);
    array_reset(*draw_list.clip_box_stack);
    array_reset(*draw_list.vertices);
    array_reset(*draw_list.indices);
    array_reset(*draw_list.path);
    draw_list.* = .{};
}

ClearDrawList :: (draw_list : *DrawList) {
    array_reset_keeping_memory(*draw_list.draw_calls);
    array_reset_keeping_memory(*draw_list.clip_boxes);
    array_reset_keeping_memory(*draw_list.clip_box_stack);
    array_reset_keeping_memory(*draw_list.vertices);
    array_reset_keeping_memory(*draw_list.indices);
    array_reset_keeping_memory(*draw_list.path);

    draw_list.gpu_buffer_clip_boxes_offset = 0;
    draw_list.gpu_buffer_vertices_offset = 0;
    draw_list.gpu_buffer_indices_offset = 0;
}

GetCurrentDrawCall :: (draw_list : *DrawList) -> *DrawCall {
    if draw_list.draw_calls.count <= 0 {
        return null;
    }
    return *draw_list.draw_calls[draw_list.draw_calls.count - 1];
}

GetCurrentClipBoxIndex :: (draw_list : *DrawList) -> s32 #no_abc {
    if draw_list.clip_box_stack.count <= 0 {
        return -1;
    }
    return draw_list.clip_box_stack[draw_list.clip_box_stack.count - 1];
}

ClipBoxAgainstBox :: (a : ClipBox, b : ClipBox) -> ClipBox {
    a_corners := Vec2f.[
        .{a.bounds.x, a.bounds.y},
        .{a.bounds.z, a.bounds.y},
        .{a.bounds.x, a.bounds.w},
        .{a.bounds.z, a.bounds.w},
    ];
    a_inner_corners := Vec2f.[
        .{a.bounds.x + a.corner_radiuses.x, a.bounds.y + a.corner_radiuses.x},
        .{a.bounds.z - a.corner_radiuses.y, a.bounds.y + a.corner_radiuses.y},
        .{a.bounds.x + a.corner_radiuses.z, a.bounds.w - a.corner_radiuses.z},
        .{a.bounds.z - a.corner_radiuses.w, a.bounds.w - a.corner_radiuses.w},
    ];
    b_corners := Vec2f.[
        .{b.bounds.x, b.bounds.y},
        .{b.bounds.z, b.bounds.y},
        .{b.bounds.x, b.bounds.w},
        .{b.bounds.z, b.bounds.w},
    ];
    b_inner_corners := Vec2f.[
        .{b.bounds.x + b.corner_radiuses.x, b.bounds.y + b.corner_radiuses.x},
        .{b.bounds.z - b.corner_radiuses.y, b.bounds.y + b.corner_radiuses.y},
        .{b.bounds.x + b.corner_radiuses.z, b.bounds.w - b.corner_radiuses.z},
        .{b.bounds.z - b.corner_radiuses.w, b.bounds.w - b.corner_radiuses.w},
    ];
    new_corner_radiuses := a.corner_radiuses;

    clipped_bounds := ClipRect(a.bounds, b.bounds);

    for i : 0..3 {
        b_corner_rect := Vec4f.{
            xy=min(b_corners[i], b_inner_corners[i]),
            zw=max(b_corners[i], b_inner_corners[i])
        };

        if RectIntersectsRect(b_corner_rect, a.bounds) {
            new_corner_radiuses[i] = max(new_corner_radiuses[i], b.corner_radiuses[i]);
        }
    }

    return .{bounds=clipped_bounds, corner_radiuses=new_corner_radiuses};
} @Profile

ReserveVertices :: (draw_list : *DrawList, count : int) {
    if draw_list.vertices.count + count <= draw_list.vertices.allocated {
        return;
    }

    array_reserve(*draw_list.vertices, draw_list.vertices.count + count);
}

PushVertex :: inline (draw_list : *DrawList) -> *Vertex {
    vertex := array_add(*draw_list.vertices);
    vertex.clip_box_index = GetCurrentClipBoxIndex(draw_list);
    return vertex;
}

GetCurrentIndex :: inline (draw_list : *DrawList) -> u32 {
    return xx draw_list.vertices.count;
}

PushIndex :: inline (draw_list : *DrawList, value : u32) {
    draw_call := GetCurrentDrawCall(draw_list);
    if !draw_call {
        draw_call = array_add(*draw_list.draw_calls);
    }

    draw_call.num_indices += 1;

    array_add(*draw_list.indices, value);
}

PushIndices :: (draw_list : *DrawList, count : u32) -> []u32 {
    draw_call := GetCurrentDrawCall(draw_list);
    if !draw_call {
        draw_call = array_add(*draw_list.draw_calls);
    }

    draw_call.num_indices += count;

    if draw_list.indices.count + count > draw_list.indices.allocated {
        array_reserve(*draw_list.indices, draw_list.indices.allocated + count);
    }

    data := draw_list.indices.data + draw_list.indices.count;
    draw_list.indices.count += count;

    return .{data=data, count=count};
}

PushDisableClipBox :: inline (draw_list : *DrawList) {
    array_add(*draw_list.clip_box_stack, -1);
}

PushClipBox :: (draw_list : *DrawList, bounds : Vec4f, corner_radiuses : Vec4f = .{}, global := false) {
    box := array_add(*draw_list.clip_boxes);
    box.bounds = bounds;
    box.corner_radiuses = corner_radiuses;

    if !global {
        current_index := GetCurrentClipBoxIndex(draw_list);
        if current_index >= 0 {
            current := draw_list.clip_boxes[current_index];
            box.* = ClipBoxAgainstBox(box, current);
        }
    }

    array_add(*draw_list.clip_box_stack, xx (draw_list.clip_boxes.count - 1));
}

PopClipBox :: (draw_list : *DrawList) {
    pop(*draw_list.clip_box_stack);
}

IsClipped :: (draw_list : *DrawList, bounds : Vec4f) -> bool {
    index := GetCurrentClipBoxIndex(draw_list);
    if index < 0 {
        return false;
    }

    clipped := ClipRect(bounds, draw_list.clip_boxes[index].bounds);
    return clipped.x > clipped.z || clipped.y > clipped.w;
}

PushDrawCall :: (draw_list : *DrawList) -> *DrawCall {
    new : *DrawCall;
    if draw_list.draw_calls.count > 0 {
        current := GetCurrentDrawCall(draw_list).*;
        new = array_add(*draw_list.draw_calls);
        new.* = current;
    } else {
        new = array_add(*draw_list.draw_calls);
    }

    new.index_offset = xx draw_list.indices.count;
    new.num_indices = 0;

    return new;
}

SetTexture :: (draw_list : *DrawList, texture : TextureHandle, has_white_px : bool = false) -> previous : DrawCall.Texture {
    return SetTexture(draw_list, .{texture, has_white_px});
}

SetTexture :: (draw_list : *DrawList, texture : DrawCall.Texture) -> previous : DrawCall.Texture {
    draw_call := GetCurrentDrawCall(draw_list);
    previous := ifx draw_call then draw_call.texture;

    if draw_call && texture.handle == 0 && previous.has_white_px {
        return previous;
    }

    if !draw_call
    || (draw_call.num_indices > 0 && (draw_call.texture.handle != texture.handle || draw_call.texture.has_white_px != texture.has_white_px)) {
        draw_call = PushDrawCall(draw_list);
    }

    draw_call.texture = texture;
    if draw_call.texture.handle == 0 {
        draw_call.texture.has_white_px = true;
    }

    return previous;
}

DrawRect :: inline (
    draw_list : *DrawList,
    bounds : Vec4f,
    color : RGBA8,
    corner_radiuses : Vec4f = .{0,0,0,0},
    uv_bounds : Vec4f = .{0,0,0,0},
    blur_size := 0.0
) {
    DrawRect(draw_list, bounds, color, color, color, color, corner_radiuses, uv_bounds, blur_size);
}

DrawRect :: inline (
    draw_list : *DrawList,
    bounds : Vec4f,
    colors : BoxColors,
    corner_radiuses : Vec4f = .{0,0,0,0},
    uv_bounds : Vec4f = .{0,0,0,0},
    blur_size := 0.0
) {
    DrawRect(draw_list, bounds, colors.top_left, colors.top_right, colors.bottom_left, colors.bottom_right, corner_radiuses, uv_bounds, blur_size);
}

DrawRect :: (
    draw_list : *DrawList,
    bounds : Vec4f,
    color_top_left : RGBA8,
    color_top_right : RGBA8,
    color_bottom_left : RGBA8,
    color_bottom_right : RGBA8,
    corner_radiuses : Vec4f = .{0,0,0,0},
    uv_bounds : Vec4f = .{0,0,0,0},
    blur_size := 0.0
) #no_abc {
    PushVertex :: (draw_list : *DrawList, position : Vec2f) -> *Vertex #expand {
        tx := InverseLerp(`bounds.x, `bounds.z, position.x);
        ty := InverseLerp(`bounds.y, `bounds.w, position.y);
        tx = clamp(tx, 0, 1);
        ty = clamp(ty, 0, 1);

        v := PushVertex(draw_list);
        v.position = position;

        a := MixColors(`color_top_left, `color_top_right, tx);
        b := MixColors(`color_bottom_left, `color_bottom_right, tx);

        v.color = MixColors(a, b, ty);
        v.tex_coords = .{lerp(uv_bounds.x, uv_bounds.z, tx), lerp(uv_bounds.y, uv_bounds.w, ty)};

        return v;
    }

    if IsClipped(draw_list, bounds) {
        return;
    }

    if (color_top_left & 0xff) == 0
    && (color_top_right & 0xff) == 0
    && (color_bottom_left & 0xff) == 0
    && (color_bottom_right & 0xff) == 0 {
        return;
    }

    blur_size = max(blur_size, draw_list.anti_alias_margin, 0.0);

    half_size := (bounds.zw - bounds.xy) * 0.5;
    max_radius := min(half_size.x, half_size.y);

    // We don't use path + DrawConvexPolygon here because this produces geometry
    // that does not work well with gradients
    // What we do instead is create stacked horizontal strips from top to bottom that follow the rect's outline
    radiuses := Vec4f.{
        max(min(corner_radiuses.x, max_radius), 0),
        max(min(corner_radiuses.y, max_radius), 0),
        max(min(corner_radiuses.z, max_radius), 0),
        max(min(corner_radiuses.w, max_radius), 0),
    };

    top_left := bounds.xy;
    top_left.x += radiuses.x + blur_size * 0.5;
    top_left.y += radiuses.x + blur_size * 0.5;

    top_right := Vec2f.{bounds.z, bounds.y};
    top_right.x -= radiuses.y + blur_size * 0.5;
    top_right.y += radiuses.y + blur_size * 0.5;

    bottom_left := Vec2f.{bounds.x, bounds.w};
    bottom_left.x += radiuses.z + blur_size * 0.5;
    bottom_left.y -= radiuses.z + blur_size * 0.5;

    bottom_right := bounds.zw;
    bottom_right.x -= radiuses.w + blur_size * 0.5;
    bottom_right.y -= radiuses.w + blur_size * 0.5;

    PushCornerVertices :: (draw_list : *DrawList, left : Vec2f, right : Vec2f, left_radius : float, right_radius : float, bottom : bool) -> num_segments : int #expand {
        #if #exists(context._Tracy) {
            context._Tracy.ZoneScoped("PushCornerVertices");
        }

        if left_radius <= 0 && right_radius <= 0 {
            n := Vec2f.{-1, -1};
            if bottom {
                n.y = -n.y;
            }

            v := PushVertex(draw_list, left + n * `blur_size);
            SetAlpha(*v.color, 0);

            PushVertex(draw_list, left);
            PushVertex(draw_list, right);

            n.x = -n.x;

            v = PushVertex(draw_list, right + n * `blur_size);
            SetAlpha(*v.color, 0);

            return 0;
        }

        num_segments : int = xx max(
            (left_radius * 0.25 + blur_size) * context.omg.global_polygon_resolution,
            (right_radius * 0.25 + blur_size) * context.omg.global_polygon_resolution,
            3
        );

        left_dominant := left_radius > right_radius;
        start_angle : float = ---;
        dominant_angle_sign : float = ---;
        dominant_radius, non_dominant_radius : float = ---;
        dominant_center, non_dominant_center : Vec2f = ---;
        if left_dominant {
            start_angle = ifx bottom then PI else PI * 0.5;
            dominant_angle_sign = 1;
            dominant_radius = left_radius;
            non_dominant_radius = right_radius;
            dominant_center = left;
            non_dominant_center = right;
        } else {
            start_angle = ifx bottom then 0.0 else PI * 0.5;
            dominant_angle_sign = -1;
            dominant_radius = right_radius;
            non_dominant_radius = left_radius;
            dominant_center = right;
            non_dominant_center = left;
        }

        for i : 0..num_segments {
            #if #exists(context._Tracy) {
                context._Tracy.ZoneScoped("Iterate");
            }

            t := i / cast(float, num_segments);
            angle := start_angle + t * dominant_angle_sign * PI * 0.5;
            dominant_p := SampleCosSinTable(-angle);

            dominant_position := dominant_center + dominant_p * dominant_radius;
            non_dominant_p : Vec2f = ---;
            non_dominant_position : Vec2f = ---;

            if non_dominant_radius <= 0 {
                non_dominant_position = .{
                    non_dominant_center.x,
                    dominant_position.y,
                };

                if bottom && i == num_segments {
                    non_dominant_p = .{dominant_angle_sign, 1};
                } else if !bottom && i == 0 {
                    non_dominant_p = .{dominant_angle_sign, -1};
                } else {
                    non_dominant_p = .{dominant_angle_sign, 0};
                }
            } else if left_radius == right_radius {
                non_dominant_p = dominant_p;
                non_dominant_p.x = -non_dominant_p.x;
                non_dominant_position = .{
                    non_dominant_center.x + non_dominant_p.x * non_dominant_radius,
                    dominant_position.y,
                };
            } else {
                sin_y := ifx bottom
                    then InverseLerp(non_dominant_center.y, bounds.w, dominant_position.y)
                    else InverseLerp(non_dominant_center.y, bounds.y, dominant_position.y);
                sin_y = clamp(sin_y, 0, 1);
                angle := asin(sin_y);
                non_dominant_p = SampleCosSinTable(angle);
                non_dominant_p.x *= dominant_angle_sign;
                if !bottom {
                    non_dominant_p.y = -non_dominant_p.y;
                }

                non_dominant_position = .{
                    non_dominant_center.x + non_dominant_p.x * non_dominant_radius,
                    dominant_position.y,
                };
            }

            #if #exists(context._Tracy) {
                context._Tracy.ZoneScoped("Push vertices");
            }

            if left_dominant {
                // Outer
                v := PushVertex(draw_list, dominant_position + dominant_p * blur_size);
                SetAlpha(*v.color, 0);

                // Inner
                PushVertex(draw_list, dominant_position);
                PushVertex(draw_list, non_dominant_position);

                // Outer
                v = PushVertex(draw_list, non_dominant_position + non_dominant_p * blur_size);
                SetAlpha(*v.color, 0);
            } else {
                // Outer
                v := PushVertex(draw_list, non_dominant_position + non_dominant_p * blur_size);
                SetAlpha(*v.color, 0);

                // Inner
                PushVertex(draw_list, non_dominant_position);
                PushVertex(draw_list, dominant_position);

                // Outer
                v = PushVertex(draw_list, dominant_position + dominant_p * blur_size);
                SetAlpha(*v.color, 0);
            }
        }

        // Top/bottom blur margins
        {
            n := Vec2f.{0, ifx bottom then blur_size + left_radius else -blur_size - left_radius};
            if left_radius <= 0 {
                n.x = -blur_size - left_radius;
            }
            v := PushVertex(draw_list, left + n);
            SetAlpha(*v.color, 0);

            n = Vec2f.{0, ifx bottom then blur_size + right_radius else -blur_size - right_radius};
            if right_radius <= 0 {
                n.x = blur_size + right_radius;
            }
            v = PushVertex(draw_list, right + n);
            SetAlpha(*v.color, 0);

        }

        return num_segments;
    }

    first_top_vertex := GetCurrentIndex(draw_list);
    num_top_segments := PushCornerVertices(draw_list, top_left, top_right, radiuses.x, radiuses.y, bottom=false);

    last_top_left_outer_vertex := cast(u32, first_top_vertex + num_top_segments * 4);
    last_top_left_inner_vertex := last_top_left_outer_vertex + 1;
    last_top_right_inner_vertex := last_top_left_inner_vertex + 1;
    last_top_right_outer_vertex := last_top_right_inner_vertex + 1;
    top_margin_left := last_top_right_outer_vertex + 1;
    top_margin_right := top_margin_left + 1;

    if num_top_segments > 0 {
        indices := PushIndices(draw_list, cast(u32, num_top_segments) * 18 + 6);
        for i : 0..cast(u32, num_top_segments - 1) {
            outer_left := first_top_vertex + i * 4;
            inner_left := outer_left + 1;
            inner_right := inner_left + 1;
            outer_right := inner_right + 1;

            indices[0] = outer_left;
            indices[1] = outer_left + 4;
            indices[2] = inner_left;

            indices[3] = inner_left;
            indices[4] = outer_left + 4;
            indices[5] = inner_left + 4;

            indices[6] = inner_left;
            indices[7] = inner_left + 4;
            indices[8] = inner_right;

            indices[9] = inner_right;
            indices[10] = inner_left + 4;
            indices[11] = inner_right + 4;

            indices[12] = inner_right;
            indices[13] = inner_right + 4;
            indices[14] = outer_right;

            indices[15] = outer_right;
            indices[16] = inner_right + 4;
            indices[17] = outer_right + 4;

            indices.data += 18;
            indices.count -= 18;
        }

        // Top margin
        indices[0] = top_margin_left;
        indices[1] = first_top_vertex + 1;
        indices[2] = top_margin_right;

        indices[3] = top_margin_right;
        indices[4] = first_top_vertex + 1;
        indices[5] = first_top_vertex + 2;
    } else {
        // Top margin
        PushIndex(draw_list, first_top_vertex);
        PushIndex(draw_list, first_top_vertex + 3);
        PushIndex(draw_list, first_top_vertex + 1);

        PushIndex(draw_list, first_top_vertex + 1);
        PushIndex(draw_list, first_top_vertex + 3);
        PushIndex(draw_list, first_top_vertex + 2);
    }

    first_bottom_vertex := GetCurrentIndex(draw_list);
    num_bottom_segments := PushCornerVertices(draw_list, bottom_left, bottom_right, radiuses.z, radiuses.w, bottom=true);

    first_bottom_left_outer_vertex := cast(u32, first_bottom_vertex);
    first_bottom_left_inner_vertex := first_bottom_left_outer_vertex + 1;
    first_bottom_right_inner_vertex := first_bottom_left_inner_vertex + 1;
    first_bottom_right_outer_vertex := first_bottom_right_inner_vertex + 1;
    last_bottom_left_inner_vertex := cast(u32, first_bottom_vertex + num_bottom_segments * 4) + 1;
    last_bottom_right_inner_vertex := cast(u32, first_bottom_vertex + num_bottom_segments * 4) + 2;
    bottom_margin_left := last_bottom_right_inner_vertex + 2;
    bottom_margin_right := bottom_margin_left + 1;

    indices := PushIndices(draw_list, 18);

    indices[0] = last_top_left_outer_vertex;
    indices[1] = first_bottom_left_outer_vertex;
    indices[2] = last_top_left_inner_vertex;

    indices[3] = last_top_left_inner_vertex;
    indices[4] = first_bottom_left_outer_vertex;
    indices[5] = first_bottom_left_inner_vertex;

    indices[6] = last_top_left_inner_vertex;
    indices[7] = first_bottom_left_inner_vertex;
    indices[8] = last_top_right_inner_vertex;

    indices[9] = last_top_right_inner_vertex;
    indices[10] = first_bottom_left_inner_vertex;
    indices[11] = first_bottom_right_inner_vertex;

    indices[12] = last_top_right_inner_vertex;
    indices[13] = first_bottom_right_inner_vertex;
    indices[14] = last_top_right_outer_vertex;

    indices[15] = last_top_right_outer_vertex;
    indices[16] = first_bottom_right_inner_vertex;
    indices[17] = first_bottom_right_outer_vertex;

    if num_bottom_segments > 0 {
        indices := PushIndices(draw_list, cast(u32, num_bottom_segments) * 18 + 6);
        for i : 0..cast(u32, num_bottom_segments - 1) {
            outer_left := first_bottom_vertex + i * 4;
            inner_left := outer_left + 1;
            inner_right := inner_left + 1;
            outer_right := inner_right + 1;

            indices[0] = outer_left;
            indices[1] = outer_left + 4;
            indices[2] = inner_left;

            indices[3] = inner_left;
            indices[4] = outer_left + 4;
            indices[5] = inner_left + 4;

            indices[6] = inner_left;
            indices[7] = inner_left + 4;
            indices[8] = inner_right;

            indices[9] = inner_right;
            indices[10] = inner_left + 4;
            indices[11] = inner_right + 4;

            indices[12] = inner_right;
            indices[13] = inner_right + 4;
            indices[14] = outer_right;

            indices[15] = outer_right;
            indices[16] = inner_right + 4;
            indices[17] = outer_right + 4;

            indices.data += 18;
            indices.count -= 18;
        }

        // Bottom margin
        indices[0] = last_bottom_left_inner_vertex;
        indices[1] = bottom_margin_left;
        indices[2] = last_bottom_right_inner_vertex;

        indices[3] = last_bottom_right_inner_vertex;
        indices[4] = bottom_margin_left;
        indices[5] = bottom_margin_right;
    } else {
        // Bottom margin
        PushIndex(draw_list, first_bottom_vertex);
        PushIndex(draw_list, first_bottom_vertex + 3);
        PushIndex(draw_list, first_bottom_vertex + 1);

        PushIndex(draw_list, first_bottom_vertex + 1);
        PushIndex(draw_list, first_bottom_vertex + 3);
        PushIndex(draw_list, first_bottom_vertex + 2);
    }
} @Profile

DrawRectOutline :: inline (
    draw_list : *DrawList,
    bounds : Vec4f,
    color : RGBA8,
    thickness : float,
    corner_radiuses : Vec4f = .{0,0,0,0},
    uv_bounds : Vec4f = .{0,0,0,0},
    blur_size := 0.0,
    blur_sides := LineSides.All
) {
    DrawRectOutline(draw_list, bounds, color, color, color, color, thickness, corner_radiuses, uv_bounds, blur_size, blur_sides);
}

DrawRectOutline :: inline (
    draw_list : *DrawList,
    bounds : Vec4f,
    colors : BoxColors,
    thickness : float,
    corner_radiuses : Vec4f = .{0,0,0,0},
    uv_bounds : Vec4f = .{0,0,0,0},
    blur_size := 0.0,
    blur_sides := LineSides.All
) {
    DrawRectOutline(draw_list, bounds, colors.top_left, colors.top_right, colors.bottom_left, colors.bottom_right, thickness, corner_radiuses, uv_bounds, blur_size, blur_sides);
}

DrawRectOutline :: (
    draw_list : *DrawList,
    bounds : Vec4f,
    color_top_left : RGBA8,
    color_top_right : RGBA8,
    color_bottom_left : RGBA8,
    color_bottom_right : RGBA8,
    thickness : float,
    corner_radiuses : Vec4f = .{0,0,0,0},
    uv_bounds : Vec4f = .{0,0,0,0},
    blur_size := 0.0,
    blur_sides := LineSides.All
) {
    if IsClipped(draw_list, bounds) {
        return;
    }

    if (color_top_left & 0xff) == 0
    && (color_top_right & 0xff) == 0
    && (color_bottom_left & 0xff) == 0
    && (color_bottom_right & 0xff) == 0 {
        return;
    }

    PathPushRoundedRect(*draw_list.path, bounds, corner_radiuses);

    get_color_data : struct {
        points : []PathPoint;
        bounds : Vec4f;
        colors : BoxColors;
    } = .{
        points=draw_list.path,
        bounds=bounds,
        colors.top_left=color_top_left,
        colors.top_right=color_top_right,
        colors.bottom_left=color_bottom_left,
        colors.bottom_right=color_bottom_right,
    };

    GetColor :: (index : int, data : *void) -> RGBA8 {
        using _ := cast(*type_of(get_color_data), data);

        point := points[index];
        tx := InverseLerp(bounds.x, bounds.z, point.position.x);
        ty := InverseLerp(bounds.y, bounds.w, point.position.y);
        return GetColor(colors, tx, ty);
    }

    DrawPolygonLine(draw_list, draw_list.path, true, thickness, GetColor, *get_color_data, blur_size, blur_sides);
    array_reset_keeping_memory(*draw_list.path);
} @Profile

BoxDrawing :: struct {
    bounds : Vec4f;
    uv_bounds : Vec4f;
    corner_radiuses : Vec4f;
    background_colors : BoxColors;
    border_colors : BoxColors;
    border_size : float;
    border_inset : float;
    outer_shadow_color : RGBA8;
    outer_shadow_offset : Vec2f;
    outer_shadow_size : float;
    inner_shadow_color : RGBA8;
    inner_shadow_size : float;
    clip_box_index : s32;
}

DrawBox :: inline (draw_list : *DrawList, box : BoxDrawing, texture : TextureHandle = 0) {
    // Outer shadow
    DrawRect(
        draw_list,
        MoveRect(box.bounds, box.outer_shadow_offset),
        box.outer_shadow_color,
        box.corner_radiuses,
        box.uv_bounds,
        box.outer_shadow_size,
    );

    // Background
    prev_texture := SetTexture(draw_list, texture);

    DrawRect(
        draw_list,
        box.bounds,
        box.background_colors,
        box.corner_radiuses,
        box.uv_bounds
    );

    SetTexture(draw_list, prev_texture);

    // Inner shadow
    DrawRectOutline(
        draw_list,
        box.bounds,
        box.inner_shadow_color,
        0,
        box.corner_radiuses,
        box.uv_bounds,
        box.inner_shadow_size,
        .Interior,
    );

    // Border
    border_inset := Vec4f.{-1,-1,-1,-1} * (box.border_size * 0.5 + box.border_inset);
    DrawRectOutline(
        draw_list,
        InflateRect(box.bounds, border_inset),
        box.border_colors,
        box.border_size,
        box.corner_radiuses,
        box.uv_bounds
    );
} @Profile

DrawCircle :: (
    draw_list : *DrawList,
    center : Vec2f,
    radius : float,
    color : RGBA8,
    blur_size := 0.0,
) {
    if IsClipped(draw_list, Vec4f.{center.x - radius, center.y - radius, center.x + radius, center.y + radius}) {
        return;
    }

    if (color & 0xff) == 0 {
        return;
    }

    PathPushArc(*draw_list.path, center, radius, 0, 2 * PI);
    DrawConvexPolygon(draw_list, draw_list.path, color, blur_size);
    array_reset_keeping_memory(*draw_list.path);
} @Profile

DrawCircleOutline :: (
    draw_list : *DrawList,
    center : Vec2f,
    radius : float,
    color : RGBA8,
    thickness : float,
    blur_size := 0.0,
    blur_sides := LineSides.All
) {
    if IsClipped(draw_list, Vec4f.{center.x - radius, center.y - radius, center.x + radius, center.y + radius}) {
        return;
    }

    if (color & 0xff) == 0 {
        return;
    }

    PathPushArc(*draw_list.path, center, radius, 0, 2 * PI);
    DrawPolygonLine(draw_list, draw_list.path, true, thickness, color, blur_size, blur_sides);
    array_reset_keeping_memory(*draw_list.path);
} @Profile

DrawLine :: inline (
    draw_list : *DrawList,
    start : Vec2f,
    end : Vec2f,
    thickness : float,
    color : RGBA8,
    blur_size := 0.0
) {
    DrawLine(draw_list, start, end, thickness, color, color, blur_size);
}

DrawLine :: (
    draw_list : *DrawList,
    start : Vec2f,
    end : Vec2f,
    thickness : float,
    start_color : RGBA8,
    end_color : RGBA8,
    blur_size := 0.0
) {
    if (start_color & 0xff) == 0 && (end_color & 0xff) == 0 {
        return;
    }

    dir := end - start;
    length := normalize(*dir);
    normal := Vec2f.{dir.y, -dir.x};

    array_add(*draw_list.path, .{start, normal});
    array_add(*draw_list.path, .{end, normal});

    get_color_data : struct {
        start : RGBA8;
        end : RGBA8;
    } = .{start_color, end_color};

    GetColor :: (index : int, data : *void) -> RGBA8 {
        using _ := cast(*type_of(get_color_data), data);
        return ifx index == 0 then start else end;
    }

    DrawPolygonLine(draw_list, draw_list.path, false, thickness, GetColor, *get_color_data, blur_size);
    array_reset_keeping_memory(*draw_list.path);
} @Profile

DrawSDFGlyph :: (
    draw_list : *DrawList,
    bounds : Vec4f,
    color : RGBA8,
    uv_bounds : Vec4f,
    sdf_range : float,
    blur_amount := 0.0
) {
    DrawSDFGlyph(draw_list, bounds, color, color, color, color, uv_bounds, sdf_range, blur_amount);
}

DrawSDFGlyph :: (
    draw_list : *DrawList,
    bounds : Vec4f,
    color_top_left : RGBA8,
    color_top_right : RGBA8,
    color_bottom_left : RGBA8,
    color_bottom_right : RGBA8,
    uv_bounds : Vec4f,
    sdf_range : float,
    blur_amount := 0.0
) {
    if IsClipped(draw_list, bounds) {
        return;
    }

    if (color_top_left & 0xff) == 0
    && (color_top_right & 0xff) == 0
    && (color_bottom_left & 0xff) == 0
    && (color_bottom_right & 0xff) == 0 {
        return;
    }

    first := GetCurrentIndex(draw_list);

    ReserveVertices(draw_list, 4);
    p0 := PushVertex(draw_list);
    p1 := PushVertex(draw_list);
    p2 := PushVertex(draw_list);
    p3 := PushVertex(draw_list);

    p0.position = bounds.xy;
    p0.tex_coords = uv_bounds.xy;
    p0.color = color_top_left;
    p0.sdf_texture_blur = 1 + blur_amount;
    p0.sdf_texture_range = sdf_range;

    p1.position = .{bounds.z, bounds.y};
    p1.tex_coords = .{uv_bounds.z, uv_bounds.y};
    p1.color = color_top_right;
    p1.sdf_texture_blur = 1 + blur_amount;
    p1.sdf_texture_range = sdf_range;

    p2.position = .{bounds.x, bounds.w};
    p2.tex_coords = .{uv_bounds.x, uv_bounds.w};
    p2.color = color_bottom_left;
    p2.sdf_texture_blur = 1 + blur_amount;
    p2.sdf_texture_range = sdf_range;

    p3.position = bounds.zw;
    p3.tex_coords = uv_bounds.zw;
    p3.color = color_bottom_right;
    p3.sdf_texture_blur = 1 + blur_amount;
    p3.sdf_texture_range = sdf_range;

    PushIndex(draw_list, first);
    PushIndex(draw_list, first + 1);
    PushIndex(draw_list, first + 2);

    PushIndex(draw_list, first + 2);
    PushIndex(draw_list, first + 1);
    PushIndex(draw_list, first + 3);
}

DrawText :: inline (
    draw_list : *DrawList,
    font : *Font,
    position : Vec2f,
    size : float,
    text : string,
    color : RGBA8,
    effects : TextEffects = 0
) {
    DrawWrappedText(
        draw_list,
        font,
        position,
        size,
        text,
        .{FLOAT32_INFINITY, FLOAT32_INFINITY},
        color,
        effects
    );
}

DrawWrappedText :: (
    draw_list : *DrawList,
    font : *Font,
    position : Vec2f,
    size : float,
    text : string,
    bounds : Vec2f,
    color : RGBA8,
    effects : TextEffects = 0
) {
    if !font || (color & 0xff) == 0 {
        return;
    }

    prev_texture := SetTexture(draw_list, font.texture, has_white_px=true);

    sdf_range := font.sdf_range * size;

    iter : TextGlyphIterator;
    iter.font = font;
    iter.font_size = size;
    iter.text = text;
    iter.bounds = bounds;
    for :WordWrap iter {
        glyph_position := position + iter.pen + it.hori_bearing * iter.font_size;
        glyph_position += it.size * iter.font_size * 0.5;

        bounds := Vec4f.{
            xy=glyph_position - it.texture_size * iter.font_size * 0.5,
            zw=glyph_position + it.texture_size * iter.font_size * 0.5,
        };

        DrawSDFGlyph(draw_list, bounds, color, color, color, color, it.uv_rect, sdf_range);
    }

    SetTexture(draw_list, prev_texture);

    if effects {
        ResetPen(*iter);

        underline_thickness := max(font.desired_underline_thickness * size, 1);
        underline_position := font.desired_underline_position * size;
        if underline_thickness == 1 {
            underline_position = ceil(underline_position);
        }

        for :WordWrappedLines iter {
            if effects & .Underline {
                start := it.line_pen_start + position;
                start.y += (underline_position + underline_thickness * 0.5);

                end := it.line_pen_end + position;
                end.y += (underline_position + underline_thickness * 0.5);

                DrawLine(draw_list, start, end, underline_thickness, color, color);
            }

            if effects & .Strikethrough {
                start := it.line_pen_start + position;
                start.y -= font.ascent * 0.35 * size;

                end := it.line_pen_end + position;
                end.y -= font.ascent * 0.35 * size;

                DrawLine(draw_list, start, end, underline_thickness, color, color);
            }
        }
    }
} @Profile

DrawNodeDefault :: (draw_list : *DrawList, node : *Node) -> bool {
    if IsClipped(draw_list, node.rect) {
        return false;
    }

    DrawBox(draw_list, .{
        bounds=node.rect,
        uv_bounds=node.image_uv_bounds,
        corner_radiuses=node.corner_radiuses,
        background_colors=node.background_colors,
        border_colors=node.border_colors,
        border_size=node.border_size,
        border_inset=node.border_inset,
        outer_shadow_color=node.outer_shadow_color,
        outer_shadow_offset=node.outer_shadow_offset,
        outer_shadow_size=node.outer_shadow_size,
        inner_shadow_color=node.inner_shadow_color,
        inner_shadow_size=node.inner_shadow_size,
    }, texture=node.image);

    if node.flags & .WrapText {
        DrawWrappedText(draw_list,
            node.font,
            node.rect.xy,
            node.text_size,
            node.text,
            node.size,
            node.text_color,
            node.text_effects
        );
    } else {
        DrawText(draw_list,
            node.font,
            node.rect.xy,
            node.text_size,
            node.text,
            node.text_color,
            node.text_effects
        );
    }

    return true;
} @Profile

DrawNodes :: (draw_list : *DrawList, node : *Node) {
    draw_children := true;
    if node.draw {
        draw_children = node.draw(draw_list, node);
    }

    if node.num_children > 0 {
        if !(node.flags & .NoClip) {
            if node.flags & .NoPaddedClip {
                PushClipBox(*node.window.draw_list, node.rect, node.corner_radiuses);
            } else {
                bounds := node.rect;
                bounds.xy += ToVec2f(node.padding.xy);
                bounds.zw -= ToVec2f(node.padding.zw);
                PushClipBox(*node.window.draw_list, bounds, node.corner_radiuses);
            }
        }

        for :Children node {
            DrawNodes(draw_list, it);
        }

        if !(node.flags & .NoClip) {
            PopClipBox(*node.window.draw_list);
        }
    }
} @Profile

DrawCheckerboard :: (draw_list : *DrawList, rect : Vec4f, checker_size : float, white : RGBA8, black : RGBA8) {
    if (white & 0xff) == 0 && (black & 0xff) == 0 {
        return;
    }

    if rect.x >= rect.z || rect.y >= rect.w {
        return;
    }

    white_square_x := false;
    px := rect.x;
    while px < rect.z {
        py := rect.y;
        white_square := white_square_x;
        while py < rect.w {
            bounds := Vec4f.{px, py, px + checker_size, py + checker_size};
            DrawRect(draw_list, bounds, ifx white_square then white else black);

            white_square = !white_square;
            py += checker_size;
        }

        white_square_x = !white_square_x;
        px += checker_size;
    }
} @Profile

DrawPolygonLine :: inline (
    draw_list : *DrawList,
    points : []PathPoint,
    closed : bool,
    thickness : float,
    color : RGBA8,
    blur_size := 0.0,
    blur_sides := LineSides.All
) {
    if (color & 0xff) == 0 {
        return;
    }

    DrawPolygonLine(
        draw_list,
        points,
        closed,
        thickness,
        (index, data) => cast(*RGBA8, data).*, *color,
        blur_size, blur_sides
    );
}

DrawPolygonLine :: (
    draw_list : *DrawList,
    points : []PathPoint,
    closed : bool,
    thickness : float,
    color_start : RGBA8,
    color_end : RGBA8,
    blur_size := 0.0,
    blur_sides := LineSides.All
) {
    if (color_start & 0xff) == 0 && (color_end & 0xff) == 0 {
        return;
    }

    get_color_data : struct {
        points : []PathPoint;
        color_start : RGBA8;
        color_end : RGBA8;
    } = .{points, color_start, color_end};

    GetColor :: (index : int, data : *void) -> RGBA8 {
        using _ := cast(*type_of(get_color_data), data);

        t := index / cast(float, points.count - 1);
        return MixColors(color_start, color_end, t);
    }

    DrawPolygonLine(
        draw_list,
        points,
        closed,
        thickness,
        GetColor, *get_color_data,
        blur_size, blur_sides
    );
}

LineSides :: enum_flags {
    Interior;
    Exterior;

    All :: Interior | Exterior;
}

DrawPolygonLine :: (
    draw_list : *DrawList,
    points : []PathPoint,
    closed : bool,
    thickness : float,
    $get_color : #type (index : int, data : *void) -> RGBA8,
    get_color_data : *void,
    blur_size := 0.0,
    blur_sides := LineSides.All
) #no_abc {
    if blur_size <= 0 {
        blur_sides = 0;
    }

    if points.count < 2 || (thickness <= 0 && blur_sides == 0) {
        return;
    }

    aa := draw_list.anti_alias_margin;

    thickness = max(thickness, 1);
    blur_size = max(blur_size, 0);
    has_middle_part := thickness > max(blur_size, aa);

    first := GetCurrentIndex(draw_list);

    num_indices_per_point : u32;
    if has_middle_part {
        num_indices_per_point += 6;
    }
    if aa > 0 || blur_sides & .Exterior {
        num_indices_per_point += 6;
    }
    if aa > 0 || blur_sides & .Interior {
        num_indices_per_point += 6;
    }

    num_indices : u32;
    if closed {
        num_indices = xx points.count * num_indices_per_point;
    } else {
        num_indices = xx (points.count - 1) * num_indices_per_point;
    }

    indices := PushIndices(draw_list, xx num_indices);
    indices_index := 0;

    num_vertices_per_point : u32;
    if has_middle_part {
        num_vertices_per_point += 2;
    } else {
        num_vertices_per_point += 1;
    }
    if aa > 0 || blur_sides & .Exterior {
        num_vertices_per_point += 1;
    }
    if aa > 0 || blur_sides & .Interior {
        num_vertices_per_point += 1;
    }

    num_vertices := cast(u32, points.count) * num_vertices_per_point;
    ReserveVertices(draw_list, num_vertices);

    half_inner_thickness := (thickness - max(blur_size, aa)) * 0.5;

    i0 : u32 = xx (points.count - 1);
    i1 : u32 = 0;
    i2 : u32 = 1;
    while i1 < xx points.count {
        defer {
            i0 = i1;
            i1 += 1;
            i2 = (i2 + 1) % cast(u32, points.count);
        }

        #if #exists(__Tracy) {
            __Tracy.ZoneScoped("Iteration");
        }

        color := inline get_color(i1, get_color_data);
        color_alpha0 := SetAlpha(color, 0);

        p1 := points[i1];

        n : Vec2f = ---;
        if p1.normal != .{0,0} {
            n = p1.normal;
        } else if !closed && (i1 == 0 || i1 == points.count - 1) {
            p2 := ifx i1 == 0 then points[1] else points[points.count - 2];

            n = PerpendicularCW(p2.position - p1.position);
            normalize(*n);
        } else {
            #if #exists(__Tracy) {
                __Tracy.ZoneScoped("Calculate intersection");
            }

            p0 := points[i0];
            p2 := points[i2];

            n0 := PerpendicularCW(p1.position - p0.position);
            normalize(*n0);

            n1 := PerpendicularCW(p2.position - p1.position);
            normalize(*n1);

            inter, p := LineIntersection(p0.position + n0, p1.position + n0, p1.position + n1, p2.position + n1);
            if !inter {
                p = p1.position + (n0 + n1) * 0.5;
            }

            n = p1.position - p;
        }

        #if #exists(__Tracy) {
            __Tracy.ZoneScoped("Push vertices and indices");
        }

        if has_middle_part {
            v := PushVertex(draw_list);
            v.position = points[i1].position + n * half_inner_thickness;
            v.color = color;

            v = PushVertex(draw_list);
            v.position = points[i1].position - n * half_inner_thickness;
            v.color = color;

            if aa > 0 || blur_sides & .Exterior {
                v = PushVertex(draw_list);
                v.position = points[i1].position + n * (half_inner_thickness + ifx blur_sides & .Exterior then blur_size else aa);
                v.color = color_alpha0;
            }

            if aa > 0 || blur_sides & .Interior {
                v = PushVertex(draw_list);
                v.position = points[i1].position - n * (half_inner_thickness + ifx blur_sides & .Interior then blur_size else aa);
                v.color = color_alpha0;
            }

            // Indices
            if i1 < points.count - 1 || closed {
                i1_middle0  := i1 * num_vertices_per_point;
                i1_middle1  := i1 * num_vertices_per_point + 1;
                i1_exterior := i1 * num_vertices_per_point + 2;
                i1_interior := i1 * num_vertices_per_point + 3;

                i2_middle0  := ifx i1 == points.count - 1 then 0 else i1_middle0  + num_vertices_per_point;
                i2_middle1  := ifx i1 == points.count - 1 then 1 else i1_middle1  + num_vertices_per_point;
                i2_exterior := ifx i1 == points.count - 1 then 2 else i1_exterior + num_vertices_per_point;
                i2_interior := ifx i1 == points.count - 1 then 3 else i1_interior + num_vertices_per_point;

                if aa <= 0 && !(blur_sides & .Exterior) {
                    i1_interior = i1_exterior;
                    i2_interior = i2_exterior;
                }

                // Middle
                indices[indices_index] = first + i1_middle0;
                indices_index += 1;

                indices[indices_index] = first + i2_middle0;
                indices_index += 1;

                indices[indices_index] = first + i1_middle1;
                indices_index += 1;

                indices[indices_index] = first + i1_middle1;
                indices_index += 1;

                indices[indices_index] = first + i2_middle0;
                indices_index += 1;

                indices[indices_index] = first + i2_middle1;
                indices_index += 1;

                if aa > 0 || blur_sides & .Exterior {
                    indices[indices_index] = first + i1_exterior;
                    indices_index += 1;

                    indices[indices_index] = first + i2_exterior;
                    indices_index += 1;

                    indices[indices_index] = first + i1_middle0;
                    indices_index += 1;

                    indices[indices_index] = first + i1_middle0;
                    indices_index += 1;

                    indices[indices_index] = first + i2_exterior;
                    indices_index += 1;

                    indices[indices_index] = first + i2_middle0;
                    indices_index += 1;
                }

                if aa > 0 || blur_sides & .Interior {
                    indices[indices_index] = first + i1_interior;
                    indices_index += 1;

                    indices[indices_index] = first + i2_interior;
                    indices_index += 1;

                    indices[indices_index] = first + i1_middle1;
                    indices_index += 1;

                    indices[indices_index] = first + i1_middle1;
                    indices_index += 1;

                    indices[indices_index] = first + i2_interior;
                    indices_index += 1;

                    indices[indices_index] = first + i2_middle1;
                    indices_index += 1;
                }
            }
        } else {
            v := PushVertex(draw_list);
            v.position = points[i1].position;
            v.color = color;

            if aa > 0 || blur_sides & .Exterior {
                v = PushVertex(draw_list);
                v.position = points[i1].position + n * ifx blur_sides & .Exterior then blur_size else aa;
                v.color = color_alpha0;
            }

            if aa > 0 || blur_sides & .Interior {
                v = PushVertex(draw_list);
                v.position = points[i1].position - n * ifx blur_sides & .Interior then blur_size else aa;
                v.color = color_alpha0;
            }

            // Indices
            if i1 < points.count - 1 || closed {
                i1_middle   := i1 * num_vertices_per_point;
                i1_exterior := i1 * num_vertices_per_point + 1;
                i1_interior := i1 * num_vertices_per_point + 2;

                i2_middle   := ifx i1 == points.count - 1 then 0 else i1_middle   + num_vertices_per_point;
                i2_exterior := ifx i1 == points.count - 1 then 1 else i1_exterior + num_vertices_per_point;
                i2_interior := ifx i1 == points.count - 1 then 2 else i1_interior + num_vertices_per_point;

                if aa <= 0 && !(blur_sides & .Exterior) {
                    i1_interior = i1_exterior;
                    i2_interior = i2_exterior;
                }

                if aa > 0 || blur_sides & .Exterior {
                    indices[indices_index] = first + i1_exterior;
                    indices_index += 1;

                    indices[indices_index] = first + i2_exterior;
                    indices_index += 1;

                    indices[indices_index] = first + i1_middle;
                    indices_index += 1;

                    indices[indices_index] = first + i1_middle;
                    indices_index += 1;

                    indices[indices_index] = first + i2_exterior;
                    indices_index += 1;

                    indices[indices_index] = first + i2_middle;
                    indices_index += 1;
                }

                if aa > 0 || blur_sides & .Interior {
                    indices[indices_index] = first + i1_interior;
                    indices_index += 1;

                    indices[indices_index] = first + i2_interior;
                    indices_index += 1;

                    indices[indices_index] = first + i1_middle;
                    indices_index += 1;

                    indices[indices_index] = first + i1_middle;
                    indices_index += 1;

                    indices[indices_index] = first + i2_interior;
                    indices_index += 1;

                    indices[indices_index] = first + i2_middle;
                    indices_index += 1;
                }
            }
        }
    }
} @Profile

DrawConvexPolygon :: inline (
    draw_list : *DrawList,
    points : []PathPoint,
    color : RGBA8,
    blur_size := 0.0
) #no_abc {
    if (color & 0xff) == 0 {
        return;
    }

    DrawConvexPolygon(
        draw_list,
        points,
        (index, data) => cast(*RGBA8, data).*, *color,
        (index, data) => Vec2f.{}, null,
        blur_size
    );
}

DrawConvexPolygon :: (
    draw_list : *DrawList,
    points : []PathPoint,
    $get_color : (index : int, data : *void) -> RGBA8,
    get_color_data : *void,
    $get_tex_coords : (index : int, data : *void) -> Vec2f,
    get_tex_coords_data : *void,
    blur_size := 0.0
) #no_abc {
    if points.count < 3 {
        return;
    }

    first_inner := GetCurrentIndex(draw_list);
    first_outer := first_inner + 1;

    blur_size = max(blur_size, draw_list.anti_alias_margin, 0.0);

    num_indices := cast(u32, (points.count - 2) * 3);
    if blur_size > 0 {
        num_indices += cast(u32, points.count * 6);
    }

    indices := PushIndices(draw_list, num_indices);
    indices_index := 0;
    for i : 2..cast(u32, points.count - 1) {
        indices[indices_index] = first_inner;
        indices_index += 1;

        indices[indices_index] = first_inner + ((i - 1) << 1);
        indices_index += 1;

        indices[indices_index] = first_inner + (i << 1);
        indices_index += 1;
    }

    num_vertices := points.count;
    if blur_size > 0 {
        num_vertices += points.count;
    }

    ReserveVertices(draw_list, num_vertices);

    i0 : u32 = xx (points.count - 1);
    i1 : u32 = 0;
    i2 : u32 = 1;
    while i1 < points.count {
        defer {
            i0 = i1;
            i1 += 1;
            i2 = (i2 + 1) % cast(u32, points.count);
        }

        color := inline get_color(i1, get_color_data);
        color_alpha0 := SetAlpha(color, 0);

        tex_coords := inline get_tex_coords(i1, get_tex_coords_data);

        p1 := points[i1];

        n : Vec2f = ---;
        if p1.normal != .{0,0} {
            n = p1.normal;
        } else {
            p0 := points[i0];
            p2 := points[i2];

            n0 := PerpendicularCW(p1.position - p0.position);
            normalize(*n0);

            n1 := PerpendicularCW(p2.position - p1.position);
            normalize(*n1);

            inter, p := LineIntersection(p0.position + n0, p1.position + n0, p1.position + n1, p2.position + n1);
            if !inter {
                p = p1.position + (n0 + n1) * 0.5;
            }

            n = p1.position - p;
        }

        n *= blur_size * 0.5;

        // Inner
        v := PushVertex(draw_list);
        v.position = points[i1].position - n;
        v.color = color;
        v.tex_coords = tex_coords;

        if blur_size > 0 {
            // Outer
            v = PushVertex(draw_list);
            v.position = points[i1].position + n;
            v.color = color_alpha0;
            v.tex_coords = tex_coords;

            // Blur indices
            indices[indices_index] = first_inner + (i1 << 1);
            indices_index += 1;

            indices[indices_index] = first_inner + (i0 << 1);
            indices_index += 1;

            indices[indices_index] = first_outer + (i0 << 1);
            indices_index += 1;

            indices[indices_index] = first_outer + (i0 << 1);
            indices_index += 1;

            indices[indices_index] = first_outer + (i1 << 1);
            indices_index += 1;

            indices[indices_index] = first_inner + (i1 << 1);
            indices_index += 1;
        }
    }
} @Profile

TriangleSides :: enum_flags {
    P0P1;
    P1P2;
    P2P0;

    All :: P0P1 | P1P2 | P2P0;
}

DrawTriangle :: inline (
    draw_list : *DrawList,
    p0 : Vec2f,
    p1 : Vec2f,
    p2 : Vec2f,
    color : RGBA8,
    // A blur of 1.0 can be used for anti-aliasing
    // For blur to work the points need to be in counter clockwise order
    blur_size := 1.0,
    blur_sides := TriangleSides.All
) {
    DrawTriangle(draw_list, p0, p1, p2, color, color, color, blur_size, blur_sides);
}

DrawTriangle :: (
    draw_list : *DrawList,
    p0 : Vec2f,
    p1 : Vec2f,
    p2 : Vec2f,
    c0 : RGBA8,
    c1 : RGBA8,
    c2 : RGBA8,
    // A blur of 1.0 can be used for anti-aliasing
    // For blur to work the points need to be in counter clockwise order
    blur_size := 1.0,
    blur_sides := TriangleSides.All
) {
    if (c0 & 0xff) == 0 && (c1 & 0xff) == 0 && (c2 & 0xff) == 0 {
        return;
    }

    color0_alpha0 := SetAlpha(c0, 0);
    color1_alpha0 := SetAlpha(c1, 0);
    color2_alpha0 := SetAlpha(c2, 0);

    num_indices : u32 = 3;
    if blur_sides & .P0P1 {
        num_indices += 6;
    }
    if blur_sides & .P1P2 {
        num_indices += 6;
    }
    if blur_sides & .P2P0 {
        num_indices += 6;
    }

    num_vertices : u32 = 3;
    has_p0_blur := (blur_sides & .P0P1) != 0 || (blur_sides & .P2P0) != 0;
    has_p1_blur := (blur_sides & .P0P1) != 0 || (blur_sides & .P1P2) != 0;
    has_p2_blur := (blur_sides & .P1P2) != 0 || (blur_sides & .P2P0) != 0;
    if has_p0_blur {
        num_vertices += 1;
    }
    if has_p1_blur {
        num_vertices += 1;
    }
    if has_p2_blur {
        num_vertices += 1;
    }

    first := GetCurrentIndex(draw_list);
    indices := PushIndices(draw_list, num_indices);
    indices_index := 0;

    ReserveVertices(draw_list, num_vertices);

    v := PushVertex(draw_list);
    v.position = p0;
    v.color = c0;

    v = PushVertex(draw_list);
    v.position = p1;
    v.color = c1;

    v = PushVertex(draw_list);
    v.position = p2;
    v.color = c2;

    if has_p0_blur {
        a := p1 - p0;
        a = .{-a.y, a.x};
        normalize(*a);

        b := p2 - p0;
        b = .{b.y, -b.x};
        normalize(*b);

        inter, p := LineIntersection(
            p0 + a * blur_size, p1 + a * blur_size,
            p0 + b * blur_size, p2 + b * blur_size
        );

        if !inter {
            p = p0 + a * blur_size;
        }

        v = PushVertex(draw_list);
        v.position = p;
        v.color = color0_alpha0;
    }

    if has_p1_blur {
        a := p0 - p1;
        a = .{-a.y, a.x};
        normalize(*a);

        b := p2 - p1;
        b = .{b.y, -b.x};
        normalize(*b);

        inter, p := LineIntersection(
            p1 - a * blur_size, p0 - a * blur_size,
            p1 - b * blur_size, p2 - b * blur_size
        );

        if !inter {
            p = p1 - a * blur_size;
        }

        v = PushVertex(draw_list);
        v.position = p;
        v.color = color1_alpha0;
    }

    if has_p2_blur {
        a := p1 - p2;
        a = .{-a.y, a.x};
        normalize(*a);

        b := p0 - p2;
        b = .{b.y, -b.x};
        normalize(*b);

        inter, p := LineIntersection(
            p2 - a * blur_size, p1 - a * blur_size,
            p2 - b * blur_size, p0 - b * blur_size
        );

        if !inter {
            p = p2 - a * blur_size;
        }

        v = PushVertex(draw_list);
        v.position = p;
        v.color = color2_alpha0;
    }

    indices[indices_index] = first;
    indices_index += 1;

    indices[indices_index] = first + 1;
    indices_index += 1;

    indices[indices_index] = first + 2;
    indices_index += 1;

    if blur_sides & .P0P1 {
        indices[indices_index] = first;
        indices_index += 1;

        indices[indices_index] = first + 3;
        indices_index += 1;

        indices[indices_index] = first + 4;
        indices_index += 1;

        indices[indices_index] = first;
        indices_index += 1;

        indices[indices_index] = first + 4;
        indices_index += 1;

        indices[indices_index] = first + 1;
        indices_index += 1;
    }

    if blur_sides & .P1P2 {
        indices[indices_index] = first + 1;
        indices_index += 1;

        indices[indices_index] = first + 4;
        indices_index += 1;

        indices[indices_index] = first + 5;
        indices_index += 1;

        indices[indices_index] = first + 1;
        indices_index += 1;

        indices[indices_index] = first + 5;
        indices_index += 1;

        indices[indices_index] = first + 2;
        indices_index += 1;
    }

    if blur_sides & .P2P0 {
        indices[indices_index] = first + 2;
        indices_index += 1;

        indices[indices_index] = first + 5;
        indices_index += 1;

        indices[indices_index] = first + 3;
        indices_index += 1;

        indices[indices_index] = first + 2;
        indices_index += 1;

        indices[indices_index] = first + 3;
        indices_index += 1;

        indices[indices_index] = first;
        indices_index += 1;
    }
} @Profile

PathPoint :: struct {
    position : Vec2f;
    normal : Vec2f;
}

PathCalcNormals :: (points : []PathPoint, closed : bool) {
    i0, i1 : u32;
    if closed {
        i0 = 0;
        i1 = 1;
    } else {
        i0 = xx (points.count - 1);
    }

    while i1 < points.count {
        defer {
            i0 = i1;
            i1 += 1;
        }

        p0 := points[i0].position;
        p1 := points[i1].position;
        d := Normalize(p1 - p0);
        d = PerpendicularCW(d);

        if !closed && i1 == points.count - 1 {
            points[i1].normal.x = d;
        }
    }
} @Profile

PathPushRoundedRect :: (points : *[..]PathPoint, bounds : Vec4f, corner_radiuses : Vec4f) {
    half_size := (bounds.zw - bounds.xy) * 0.5;
    max_radius := min(half_size.x, half_size.y);
    radiuses := Vec4f.{
        max(min(corner_radiuses.x, max_radius), 0.0),
        max(min(corner_radiuses.y, max_radius), 0.0),
        max(min(corner_radiuses.z, max_radius), 0.0),
        max(min(corner_radiuses.w, max_radius), 0.0),
    };

    top_left := bounds.xy;
    top_left.x += radiuses.x;
    top_left.y += radiuses.x;

    top_right := Vec2f.{bounds.z, bounds.y};
    top_right.x -= radiuses.y;
    top_right.y += radiuses.y;

    bottom_left := Vec2f.{bounds.x, bounds.w};
    bottom_left.x += radiuses.z;
    bottom_left.y -= radiuses.z;

    bottom_right := bounds.zw;
    bottom_right.x -= radiuses.w;
    bottom_right.y -= radiuses.w;

    PathPushArc(points, bottom_left,  radiuses.z,        PI, PI * 0.5, use_table=radiuses.z < 200);
    PathPushArc(points, bottom_right, radiuses.w, -PI * 0.5, PI * 0.5, use_table=radiuses.w < 200);
    PathPushArc(points, top_right,    radiuses.y,         0, PI * 0.5, use_table=radiuses.y < 200);
    PathPushArc(points, top_left,     radiuses.x,  PI * 0.5, PI * 0.5, use_table=radiuses.x < 200);
} @Profile

SampleCosSinTable :: (angle : float) -> Vec2f {
    Half_Circle_Points_Count :: 50;
    Half_Circle_Points :: #run () -> [Half_Circle_Points_Count + 1]Vec2f {
        result : [Half_Circle_Points_Count + 1]Vec2f = ---;

        for i : 0..Half_Circle_Points_Count {
            theta := i / cast(float, Half_Circle_Points_Count) * PI * 0.5;
            result[i] = Vec2f.{cos(theta), sin(theta)};
        }

        return result;
    }();

    while angle > 2 * PI {
        angle -= 2 * PI;
    }
    while angle < 0 {
        angle += 2 * PI;
    }

    theta := angle;
    if angle >= PI * 1.5 {
        theta -= PI * 1.5;
    } else if angle >= PI {
        theta -= PI;
    } else if angle >= PI * 0.5 {
        theta -= PI * 0.5;
    }

    f0 := Half_Circle_Points_Count * theta / (PI * 0.5);
    i0 := cast(int, f0);
    i1 := i0 + 1;
    p0 := Half_Circle_Points[i0];
    p1 := Half_Circle_Points[i1];
    t := f0 - i0;

    p := lerp(p0, p1, t);
    if angle >= PI * 0.5 {
        p = .{-p.y, p.x};
    }
    if angle >= PI {
        p = .{-p.y, p.x};
    }
    if angle >= PI * 1.5 {
        p = .{-p.y, p.x};
    }

    return normalize(p);
}

PathPushArc :: (points : *[..]PathPoint, center : Vec2f, radius : float, start_angle : float, angle : float, num_segments := 0, use_table := true) {
    if angle < 0 {
        start_angle -= angle;
        angle = -angle;
    }

    while start_angle > 2 * PI {
        start_angle -= 2 * PI;
    }
    while start_angle < 0 {
        start_angle += 2 * PI;
    }

    angle = min(angle, PI * 2);

    if radius < 0.5 {
        array_add(points, .{position=center});
        return;
    }

    if num_segments == 0 {
        num_quadrants := angle / (PI * 0.5);
        num_segments = xx max(radius * num_quadrants * 0.25 * context.omg.global_polygon_resolution, num_quadrants * 4, 2);
    }

    connected := angle == PI * 2;
    iterations := ifx connected then num_segments - 1 else num_segments;

    if use_table {
        for i : 0..iterations {
            theta := i / cast(float, num_segments) * angle;
            p := SampleCosSinTable(-start_angle - theta);
            array_add(points, .{position=center + p * radius, normal=p});
        }
    } else {
        for i : 0..iterations {
            theta := i / cast(float, num_segments) * angle;
            p := Vec2f.{cos(-start_angle - theta), sin(-start_angle - theta)};
            array_add(points, .{position=center + p * radius, normal=p});
        }
    }
} @Profile

PathPushBezierQuadratic :: (path : *[..]PathPoint, p0 : Vec2f, p1 : Vec2f, p2 : Vec2f, num_segments := 0) {
    if num_segments <= 0 {
        a := Vec2f.{abs(p0.x - p1.x), abs(p0.y - p1.y)};
        b := Vec2f.{abs(p1.x - p2.x), abs(p1.y - p2.y)};
        max_dist := max(a.x, a.y, b.x, b.y);

        num_segments = xx max(max_dist / 5 * context.omg.global_polygon_resolution, 5);
    }

    for i : 0..num_segments {
        t := i / cast(float, num_segments);

        point := array_add(path);
        point.position = BezierQuadratic(p0, p1, p2, t);
        point.normal = BezierQuadraticNormal(p0, p1, p2, t);
    }
} @Profile

PathPushBezierCubic :: (path : *[..]PathPoint, p0 : Vec2f, p1 : Vec2f, p2 : Vec2f, p3 : Vec2f, num_segments := 0) {
    if num_segments <= 0 {
        a := Vec2f.{abs(p0.x - p1.x), abs(p0.y - p1.y)};
        b := Vec2f.{abs(p1.x - p2.x), abs(p1.y - p2.y)};
        c := Vec2f.{abs(p2.x - p3.x), abs(p2.y - p3.y)};
        max_dist := max(a.x, a.y, b.x, b.y, c.x, c.y);

        num_segments = xx max(max_dist / 5 * context.omg.global_polygon_resolution, 5);
    }

    for i : 0..num_segments {
        t := i / cast(float, num_segments);

        point := array_add(path);
        point.position = BezierCubic(p0, p1, p2, p3, t);
        point.normal = BezierCubicNormal(p0, p1, p2, p3, t);
    }
} @Profile
