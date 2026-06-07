TextureHandle :: u64;

BoxDrawing :: struct {
    size : Vec2f;
    position : Vec2f;
    corner_radiuses : Vec4f;
    background_color : RGBA8;
    border_color : RGBA8;
    border_size : float;
    border_inset : float;
    outer_shadow_color : RGBA8;
    outer_shadow_offset : Vec2f;
    outer_shadow_blur : float;
    clip_box_index : s32;
}

ShaderBoxDrawing :: struct {
    size_and_position : Vec4f;
    corner_radiuses : Vec4f;
    clip_box_index : s32;
    background_color : u32;
    border_size_and_inset : Vec2f;
    border_color : u32;
    outer_shadow_color : u32;
    outer_shadow_offset : Vec2f;
    outer_shadow_blur : float;
    padding : [3]u32;
}

ClipBox :: struct {
    bounds : Vec4f;
    corner_radiuses : Vec4f;
}

ShaderClipBox :: ClipBox;

GlyphDrawing :: struct {
    bounds : Vec4f;
    uv_bounds : Vec4f;
    sdf_range : Vec2f;
    color : u32;
    outer_shadow_color : u32;
    outer_shadow_offset : Vec2f;
    outer_shadow_blur : float;
    clip_box_index : s32;
}

ShaderGlyphDrawing :: GlyphDrawing;

DrawCall :: struct {
    kind : enum {
        Box;
        Glyph;
    };

    first : u32;
    last : u32;
    texture : TextureHandle;
}

DrawList :: struct {
    draw_calls : [..]DrawCall;
    boxes : [..]BoxDrawing;
    clip_boxes : [..]ClipBox;
    clip_box_stack : [..]s32;
    glyphs : [..]GlyphDrawing;

    gpu_buffer_clip_boxes_offset : u32;
    gpu_buffer_boxes_offset : u32;
    gpu_buffer_glyphs_offset : u32;
}

InitDrawList :: (list : *DrawList) {
    list.draw_calls.allocator = context.allocator;
    list.boxes.allocator = context.allocator;
    list.clip_boxes.allocator = context.allocator;
    list.clip_box_stack.allocator = context.allocator;
    list.glyphs.allocator = context.allocator;
}

DestroyDrawList :: (list : *DrawList) {
    array_free(list.draw_calls);
    array_free(list.boxes);
    array_free(list.clip_boxes);
    array_free(list.clip_box_stack);
    array_free(list.glyphs);
    list.* = .{};
}

ClearDrawList :: (list : *DrawList) {
    array_reset_keeping_memory(*list.draw_calls);
    array_reset_keeping_memory(*list.boxes);
    array_reset_keeping_memory(*list.clip_boxes);
    array_reset_keeping_memory(*list.clip_box_stack);
    array_reset_keeping_memory(*list.glyphs);

    list.gpu_buffer_clip_boxes_offset = 0;
    list.gpu_buffer_boxes_offset = 0;
    list.gpu_buffer_glyphs_offset = 0;
}

GetCurrentDrawCall :: (list : *DrawList) -> *DrawCall {
    if list.draw_calls.count <= 0 {
        return null;
    }
    return *list.draw_calls[list.draw_calls.count - 1];
}

GetCurrentClipBoxIndex :: (list : *DrawList) -> s32 {
    if list.clip_box_stack.count <= 0 {
        return -1;
    }
    return list.clip_box_stack[list.clip_box_stack.count - 1];
}

PushClipBox :: (list : *DrawList, bounds : Vec4f, corner_radiuses : Vec4f = .{}) {
    box := array_add(*list.clip_boxes);
    box.bounds = bounds;
    box.corner_radiuses = corner_radiuses;

    current_index := GetCurrentClipBoxIndex(list);
    if current_index >= 0 {
        box.bounds = ClipRect(box.bounds, list.clip_boxes[current_index].bounds);
    }

    array_add(*list.clip_box_stack, xx (list.clip_boxes.count - 1));
}

PopClipBox :: (list : *DrawList) {
    pop(*list.clip_box_stack);
}

DrawBox :: (list : *DrawList, box : BoxDrawing, texture : TextureHandle = 0) -> int {
    if (box.background_color & 0xff) == 0
    && ((box.border_color & 0xff) == 0 || box.border_size <= 0)
    && (box.outer_shadow_color & 0xff) == 0 {
        return -1;
    }

    draw_call := GetCurrentDrawCall(list);
    if !draw_call || draw_call.kind != .Box || draw_call.texture != texture {
        draw_call = array_add(*list.draw_calls);
        draw_call.kind = .Box;
        draw_call.first = xx list.boxes.count;
        draw_call.texture = texture;
    }

    draw_call.last = xx list.boxes.count;

    ptr := array_add(*list.boxes);
    ptr.* = box;
    ptr.clip_box_index = GetCurrentClipBoxIndex(list);

    return list.boxes.count - 1;
}

DrawGlyph :: (list : *DrawList, glyph : GlyphDrawing, texture : TextureHandle) -> int {
    if (glyph.color & 0xff) == 0 && (glyph.outer_shadow_color & 0xff) == 0 {
        return -1;
    }

    draw_call := GetCurrentDrawCall(list);
    if !draw_call || draw_call.kind != .Glyph || draw_call.texture != texture {
        draw_call = array_add(*list.draw_calls);
        draw_call.kind = .Glyph;
        draw_call.first = xx list.glyphs.count;
        draw_call.texture = texture;
    }

    draw_call.last = xx list.glyphs.count;

    ptr := array_add(*list.glyphs);
    ptr.* = glyph;
    ptr.clip_box_index = GetCurrentClipBoxIndex(list);

    return list.glyphs.count - 1;
}

DrawText :: (list : *DrawList, font : *Font, position : Vec2f, size : float, text : string, color : RGBA8, outer_shadow_color : RGBA8 = 0, outer_shadow_offset := Vec2f.{0,0}, outer_shadow_blur := 0.0) {
    if !font || ((color & 0xff) == 0 && (outer_shadow_color & 0xff) == 0) {
        return;
    }

    sdf_range := font.sdf_range * size;

    iter : TextGlyphIterator;
    iter.font = font;
    iter.size = size;
    iter.text = text;
    for iter {
        glyph_position := position + iter.pen + it.hori_bearing * iter.size;
        glyph_position += it.size * iter.size * 0.5;

        bounds := Vec4f.{
            xy=glyph_position - it.texture_size * iter.size * 0.5,
            zw=glyph_position + it.texture_size * iter.size * 0.5,
        };

        DrawGlyph(list, .{
                bounds=bounds,
                uv_bounds=it.uv_rect,
                sdf_range=.{sdf_range, -sdf_range},
                color=color,
                outer_shadow_color=outer_shadow_color,
                outer_shadow_offset=outer_shadow_offset,
                outer_shadow_blur=outer_shadow_blur,
            },
            font.texture
        );
    }
}

DrawNodeDefault :: (draw_list : *DrawList, node : *Node) {
    DrawBox(draw_list, .{
        size=node.rect.zw - node.rect.xy,
        position=(node.rect.xy + node.rect.zw) * 0.5,
        corner_radiuses=node.corner_radiuses,
        background_color=node.background_color,
        border_color=node.border_color,
        border_size=node.border_size,
        border_inset=node.border_inset,
        outer_shadow_color=node.outer_shadow_color,
        outer_shadow_offset=node.outer_shadow_offset,
        outer_shadow_blur=node.outer_shadow_blur,
    });

    DrawText(draw_list,
        node.font,
        node.rect.xy,
        node.text_size,
        node.text,
        node.text_color,
        node.outer_shadow_color,
        node.outer_shadow_offset,
        node.outer_shadow_blur
    );
}


CopyDrawListShaderData :: (list : *DrawList, clip_boxes : *[..]ShaderClipBox, boxes : *[..]ShaderBoxDrawing, glyphs : *[..]ShaderGlyphDrawing) {
    list.gpu_buffer_clip_boxes_offset = xx clip_boxes.count;
    list.gpu_buffer_boxes_offset = xx boxes.count;
    list.gpu_buffer_glyphs_offset = xx glyphs.count;

    for list.clip_boxes {
        array_add(clip_boxes, it);
    }

    for list.boxes {
        box := array_add(boxes);
        box.size_and_position.xy = it.size;
        box.size_and_position.zw = it.position;
        box.corner_radiuses = it.corner_radiuses;
        box.background_color = it.background_color;
        box.border_color = it.border_color;
        box.border_size_and_inset.x = it.border_size;
        box.border_size_and_inset.y = it.border_inset;
        box.outer_shadow_color = it.outer_shadow_color;
        box.outer_shadow_offset = it.outer_shadow_offset;
        box.outer_shadow_blur = it.outer_shadow_blur;
        box.clip_box_index = ifx it.clip_box_index >= 0
            then cast(s32, list.gpu_buffer_clip_boxes_offset) + it.clip_box_index
            else -1;
    }

    for list.glyphs {
        glyph := array_add(glyphs);
        glyph.* = it;
        glyph.clip_box_index = ifx it.clip_box_index >= 0
            then cast(s32, list.gpu_buffer_clip_boxes_offset) + it.clip_box_index
            else -1;
    }
}

SendDrawCommands :: (list : *DrawList, buffer_handle : GLuint, clip_boxes_offset : u32, boxes_offset : u32, glyphs_offset : u32, viewport_w : u32, viewport_h : u32) {
    glBindBufferRange(GL_SHADER_STORAGE_BUFFER, 0, buffer_handle, xx clip_boxes_offset, xx (list.clip_boxes.count * size_of(ShaderClipBox)));
    glBindBufferRange(GL_SHADER_STORAGE_BUFFER, 1, buffer_handle, xx boxes_offset, xx (list.boxes.count * size_of(ShaderBoxDrawing)));
    glBindBufferRange(GL_SHADER_STORAGE_BUFFER, 2, buffer_handle, xx glyphs_offset, xx (list.glyphs.count * size_of(ShaderGlyphDrawing)));

    current_shader : GLuint = 0;
    current_texture : GLuint = 0;

    for list.draw_calls {
        first_instance : u32;

        num_instances := it.last - it.first + 1;
        if num_instances <= 0 {
            continue;
        }

        if it.kind == {
        case .Box;
            first_instance = it.first + list.gpu_buffer_boxes_offset;

            if current_shader != g_shader_box {
                glUseProgram(g_shader_box);
                current_shader = g_shader_box;

                u_viewport_size := glGetUniformLocation(current_shader, "u_viewport_size");
                if u_viewport_size >= 0 {
                    glUniform2f(u_viewport_size, xx viewport_w, xx viewport_h);
                }
            }

        case .Glyph;
            first_instance = it.first + list.gpu_buffer_glyphs_offset;

            if current_shader != g_shader_glyph {
                glUseProgram(g_shader_glyph);
                current_shader = g_shader_glyph;

                u_viewport_size := glGetUniformLocation(current_shader, "u_viewport_size");
                if u_viewport_size >= 0 {
                    glUniform2f(u_viewport_size, xx viewport_w, xx viewport_h);
                }
            }
        }

        if current_texture != it.texture {
            glBindTextureUnit(0, xx it.texture);
            current_texture = xx it.texture;
        }

        glDrawArraysInstancedBaseInstance(GL_TRIANGLES, 0, 6, xx num_instances, xx first_instance);
    }
}
