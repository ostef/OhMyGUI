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

TriangleDrawing :: struct {
    p0 : Vec2f;
    p1 : Vec2f;
    p2 : Vec2f;
    c0 : RGBA8;
    c1 : RGBA8;
    c2 : RGBA8;
    clip_box_index : s32;
}

ShaderTriangleDrawing :: TriangleDrawing;

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
        Boxes;
        Glyphs;
        Triangles;
    };

    first : u32;
    last : u32;
    texture : TextureHandle;
}

DrawList :: struct {
    draw_calls : [..]DrawCall;
    clip_boxes : [..]ClipBox;
    clip_box_stack : [..]s32;
    boxes : [..]BoxDrawing;
    glyphs : [..]GlyphDrawing;
    triangles : [..]TriangleDrawing;

    gpu_buffer_clip_boxes_offset : u32;
    gpu_buffer_boxes_offset : u32;
    gpu_buffer_glyphs_offset : u32;
    gpu_buffer_triangles_offset : u32;
}

InitDrawList :: (draw_list : *DrawList) {
    draw_list.draw_calls.allocator = context.allocator;
    draw_list.boxes.allocator = context.allocator;
    draw_list.clip_boxes.allocator = context.allocator;
    draw_list.clip_box_stack.allocator = context.allocator;
    draw_list.glyphs.allocator = context.allocator;
    draw_list.triangles.allocator = context.allocator;
}

DestroyDrawList :: (draw_list : *DrawList) {
    array_free(draw_list.draw_calls);
    array_free(draw_list.boxes);
    array_free(draw_list.clip_boxes);
    array_free(draw_list.clip_box_stack);
    array_free(draw_list.glyphs);
    array_free(draw_list.triangles);
    draw_list.* = .{};
}

ClearDrawList :: (draw_list : *DrawList) {
    array_reset_keeping_memory(*draw_list.draw_calls);
    array_reset_keeping_memory(*draw_list.boxes);
    array_reset_keeping_memory(*draw_list.clip_boxes);
    array_reset_keeping_memory(*draw_list.clip_box_stack);
    array_reset_keeping_memory(*draw_list.glyphs);
    array_reset_keeping_memory(*draw_list.triangles);

    draw_list.gpu_buffer_clip_boxes_offset = 0;
    draw_list.gpu_buffer_boxes_offset = 0;
    draw_list.gpu_buffer_glyphs_offset = 0;
    draw_list.gpu_buffer_triangles_offset = 0;
}

GetCurrentDrawCall :: (draw_list : *DrawList) -> *DrawCall {
    if draw_list.draw_calls.count <= 0 {
        return null;
    }
    return *draw_list.draw_calls[draw_list.draw_calls.count - 1];
}

GetCurrentClipBoxIndex :: (draw_list : *DrawList) -> s32 {
    if draw_list.clip_box_stack.count <= 0 {
        return -1;
    }
    return draw_list.clip_box_stack[draw_list.clip_box_stack.count - 1];
}

PushClipBox :: (draw_list : *DrawList, bounds : Vec4f, corner_radiuses : Vec4f = .{}) {
    box := array_add(*draw_list.clip_boxes);
    box.bounds = bounds;
    box.corner_radiuses = corner_radiuses;

    current_index := GetCurrentClipBoxIndex(draw_list);
    if current_index >= 0 {
        box.bounds = ClipRect(box.bounds, draw_list.clip_boxes[current_index].bounds);
    }

    array_add(*draw_list.clip_box_stack, xx (draw_list.clip_boxes.count - 1));
}

PopClipBox :: (draw_list : *DrawList) {
    pop(*draw_list.clip_box_stack);
}

DrawBox :: inline (draw_list : *DrawList, position : Vec2f, size : Vec2f, color : RGBA8, corner_radiuses := Vec4f.{}) -> int {
    return DrawBox(draw_list, .{
            size=size,
            position=position,
            background_color=color,
            corner_radiuses=corner_radiuses,
        });
}

DrawBox :: (draw_list : *DrawList, box : BoxDrawing, texture : TextureHandle = 0) -> int {
    if (box.background_color & 0xff) == 0
    && ((box.border_color & 0xff) == 0 || box.border_size <= 0)
    && (box.outer_shadow_color & 0xff) == 0 {
        return -1;
    }

    draw_call := GetCurrentDrawCall(draw_list);
    if !draw_call || draw_call.kind != .Boxes || draw_call.texture != texture {
        draw_call = array_add(*draw_list.draw_calls);
        draw_call.kind = .Boxes;
        draw_call.first = xx draw_list.boxes.count;
        draw_call.texture = texture;
    }

    draw_call.last = xx draw_list.boxes.count;

    ptr := array_add(*draw_list.boxes);
    ptr.* = box;
    ptr.clip_box_index = GetCurrentClipBoxIndex(draw_list);

    return draw_list.boxes.count - 1;
}

DrawGlyph :: (draw_list : *DrawList, glyph : GlyphDrawing, texture : TextureHandle) -> int {
    if (glyph.color & 0xff) == 0 && (glyph.outer_shadow_color & 0xff) == 0 {
        return -1;
    }

    draw_call := GetCurrentDrawCall(draw_list);
    if !draw_call || draw_call.kind != .Glyphs || draw_call.texture != texture {
        draw_call = array_add(*draw_list.draw_calls);
        draw_call.kind = .Glyphs;
        draw_call.first = xx draw_list.glyphs.count;
        draw_call.texture = texture;
    }

    draw_call.last = xx draw_list.glyphs.count;

    ptr := array_add(*draw_list.glyphs);
    ptr.* = glyph;
    ptr.clip_box_index = GetCurrentClipBoxIndex(draw_list);

    return draw_list.glyphs.count - 1;
}

DrawTriangle :: inline (draw_list : *DrawList, p0 : Vec2f, p1 : Vec2f, p2 : Vec2f, color : RGBA8) -> int {
    return DrawTriangle(draw_list, .{
            p0=p0, p1=p1, p2=p2,
            c0=color, c1=color, c2=color,
        });
}

DrawTriangle :: (draw_list : *DrawList, triangle : TriangleDrawing) -> int {
    if (triangle.c0 & 0xff) == 0 && (triangle.c1 & 0xff) == 0 && (triangle.c2 & 0xff) == 0 {
        return -1;
    }

    draw_call := GetCurrentDrawCall(draw_list);
    if !draw_call || draw_call.kind != .Triangles {
        draw_call = array_add(*draw_list.draw_calls);
        draw_call.kind = .Triangles;
        draw_call.first = xx draw_list.triangles.count;
        draw_call.texture = 0;
    }

    draw_call.last = xx draw_list.triangles.count;

    ptr := array_add(*draw_list.triangles);
    ptr.* = triangle;
    ptr.clip_box_index = GetCurrentClipBoxIndex(draw_list);

    return draw_list.triangles.count - 1;
}

DrawText :: (draw_list : *DrawList, font : *Font, position : Vec2f, size : float, text : string, color : RGBA8, outer_shadow_color : RGBA8 = 0, outer_shadow_offset := Vec2f.{0,0}, outer_shadow_blur := 0.0, effects : TextEffects = 0) {
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

        DrawGlyph(draw_list, .{
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

    if effects {
        ResetPen(*iter);
        iter.include_newlines = true;

        line_start : Vec2f;
        new_line := true;

        for iter {
            if new_line {
                line_start = position + iter.pen;
                new_line = false;
            }

            if it.codepoint == #char "\n" {
                new_line = true;

                line_end := position + iter.pen;

                if effects & .Underline {
                    box_position := (line_start + line_end) * 0.5;
                    box_position.y += (font.desired_underline_position + font.desired_underline_thickness * 0.5) * size;
                    box_size := Vec2f.{
                        line_end.x - line_start.x,
                        max(font.desired_underline_thickness * size, 1),
                    };

                    DrawBox(draw_list, box_position, box_size, color);
                }

                if effects & .Strikethrough {
                    box_position := (line_start + line_end) * 0.5;
                    box_position.y -= font.ascent * 0.35 * size;
                    box_size := Vec2f.{
                        line_end.x - line_start.x,
                        max(font.desired_underline_thickness * size, 1),
                    };

                    DrawBox(draw_list, box_position, box_size, color);
                }
            }
        }

        if !new_line {
            line_end := position + iter.pen;

            if effects & .Underline {
                box_position := (line_start + line_end) * 0.5;
                box_position.y += (font.desired_underline_position + font.desired_underline_thickness * 0.5) * size;
                box_size := Vec2f.{
                    line_end.x - line_start.x,
                    max(font.desired_underline_thickness * size, 1),
                };

                DrawBox(draw_list, box_position, box_size, color);
            }

            if effects & .Strikethrough {
                box_position := (line_start + line_end) * 0.5;
                box_position.y -= font.ascent * 0.35 * size;
                box_size := Vec2f.{
                    line_end.x - line_start.x,
                    max(font.desired_underline_thickness * size, 1),
                };

                DrawBox(draw_list, box_position, box_size, color);
            }
        }
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
        node.outer_shadow_blur,
        node.text_effects
    );
}


CopyDrawListShaderData :: (draw_list : *DrawList, clip_boxes : *[..]ShaderClipBox, boxes : *[..]ShaderBoxDrawing, glyphs : *[..]ShaderGlyphDrawing, triangles : *[..]ShaderTriangleDrawing) {
    draw_list.gpu_buffer_clip_boxes_offset = xx clip_boxes.count;
    draw_list.gpu_buffer_boxes_offset = xx boxes.count;
    draw_list.gpu_buffer_glyphs_offset = xx glyphs.count;
    draw_list.gpu_buffer_triangles_offset = xx triangles.count;

    for draw_list.clip_boxes {
        array_add(clip_boxes, it);
    }

    for draw_list.boxes {
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
            then cast(s32, draw_list.gpu_buffer_clip_boxes_offset) + it.clip_box_index
            else -1;
    }

    for draw_list.glyphs {
        glyph := array_add(glyphs);
        glyph.* = it;
        glyph.clip_box_index = ifx it.clip_box_index >= 0
            then cast(s32, draw_list.gpu_buffer_clip_boxes_offset) + it.clip_box_index
            else -1;
    }

    for draw_list.triangles {
        triangle := array_add(triangles);
        triangle.* = it;
        triangle.clip_box_index = ifx it.clip_box_index >= 0
            then cast(s32, draw_list.gpu_buffer_clip_boxes_offset) + it.clip_box_index
            else -1;
    }
}

SendDrawCommands :: (
    draw_list : *DrawList,
    buffer_handle : GLuint,
    clip_boxes_offset : u32,
    boxes_offset : u32,
    glyphs_offset : u32,
    triangles_offset : u32,
    viewport_w : u32,
    viewport_h : u32
) {
    glBindBufferRange(GL_SHADER_STORAGE_BUFFER, 0, buffer_handle, xx clip_boxes_offset, xx (draw_list.clip_boxes.count * size_of(ShaderClipBox)));
    glBindBufferRange(GL_SHADER_STORAGE_BUFFER, 1, buffer_handle, xx boxes_offset, xx (draw_list.boxes.count * size_of(ShaderBoxDrawing)));
    glBindBufferRange(GL_SHADER_STORAGE_BUFFER, 2, buffer_handle, xx glyphs_offset, xx (draw_list.glyphs.count * size_of(ShaderGlyphDrawing)));
    glBindBufferRange(GL_SHADER_STORAGE_BUFFER, 3, buffer_handle, xx triangles_offset, xx (draw_list.triangles.count * size_of(ShaderTriangleDrawing)));

    current_shader : GLuint = 0;
    current_texture : GLuint = 0;

    for draw_list.draw_calls {
        first_instance : u32;

        num_instances := it.last - it.first + 1;
        if num_instances <= 0 {
            continue;
        }

        num_vertices : u32;

        if it.kind == {
        case .Boxes;
            num_vertices = 6;
            first_instance = it.first + draw_list.gpu_buffer_boxes_offset;

            if current_shader != g_shader_box {
                glUseProgram(g_shader_box);
                current_shader = g_shader_box;

                u_viewport_size := glGetUniformLocation(current_shader, "u_viewport_size");
                if u_viewport_size >= 0 {
                    glUniform2f(u_viewport_size, xx viewport_w, xx viewport_h);
                }
            }

        case .Glyphs;
            num_vertices = 6;
            first_instance = it.first + draw_list.gpu_buffer_glyphs_offset;

            if current_shader != g_shader_glyph {
                glUseProgram(g_shader_glyph);
                current_shader = g_shader_glyph;

                u_viewport_size := glGetUniformLocation(current_shader, "u_viewport_size");
                if u_viewport_size >= 0 {
                    glUniform2f(u_viewport_size, xx viewport_w, xx viewport_h);
                }
            }

        case .Triangles;
            num_vertices = 3;
            first_instance = it.first + draw_list.gpu_buffer_triangles_offset;

            if current_shader != g_shader_triangle {
                glUseProgram(g_shader_triangle);
                current_shader = g_shader_triangle;

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

        glDrawArraysInstancedBaseInstance(GL_TRIANGLES, 0, num_vertices, xx num_instances, xx first_instance);
    }
}
