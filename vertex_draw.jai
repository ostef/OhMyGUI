TextureHandle :: u64;

ClipBox :: struct {
    bounds : Vec4f;
    corner_radiuses : Vec4f;
}

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

DrawRect :: (
    draw_list : *VtxDrawList,
    bounds : Vec4f,
    color : RGBA8,
    corner_radiuses : Vec4f = .{0,0,0,0},
    uv_bounds : Vec4f = .{0,0,0,0},
    blur_size := 1.0
) {
    if IsClipped(draw_list, bounds) {
        return;
    }

    if (color & 0xff) == 0 {
        return;
    }

    PathPushRoundedRect(*draw_list.path, bounds, corner_radiuses);

    get_tex_coords_data : struct {
        points : []PathPoint;
        bounds : Vec4f;
        uv_bounds : Vec4f;
    } = .{points=draw_list.path, bounds=bounds, uv_bounds=uv_bounds};

    GetTexCoords :: (index : int, data : *void) -> Vec2f {
        using _ := cast(*type_of(get_tex_coords_data), data);

        point := points[index];
        tx := InverseLerp(bounds.x, bounds.z, point.position.x);
        ty := InverseLerp(bounds.y, bounds.w, point.position.y);

        return .{
            lerp(uv_bounds.x, uv_bounds.z, tx),
            lerp(uv_bounds.y, uv_bounds.w, ty),
        };
    }

    DrawConvexPolygon(
        draw_list,
        draw_list.path,
        (index, data) => cast(*RGBA8, data).*, *color,
        GetTexCoords, *get_tex_coords_data,
        blur_size);
    array_reset_keeping_memory(*draw_list.path);
}

DrawRectOutline :: inline (
    draw_list : *VtxDrawList,
    bounds : Vec4f,
    color : RGBA8,
    thickness : float,
    corner_radiuses : Vec4f = .{0,0,0,0},
    uv_bounds : Vec4f = .{0,0,0,0},
    blur_size := 1.0,
    blur_sides := LineSides.All
) {
    DrawRectOutline(draw_list, bounds, color, color, color, color, thickness, corner_radiuses, uv_bounds, blur_size, blur_sides);
}

DrawRectOutline :: (
    draw_list : *VtxDrawList,
    bounds : Vec4f,
    color_top_left : RGBA8,
    color_top_right : RGBA8,
    color_bottom_left : RGBA8,
    color_bottom_right : RGBA8,
    thickness : float,
    corner_radiuses : Vec4f = .{0,0,0,0},
    uv_bounds : Vec4f = .{0,0,0,0},
    blur_size := 1.0,
    blur_sides := LineSides.All
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
    DrawPolygonLine(draw_list, draw_list.path, true, thickness, color_top_left, blur_size, blur_sides);
    array_reset_keeping_memory(*draw_list.path);
}

BoxDrawing :: struct {
    size : Vec2f;
    position : Vec2f;
    uv_bounds : Vec4f;
    rotation : float;
    corner_radiuses : Vec4f;
    background_color : RGBA8;
    background_color2 : RGBA8;
    background_gradient_offset : float;
    background_gradient_vector : Vec2f;
    border_color : RGBA8;
    border_color2 : RGBA8;
    border_gradient_offset : float;
    border_gradient_vector : Vec2f;
    border_size : float;
    border_inset : float;
    outer_shadow_color : RGBA8;
    outer_shadow_offset : Vec2f;
    outer_shadow_blur : float;
    inner_shadow_color : RGBA8;
    inner_shadow_offset : Vec2f;
    inner_shadow_blur : float;
    clip_box_index : s32;
}

DrawBox :: inline (draw_list : *VtxDrawList, box : BoxDrawing, texture : TextureHandle = 0) {
    bounds := Vec4f.{xy=box.position - box.size * 0.5, zw=box.position + box.size * 0.5};

    // Outer shadow
    DrawRect(
        draw_list,
        .{xy=box.outer_shadow_offset + bounds.xy, zw=box.outer_shadow_offset + bounds.zw},
        box.outer_shadow_color,
        box.corner_radiuses,
        box.uv_bounds,
        box.outer_shadow_blur,
    );

    // Background
    prev_texture := SetTexture(draw_list, texture);

    DrawRect(
        draw_list,
        bounds,
        box.background_color,
        box.corner_radiuses,
        box.uv_bounds
    );

    SetTexture(draw_list, prev_texture);

    // Inner shadow
    DrawRectOutline(
        draw_list,
        bounds,
        box.inner_shadow_color,
        0,
        box.corner_radiuses,
        box.uv_bounds,
        box.inner_shadow_blur,
        .Interior,
    );

    // Border
    border_inset := Vec2f.{box.border_size * 0.5 + box.border_inset, box.border_size * 0.5 + box.border_inset};
    border_bounds := bounds;
    border_bounds.x += box.border_size * 0.5 + box.border_inset;
    border_bounds.y += box.border_size * 0.5 + box.border_inset;
    border_bounds.z -= box.border_size * 0.5 + box.border_inset;
    border_bounds.w -= box.border_size * 0.5 + box.border_inset;
    DrawRectOutline(
        draw_list,
        border_bounds,
        box.border_color,
        box.border_size,
        box.corner_radiuses,
        box.uv_bounds
    );
}

DrawCircle :: (
    draw_list : *VtxDrawList,
    center : Vec2f,
    radius : float,
    color : RGBA8,
    blur_size := 1.0,
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
}

DrawCircleOutline :: (
    draw_list : *VtxDrawList,
    center : Vec2f,
    radius : float,
    color : RGBA8,
    thickness : float,
    blur_size := 1.0,
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
}

DrawLine :: inline (
    draw_list : *VtxDrawList,
    start : Vec2f,
    end : Vec2f,
    thickness : float,
    color : RGBA8,
    blur_size := 1.0
) {
    DrawLine(draw_list, start, end, thickness, color, color, blur_size);
}

DrawLine :: (
    draw_list : *VtxDrawList,
    start : Vec2f,
    end : Vec2f,
    thickness : float,
    start_color : RGBA8,
    end_color : RGBA8,
    blur_size := 1.0
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

DrawCheckerboard :: (draw_list : *VtxDrawList, rect : Vec4f, checker_size : float, white : RGBA8, black : RGBA8) {
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
    draw_list : *VtxDrawList,
    points : []PathPoint,
    closed : bool,
    thickness : float,
    color : RGBA8,
    blur_size := 1.0,
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
        blur_size, blur_sides);
}

LineSides :: enum_flags {
    Interior;
    Exterior;

    All :: Interior | Exterior;
}

DrawPolygonLine :: (
    draw_list : *VtxDrawList,
    points : []PathPoint,
    closed : bool,
    thickness : float,
    $get_color : #type (index : int, data : *void) -> RGBA8,
    get_color_data : *void,
    blur_size := 1.0,
    blur_sides := LineSides.All
) #no_abc {
    if points.count < 2 {
        return;
    }

    thickness = max(thickness, 1);
    blur_size = max(blur_size, 0);
    has_middle_part := thickness > blur_size;

    first := GetCurrentIndex(draw_list);

    num_indices_per_point : u32;
    if has_middle_part {
        num_indices_per_point += 6;
    }
    if blur_sides & .Exterior {
        num_indices_per_point += 6;
    }
    if blur_sides & .Interior {
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
    if blur_sides & .Exterior {
        num_vertices_per_point += 1;
    }
    if blur_sides & .Interior {
        num_vertices_per_point += 1;
    }

    num_vertices := cast(u32, points.count) * num_vertices_per_point;
    ReserveVertices(draw_list, num_vertices);

    half_inner_thickness := (thickness - blur_size) * 0.5;

    i0 : u32 = xx (points.count - 1);
    i1 : u32 = 0;
    i2 : u32 = 1;
    while i1 < xx points.count {
        defer {
            i0 = i1;
            i1 += 1;
            i2 = (i2 + 1) % cast(u32, points.count);
        }

        color := inline get_color(i1, get_color_data);
        color_alpha0 := SetAlpha(color, 0);

        n : Vec2f = ---;
        if !closed && (i1 == 0 || i1 == points.count - 1) {
            n = points[i1].normal;
        } else {
            p0 := points[i0];
            p1 := points[i1];
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

        if has_middle_part {
            v := PushVertex(draw_list);
            v.position = points[i1].position + n * half_inner_thickness;
            v.color = color;

            v = PushVertex(draw_list);
            v.position = points[i1].position - n * half_inner_thickness;
            v.color = color;

            if blur_sides & .Exterior {
                v = PushVertex(draw_list);
                v.position = points[i1].position + n * (half_inner_thickness + blur_size);
                v.color = color_alpha0;
            }

            if blur_sides & .Interior {
                v = PushVertex(draw_list);
                v.position = points[i1].position - n * (half_inner_thickness + blur_size);
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

                if !(blur_sides & .Exterior) {
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

                if blur_sides & .Exterior {
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

                if blur_sides & .Interior {
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

            if blur_sides & .Exterior {
                v = PushVertex(draw_list);
                v.position = points[i1].position + n * blur_size;
                v.color = color_alpha0;
            }

            if blur_sides & .Interior {
                v = PushVertex(draw_list);
                v.position = points[i1].position - n * blur_size;
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

                if !(blur_sides & .Exterior) {
                    i1_interior = i1_exterior;
                    i2_interior = i2_exterior;
                }

                if blur_sides & .Exterior {
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

                if blur_sides & .Interior {
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
}

DrawConvexPolygon :: inline (
    draw_list : *VtxDrawList,
    points : []PathPoint,
    color : RGBA8,
    blur_size := 1.0
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
    draw_list : *VtxDrawList,
    points : []PathPoint,
    $get_color : (index : int, data : *void) -> RGBA8,
    get_color_data : *void,
    $get_tex_coords : (index : int, data : *void) -> Vec2f,
    get_tex_coords_data : *void,
    blur_size := 1.0
) #no_abc {
    if points.count < 3 {
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

    num_vertices := points.count * 2;
    ReserveVertices(draw_list, num_vertices);

    blur_size = max(blur_size, 0);
    i0 : u32 = xx (points.count - 1);
    i1 : u32 = 0;
    while i1 < points.count {
        defer {
            i0 = i1;
            i1 += 1;
        }

        color := inline get_color(i1, get_color_data);
        color_alpha0 := SetAlpha(color, 0);

        tex_coords := inline get_tex_coords(i1, get_tex_coords_data);

        n0 := points[i0].normal;
        n1 := points[i1].normal;
        n := (n0 + n1) * 0.5;
        n *= blur_size * 0.5;

        // Inner
        v := PushVertex(draw_list);
        v.position = points[i1].position - n;
        v.color = color;
        v.tex_coords = tex_coords;

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

TriangleSides :: enum_flags {
    P0P1;
    P1P2;
    P2P0;

    All :: P0P1 | P1P2 | P2P0;
}

DrawTriangle :: inline (
    draw_list : *VtxDrawList,
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
    draw_list : *VtxDrawList,
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
}

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
        points[i0].normal.x = d.y;
        points[i0].normal.y = -d.x;

        if !closed && i1 == points.count - 1 {
            points[i1].normal.x = d.y;
            points[i1].normal.y = -d.x;
        }
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
    Half_Circle_Points_Count :: 50;
    Half_Circle_Points :: #run () -> [Half_Circle_Points_Count + 1]Vec2f {
        result : [Half_Circle_Points_Count + 1]Vec2f = ---;

        for i : 0..Half_Circle_Points_Count {
            theta := i / cast(float, Half_Circle_Points_Count) * PI * 0.5;
            result[i] = Vec2f.{cos(theta), sin(theta)};
        }

        return result;
    }();

    SamplePointsArray :: (angle : float) -> Vec2f {
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
        normal := Vec2f.{cos(-start_angle - angle * 0.5), sin(-start_angle - angle * 0.5)};
        array_add(points, .{position=center, normal=normal});
        return;
    }

    if num_segments == 0 {
        num_segments = max(cast(int, radius / 3) * 3, 8);
    }

    connected := angle == PI * 2;
    iterations := ifx connected then num_segments - 1 else num_segments;

    if num_segments <= Half_Circle_Points.count {
        for i : 0..iterations {
            theta := i / cast(float, num_segments) * angle;
            p := SamplePointsArray(-start_angle - theta);
            array_add(points, .{position=center + p * radius, normal=p});
        }
    } else {
        for i : 0..iterations {
            theta := i / cast(float, num_segments) * angle;
            p := Vec2f.{cos(-start_angle - theta), sin(-start_angle - theta)};
            array_add(points, .{position=center + p * radius, normal=p});
        }
    }
}
