VtxDrawCall :: struct {
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

VtxDrawList :: struct {
    draw_calls : [..]VtxDrawCall;
    clip_boxes : [..]ClipBox;
    clip_box_stack : [..]s32;
    vertices : [..]Vertex;
    indices : [..]u32;
    path : [..]PathPoint;

    gpu_buffer_clip_boxes_offset : u32;
    gpu_buffer_vertices_offset : u32;
    gpu_buffer_indices_offset : u32;
}

InitDrawList :: (draw_list : *VtxDrawList) {
    draw_list.draw_calls.allocator = context.allocator;
    draw_list.clip_boxes.allocator = context.allocator;
    draw_list.clip_box_stack.allocator = context.allocator;
    draw_list.vertices.allocator = context.allocator;
    draw_list.indices.allocator = context.allocator;
    draw_list.path.allocator = context.allocator;
}

DestroyDrawList :: (draw_list : *VtxDrawList) {
    array_reset(*draw_list.draw_calls);
    array_reset(*draw_list.clip_boxes);
    array_reset(*draw_list.clip_box_stack);
    array_reset(*draw_list.vertices);
    array_reset(*draw_list.indices);
    array_reset(*draw_list.path);
    draw_list.* = .{};
}

ClearDrawList :: (draw_list : *VtxDrawList) {
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

GetCurrentDrawCall :: (draw_list : *VtxDrawList) -> *VtxDrawCall {
    if draw_list.draw_calls.count <= 0 {
        return null;
    }
    return *draw_list.draw_calls[draw_list.draw_calls.count - 1];
}

GetCurrentClipBoxIndex :: (draw_list : *VtxDrawList) -> s32 {
    if draw_list.clip_box_stack.count <= 0 {
        return -1;
    }
    return draw_list.clip_box_stack[draw_list.clip_box_stack.count - 1];
}

ReserveVertices :: (draw_list : *VtxDrawList, count : int) {
    if draw_list.vertices.count + count <= draw_list.vertices.allocated {
        return;
    }

    array_reserve(*draw_list.vertices, draw_list.vertices.count + count);
}

PushVertex :: inline (draw_list : *VtxDrawList) -> *Vertex {
    vertex := array_add(*draw_list.vertices);
    vertex.clip_box_index = GetCurrentClipBoxIndex(draw_list);
    return vertex;
}

GetCurrentIndex :: inline (draw_list : *VtxDrawList) -> u32 {
    return xx draw_list.vertices.count;
}

PushIndex :: inline (draw_list : *VtxDrawList, value : u32) {
    draw_call := GetCurrentDrawCall(draw_list);
    if !draw_call {
        draw_call = array_add(*draw_list.draw_calls);
    }

    draw_call.num_indices += 1;

    array_add(*draw_list.indices, value);
}

PushIndices :: (draw_list : *VtxDrawList, count : u32) -> []u32 {
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

PushClipBox :: (draw_list : *VtxDrawList, bounds : Vec4f, corner_radiuses : Vec4f = .{}) {
    box := array_add(*draw_list.clip_boxes);
    box.bounds = bounds;
    box.corner_radiuses = corner_radiuses;

    current_index := GetCurrentClipBoxIndex(draw_list);
    if current_index >= 0 {
        current := draw_list.clip_boxes[current_index];
        box.* = ClipBoxAgainstBox(box, current);
    }

    array_add(*draw_list.clip_box_stack, xx (draw_list.clip_boxes.count - 1));
}

PopClipBox :: (draw_list : *VtxDrawList) {
    pop(*draw_list.clip_box_stack);
}

IsClipped :: (draw_list : *VtxDrawList, bounds : Vec4f) -> bool {
    index := GetCurrentClipBoxIndex(draw_list);
    if index < 0 {
        return false;
    }

    clipped := ClipRect(bounds, draw_list.clip_boxes[index].bounds);
    return clipped.x > clipped.z || clipped.y > clipped.w;
}

PushDrawCall :: (draw_list : *VtxDrawList) -> *VtxDrawCall {
    new : *VtxDrawCall;
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

SetTexture :: (draw_list : *VtxDrawList, texture : TextureHandle, has_white_px : bool = false) -> previous : VtxDrawCall.Texture {
    return SetTexture(draw_list, .{texture, has_white_px});
}

SetTexture :: (draw_list : *VtxDrawList, texture : VtxDrawCall.Texture) -> previous : VtxDrawCall.Texture {
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

DrawTriangle :: inline (
    draw_list : *VtxDrawList,
    p0 : Vec2f,
    p1 : Vec2f,
    p2 : Vec2f,
    color : RGBA8
) {
    DrawTriangle(draw_list, p0, p1, p2, color, color, color);
}

DrawTriangle :: (
    draw_list : *VtxDrawList,
    p0 : Vec2f,
    p1 : Vec2f,
    p2 : Vec2f,
    color0 : RGBA8,
    color1 : RGBA8,
    color2 : RGBA8,
    uv0 := Vec2f.{0,0},
    uv1 := Vec2f.{0,0},
    uv2 := Vec2f.{0,0}
) {
    if (color0 & 0xff) == 0 && (color1 & 0xff) == 0 && (color2 & 0xff) == 0 {
        return;
    }

    first := GetCurrentIndex(draw_list);

    ReserveVertices(draw_list, 3);
    v0 := PushVertex(draw_list);
    v1 := PushVertex(draw_list);
    v2 := PushVertex(draw_list);

    v0.position = p0;
    v0.color = color0;
    v0.tex_coords = uv0;

    v1.position = p1;
    v1.color = color1;
    v1.tex_coords = uv1;

    v2.position = p2;
    v2.color = color2;
    v2.tex_coords = uv2;
}

DrawRect :: inline (
    draw_list : *VtxDrawList,
    bounds : Vec4f,
    color : RGBA8,
    corner_radiuses : Vec4f = .{0,0,0,0},
    uv_bounds : Vec4f = .{0,0,1,1},
    blur_size := 0.0
) {
    DrawRect(draw_list, bounds, color, color, color, color, corner_radiuses, uv_bounds, blur_size);
}

DrawRect :: (
    draw_list : *VtxDrawList,
    bounds : Vec4f,
    color_top_left : RGBA8,
    color_top_right : RGBA8,
    color_bottom_left : RGBA8,
    color_bottom_right : RGBA8,
    corner_radiuses : Vec4f = .{0,0,0,0},
    uv_bounds : Vec4f = .{0,0,1,1},
    blur_size := 0.0
) {
    if IsClipped(draw_list, bounds) {
        return;
    }

    if (color_top_left & 0xff) == 0
    || (color_top_right & 0xff) == 0
    || (color_bottom_left & 0xff) == 0
    || (color_bottom_right & 0xff) == 0 {
        return;
    }

    PathPushRoundedRect(*draw_list.path, bounds, corner_radiuses);
    DrawConvexPolygon(draw_list, draw_list.path, color_top_left, blur_size);
    array_reset_keeping_memory(*draw_list.path);
}

DrawBox :: inline (draw_list : *VtxDrawList, box : BoxDrawing, texture : TextureHandle = 0) -> int {
    prev_texture := SetTexture(draw_list, texture);
    defer SetTexture(draw_list, prev_texture);

    if (box.outer_shadow_color & 0xff) != 0 {
        DrawRect(
            draw_list,
            .{xy=box.outer_shadow_offset + box.position - box.size * 0.5, zw=box.outer_shadow_offset + box.position + box.size * 0.5},
            box.outer_shadow_color,
            box.corner_radiuses,
            box.uv_bounds,
            box.outer_shadow_blur,
        );

    }

    DrawRect(
        draw_list,
        .{xy=box.position - box.size * 0.5, zw=box.position + box.size * 0.5},
        box.background_color,
        box.corner_radiuses,
        box.uv_bounds
    );
}

DrawLine :: (
    draw_list : *VtxDrawList,
    start : Vec2f,
    end : Vec2f,
    thickness : float,
    start_color : RGBA8,
    end_color : RGBA8
) {
    if (start_color & 0xff) == 0 && (end_color & 0xff) == 0 {
        return;
    }

    dir := end - start;
    length := normalize(*dir);
    normal := Vec2f.{dir.y, -dir.x};
    half_thickness := thickness * 0.5;

    first := GetCurrentIndex(draw_list);
    ReserveVertices(draw_list, 4);
    p0 := PushVertex(draw_list);
    p1 := PushVertex(draw_list);
    p2 := PushVertex(draw_list);
    p3 := PushVertex(draw_list);

    p0.position = start + normal * half_thickness;
    p0.color = start_color;

    p1.position = end + normal * half_thickness;
    p1.color = end_color;

    p2.position = start - normal * half_thickness;
    p2.color = start_color;

    p3.position = end - normal * half_thickness;
    p3.color = end_color;

    PushIndex(draw_list, first);
    PushIndex(draw_list, first + 1);
    PushIndex(draw_list, first + 2);

    PushIndex(draw_list, first + 2);
    PushIndex(draw_list, first + 1);
    PushIndex(draw_list, first + 3);
}

DrawSDFGlyph :: (
    draw_list : *VtxDrawList,
    bounds : Vec4f,
    color : RGBA8,
    uv_bounds : Vec4f,
    sdf_range : float,
    blur_amount := 0.0
) {
    DrawSDFGlyph(draw_list, bounds, color, color, color, color, uv_bounds, sdf_range, blur_amount);
}

DrawSDFGlyph :: (
    draw_list : *VtxDrawList,
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
    || (color_top_right & 0xff) == 0
    || (color_bottom_left & 0xff) == 0
    || (color_bottom_right & 0xff) == 0 {
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
    draw_list : *VtxDrawList,
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
    draw_list : *VtxDrawList,
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

DrawNodeDefault :: (draw_list : *VtxDrawList, node : *Node) {
    DrawBox(draw_list, .{
        size=node.rect.zw - node.rect.xy,
        position=(node.rect.xy + node.rect.zw) * 0.5,
        uv_bounds=node.image_uv_bounds,
        corner_radiuses=node.corner_radiuses,
        background_color=node.background_color,
        background_color2=node.background_color2,
        background_gradient_vector=node.background_gradient_vector,
        background_gradient_offset=node.background_gradient_offset,
        border_color=node.border_color,
        border_color2=node.border_color2,
        border_gradient_vector=node.border_gradient_vector,
        border_gradient_offset=node.border_gradient_offset,
        border_size=node.border_size,
        border_inset=node.border_inset,
        outer_shadow_color=node.outer_shadow_color,
        outer_shadow_offset=node.outer_shadow_offset,
        outer_shadow_blur=node.outer_shadow_blur,
        inner_shadow_color=node.inner_shadow_color,
        inner_shadow_offset=node.inner_shadow_offset,
        inner_shadow_blur=node.inner_shadow_blur,
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
} @Profile

DrawNodes :: (draw_list : *VtxDrawList, node : *Node) {
    if IsClipped(draw_list, node.rect) {
        return;
    }

    if node.draw {
        node.draw(draw_list, node);
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

DrawConvexPolygon :: (draw_list : *VtxDrawList, points : []PathPoint, color : RGBA8, blur_size := 0.0) {
    auto_release_temp();

    if points.count < 3 || (color & 0xff) == 0 {
        return;
    }

    first_inner := GetCurrentIndex(draw_list);
    first_outer := first_inner + 1;

    num_indices := cast(u32, (points.count - 2) * 3 + points.count * 6);

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

    color_alpha0 := SetAlpha(color, 0);

    num_vertices := points.count * 2;
    ReserveVertices(draw_list, num_vertices);

    margin := 1.0 + max(blur_size, 0.0);
    i0 : u32 = xx (points.count - 1);
    i1 : u32 = 0;
    while i1 < points.count {
        defer {
            i0 = i1;
            i1 += 1;
        }

        n0 := points[i0].normal;
        n1 := points[i1].normal;
        n := (n0 + n1) * 0.5;

        d2 := dot(n, n);

        n *= margin * 0.5;

        // Inner
        v := PushVertex(draw_list);
        v.position = points[i1].position - n;
        v.color = color;

        // Outer
        v = PushVertex(draw_list);
        v.position = points[i1].position + n;
        v.color = color_alpha0;

        // AA margin indices
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

PathPoint :: struct {
    position : Vec2f;
    normal : Vec2f;
}

PathCalcNormals :: (points : []PathPoint) {
    i0 : u32 = xx (points.count - 1);
    i1 : u32 = 0;
    while i1 < points.count {
        defer {
            i0 = i1;
            i1 += 1;
        }

        p0 := points[i0].position;
        p1 := points[i1].position;
        d := Normalize(p1 - p0);
        points[i0].normal.x = d.y;
        points[i0].normal.y = -d.x;
    }
}

PathPushRoundedRect :: (points : *[..]PathPoint, bounds : Vec4f, corner_radiuses : Vec4f) {
    half_size := (bounds.zw - bounds.xy) * 0.5;
    max_radius := min(half_size.x, half_size.y);

    top_left := bounds.xy;
    top_left.x += min(corner_radiuses.x, max_radius);
    top_left.y += min(corner_radiuses.x, max_radius);

    top_right := Vec2f.{bounds.z, bounds.y};
    top_right.x -= min(corner_radiuses.y, max_radius);
    top_right.y += min(corner_radiuses.y, max_radius);

    bottom_left := Vec2f.{bounds.x, bounds.w};
    bottom_left.x += min(corner_radiuses.z, max_radius);
    bottom_left.y -= min(corner_radiuses.z, max_radius);

    bottom_right := bounds.zw;
    bottom_right.x -= min(corner_radiuses.w, max_radius);
    bottom_right.y -= min(corner_radiuses.w, max_radius);

    PathPushArc(points, bottom_left,  min(corner_radiuses.z, max_radius), PI, PI * 0.5);
    PathPushArc(points, bottom_right, min(corner_radiuses.w, max_radius), -PI * 0.5, PI * 0.5);
    PathPushArc(points, top_right,    min(corner_radiuses.y, max_radius), 0, PI * 0.5);
    PathPushArc(points, top_left,     min(corner_radiuses.x, max_radius), PI * 0.5, PI * 0.5);
}

PathPushArc :: (points : *[..]PathPoint, center : Vec2f, radius : float, start_angle : float, angle : float, num_segments := 0) {
    if angle < 0 {
        start_angle -= angle;
        angle = -angle;
    }

    if radius < 0.5 {
        normal := Vec2f.{cos(-start_angle - angle * 0.5), sin(-start_angle - angle * 0.5)};
        array_add(points, .{position=center, normal=normal});
        return;
    }

    if num_segments == 0 {
        num_segments = max(cast(int, radius / 3) * 3, 8);
    }

    for i : 0..num_segments {
        theta := i / cast(float, num_segments) * angle;
        p := Vec2f.{cos(-start_angle - theta), sin(-start_angle - theta)};
        array_add(points, .{position=center + p * radius, normal=p});
    }
}
