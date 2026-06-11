#import "freetype";
#import "Hash_Table";
#import "String";

// https://freetype.org/freetype2/docs/glyphs/glyphs-3.html

Font :: struct {
    prev : *Font;
    next : *Font;

    filename : string;
    name : string;
    glyph_map : Table(u32, Glyph);
    resolution : u32;
    ascent, descent : float;
    space_advance : float;
    desired_underline_position : float;
    desired_underline_thickness : float;
    sdf_range : float;
    texture : GLuint;
}

FontConfig :: struct {
    resolution : u32 = 64;
    glyph_ranges := GlyphRange.[.{0x20, 0x7f}];
    atlas_width : u32 = 1024;
    atlas_height : u32 = 1024;
}

GlyphRange :: struct {
    start : u32;
    end : u32;
}

Glyph :: struct {
    codepoint : u32;
    texture_size : Vec2f;
    size : Vec2f;
    hori_bearing : Vec2f;
    vert_bearing : Vec2f;
    hori_advance : float;
    vert_advance : float;
    uv_rect : Vec4f;
}

g_ft_lib : FT_Library;

GetDefaultFont :: inline () -> *Font {
    return GetFont("__default");
}

LoadDefaultFont :: () -> *Font {
    Default_Font_Contents :: #run ReadCompileTimeFile("Roboto-Regular.ttf");

    return LoadFontFromMemory("__default", Default_Font_Contents, .{});
}

LoadFontFromFile :: (filename : string, config : FontConfig) -> *Font {
    return LoadFontFromFile(basename(filename), filename, config);
}

LoadFontFromFile :: (name : string, filename : string, config : FontConfig) -> *Font {
    #import "File";
    contents, ok := read_entire_file(filename);
    if !ok {
        return null;
    }

    font := LoadFontFromMemory(name, contents, config);
    if font {
        font.filename = filename;
    }

    return font;
}

LoadFontFromMemory :: (name : string, data : string, config : FontConfig) -> *Font {
    if !g_ft_lib {
        ft_err := FT_Init_FreeType(*g_ft_lib);
        if ft_err != xx FT_Err.Ok {
            log_error("Could not initialize FreeType");
            return null;
        }

        // @Todo: setting this works (get returns the value we passed) but does not change the resulting SDF
        // Find what's wrong
        // ft_err = FT_Property_Set(g_ft_lib, "sdf", "spread", *sdf_spread);
        // if ft_err != xx FT_Err.Ok {
        //     log_error("Could not set spread");
        // }
    }

    existing_font := GetFont(name);
    if existing_font {
        return existing_font;
    }

    if config.resolution == 0 {
        return null;
    }

    ft_face : FT_Face;
    ft_err := FT_New_Memory_Face(g_ft_lib, data.data, data.count, 0, *ft_face);
    if ft_err != xx FT_Err.Ok {
        return null;
    }

    defer FT_Done_Face(ft_face);

    FT_Set_Pixel_Sizes(ft_face, 0, config.resolution);

    font := New(Font);
    font.name = name;
    font.resolution = config.resolution;
    font.ascent = FractToFloat(ft_face.size.metrics.ascender) / cast(float, config.resolution);
    font.descent = -FractToFloat(ft_face.size.metrics.descender) / cast(float, config.resolution);
    font.desired_underline_position = ft_face.underline_position * Fract16ToFloat(ft_face.size.metrics.y_scale);
    font.desired_underline_position = -FractToFloat(xx font.desired_underline_position) / cast(float, config.resolution);
    font.desired_underline_thickness = ft_face.underline_thickness * Fract16ToFloat(ft_face.size.metrics.y_scale);
    font.desired_underline_thickness = FractToFloat(xx font.desired_underline_thickness) / cast(float, config.resolution);

    print("% %\n", font.desired_underline_position, font.desired_underline_thickness);

    sdf_spread : s32 = 8;
    // FT_Property_Get(g_ft_lib, "sdf", "spread", *sdf_spread);
    font.sdf_range = sdf_spread / cast(float, font.resolution);

    packer : RectPacker;
    packer.width = config.atlas_width;
    packer.height = config.atlas_height;
    packer.data = xx alloc(packer.width * packer.height);
    memset(packer.data, 0, packer.width * packer.height);
    defer free(packer.data);

    space_glyph := LoadGlyph(font, #char " ", ft_face, *packer);
    if space_glyph {
        font.space_advance = space_glyph.hori_advance;
    }

    LoadGlyph(font, Unicode_Replacement, ft_face, *packer);

    for range : config.glyph_ranges {
        for i : range.start..range.end {
            LoadGlyph(font, i, ft_face, *packer);
        }
    }

    glCreateTextures(GL_TEXTURE_2D, 1, *font.texture);

    label := tprint("Font SDF Texture '%'", font.name);
    glObjectLabel(GL_TEXTURE, font.texture, xx label.count, label.data);

    glTextureStorage2D(font.texture, 1, GL_R8, packer.width, packer.height);

    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTextureSubImage2D(font.texture, 0, 0, 0, packer.width, packer.height, GL_RED, GL_UNSIGNED_BYTE, packer.data);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 4);

    glTextureParameteri(font.texture, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTextureParameteri(font.texture, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    font.next = context.omg.fonts;
    if font.next {
        font.next.prev = font;
    }
    context.omg.fonts = font;

    return font;
}

DestroyFont :: (font : *Font) {
    if font.prev {
        font.prev.next = font.next;
    }
    if font.next {
        font.next.prev = font.prev;
    }

    if context.omg.fonts == font {
        context.omg.fonts = font.next;
    }

    glDeleteTextures(1, *font.texture);

    deinit(*font.glyph_map);

    free(font);
}

GetFont :: (name : string) -> *Font {
    font := context.omg.fonts;
    while font {
        if font.name == name {
            return font;
        }

        font = font.next;
    }

    return null;
}

GetGlyph :: (font : *Font, codepoint : u32) -> *Glyph {
    return table_find_pointer(*font.glyph_map, codepoint);
}

#scope_file

RectPacker :: struct {
    data : *u8;
    width : u32;
    height : u32;
    cursor_x : u32;
    cursor_y : u32;
    row_end : u32;
}

PackRect :: (packer : *RectPacker, width : u32, height : u32) -> bool, x : u32, y : u32 {
    if width > packer.width || height > packer.height {
        return false, 0, 0;
    }

    if packer.cursor_y + height > packer.height {
        return false, 0, 0;
    }

    if packer.cursor_x + width > packer.width {
        packer.cursor_x = 0;
        packer.cursor_y = packer.row_end;
    }

    if packer.cursor_y + height > packer.height {
        return false, 0, 0;
    }

    x := packer.cursor_x;
    y := packer.cursor_y;

    packer.row_end = max(packer.row_end, packer.cursor_y + height);
    packer.cursor_x += width;

    return true, x, y;
}

BlitGlyph :: (packer : *RectPacker, bitmap_data : *u8, bitmap_x : u32, bitmap_y : u32, bitmap_width : u32, bitmap_height : u32, bitmap_pitch : u32) {
    if bitmap_width == 0 || bitmap_height == 0 {
        return;
    }

    for y : 0..bitmap_height - 1 {
        for x : 0..bitmap_width - 1 {
            index := (bitmap_y + y) * packer.width + (bitmap_x + x);
            value := bitmap_data[y * bitmap_pitch + x];
            packer.data[index] = value;
        }
    }
}

FractToFloat :: inline (value : s64) -> float {
    return cast(float, value) / 64.0;
}

Fract16ToFloat :: inline (value : s64) -> float {
    return cast(float, value) / 65536.0;
}

LoadGlyph :: (font : *Font, codepoint : u32, ft_face : FT_Face, packer : *RectPacker) -> *Glyph {
    existing_glyph := table_find_pointer(*font.glyph_map, codepoint);
    if existing_glyph {
        return existing_glyph;
    }

    ft_err := FT_Load_Char(ft_face, codepoint, FT_LOAD_DEFAULT);
    if ft_err != xx FT_Err.Ok {
        log_error("Could not load glyph for codepoint %", codepoint);
        return null;
    }

    FT_Render_Glyph(ft_face.glyph, .NORMAL); // We want the SDF rendering to be based off the bitmap
    FT_Render_Glyph(ft_face.glyph, .SDF);

    slot := ft_face.glyph;

    glyph : Glyph;
    glyph.codepoint = codepoint;

    glyph.texture_size.x = slot.bitmap.width / cast(float, font.resolution);
    glyph.texture_size.y = slot.bitmap.rows / cast(float, font.resolution);
    glyph.size.x = FractToFloat(slot.metrics.width) / cast(float, font.resolution);
    glyph.size.y = FractToFloat(slot.metrics.height) / cast(float, font.resolution);
    glyph.hori_bearing.x =  FractToFloat(slot.metrics.horiBearingX) / cast(float, font.resolution);
    glyph.hori_bearing.y = -FractToFloat(slot.metrics.horiBearingY) / cast(float, font.resolution);
    glyph.vert_bearing.x =  FractToFloat(slot.metrics.vertBearingX) / cast(float, font.resolution);
    glyph.vert_bearing.y = -FractToFloat(slot.metrics.vertBearingY) / cast(float, font.resolution);
    glyph.hori_advance = FractToFloat(slot.metrics.horiAdvance) / cast(float, font.resolution);
    glyph.vert_advance = FractToFloat(slot.metrics.vertAdvance) / cast(float, font.resolution);

    assert(slot.bitmap.pixel_mode == xx FT_Pixel_Mode_.GRAY);
    bitmap_width := slot.bitmap.width;
    bitmap_height := slot.bitmap.rows;
    bitmap_pitch := cast(u32, slot.bitmap.pitch);
    packed, bitmap_x, bitmap_y := PackRect(packer, bitmap_width, bitmap_height);
    if !packed {
        log_error("Could not pack glyph for codepoint % into atlas (size is %, %)", codepoint, bitmap_width, bitmap_height);
        return null;
    }

    BlitGlyph(packer, slot.bitmap.buffer, bitmap_x, bitmap_y, bitmap_width, bitmap_height, bitmap_pitch);

    glyph.uv_rect = .{
        bitmap_x / cast(float, packer.width), bitmap_y / cast(float, packer.height),
        bitmap_width / cast(float, packer.width), bitmap_height / cast(float, packer.height),
    };
    glyph.uv_rect.zw += glyph.uv_rect.xy;

    return table_add(*font.glyph_map, codepoint, glyph);
}

#scope_export

TextGlyphIterator :: struct {
    font : *Font;
    text : string;
    size : float;
    include_newlines : bool;
    pen : Vec2f;
    bounds : Vec2f;
}

ResetPen :: (using iter : *TextGlyphIterator) {
    pen = .{};
    bounds = .{};
}

IterText :: inline (node : *Node) -> TextGlyphIterator {
    return .{
        font=node.font,
        text=node.text,
        size=node.text_size,
    };
}

Newline :: (iter : *TextGlyphIterator) {
    iter.bounds.x = max(iter.bounds.x, iter.pen.x);

    iter.pen.x = 0;
    iter.pen.y += (iter.font.descent + iter.font.ascent) * iter.size;

    iter.bounds.y = max(iter.bounds.y, iter.pen.y + iter.font.descent * iter.size);
}

for_expansion :: (iter : *TextGlyphIterator, body : Code, flags : For_Flags) #expand {
    `it : *Glyph;

    if !iter.font {
        return;
    }

    iter.pen.y = iter.font.ascent * iter.size;

    for codepoint, `it_index : iter.text {
        if codepoint == {
        case #char "\n";
            if iter.include_newlines {
                dummy_glyph := Glyph.{codepoint=codepoint};
                it = *dummy_glyph;
                #insert body;
            }

            Newline(iter);

        case #char "\t";
            iter.pen.x = SnapUp(iter.pen.x + iter.font.space_advance * iter.size, iter.font.space_advance * 4 * iter.size);
            iter.bounds.x = max(iter.bounds.x, iter.pen.x);
            iter.bounds.y = max(iter.bounds.y, iter.pen.y + iter.font.descent * iter.size);

        case;
            glyph := GetGlyph(iter.font, codepoint);
            if !glyph {
                glyph = GetGlyph(iter.font, Unicode_Replacement);
                if !glyph {
                    continue;
                }
            }

            it = glyph;
            #insert body;

            iter.bounds.x = max(iter.bounds.x, iter.pen.x + glyph.hori_advance * iter.size, iter.pen.x + (glyph.hori_bearing.x + glyph.size.x) * iter.size);
            iter.bounds.y = max(iter.bounds.y, iter.pen.y + iter.font.descent * iter.size);

            iter.pen.x += glyph.hori_advance * iter.size;
        }
    }

    iter.bounds.y = max(iter.bounds.y, iter.pen.y + iter.font.descent * iter.size);
}

CalculateTextSize :: (font : *Font, size : float, text : string) -> Vec2f {
    iter : TextGlyphIterator;
    iter.font = font;
    iter.size = size;
    iter.text = text;
    for iter {}

    return iter.bounds;
}
