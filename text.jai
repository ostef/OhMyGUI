#import "freetype";
#import "Hash_Table";
#import "String";

// https://freetype.org/freetype2/docs/glyphs/glyphs-3.html

Font :: struct {
    filename : string;
    name : string;
    glyph_map : Table(u32, Glyph);
    resolution : u32;
    ascent, descent : float;
    texture : GLuint;
}

FontConfig :: struct {
    resolution : u32 = 20;
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
    size : Vec2f;
    hori_bearing : Vec2f;
    vert_bearing : Vec2f;
    hori_advance : float;
    vert_advance : float;
    uv_rect : Vec4f;
}

g_ft_lib : FT_Library;

LoadFontFromFile :: (filename : string, config : FontConfig) -> *Font {
    if !g_ft_lib {
        ft_err := FT_Init_FreeType(*g_ft_lib);
        if ft_err != xx FT_Err.Ok {
            log_error("Could not initialize FreeType");
            return null;
        }
    }

    if config.resolution == 0 {
        return null;
    }

    ft_face : FT_Face;
    ft_err := FT_New_Face(g_ft_lib, to_c_string(filename ,, temp), 0, *ft_face);
    if ft_err != xx FT_Err.Ok {
        return null;
    }

    defer FT_Done_Face(ft_face);

    FT_Set_Pixel_Sizes(ft_face, 0, config.resolution);

    font := New(Font);
    font.filename = filename;
    font.name = basename(filename);
    font.resolution = config.resolution;
    font.ascent = (ft_face.size.metrics.ascender >> 6) / cast(float, config.resolution);
    font.descent = (ft_face.size.metrics.descender >> 6) / cast(float, config.resolution);

    packer : RectPacker;
    packer.width = config.atlas_width;
    packer.height = config.atlas_height;
    packer.data = xx alloc(packer.width * packer.height);
    memset(packer.data, 0, packer.width * packer.height);
    defer free(packer.data);

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

    glTextureParameteri(font.texture, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTextureParameteri(font.texture, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    array_add(*context.omg.fonts, font);

    return font;
}

GetFont :: (name : string) -> *Font {
    for context.omg.fonts {
        if it.name == name {
            return it;
        }
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

    FT_Render_Glyph(ft_face.glyph, .SDF);

    slot := ft_face.glyph;

    glyph : Glyph;
    glyph.codepoint = codepoint;

    glyph.size.x = (slot.metrics.width >> 6) / cast(float, font.resolution);
    glyph.size.y = (slot.metrics.height >> 6) / cast(float, font.resolution);
    glyph.hori_bearing.x = (slot.metrics.horiBearingX >> 6) / cast(float, font.resolution);
    glyph.hori_bearing.y = (slot.metrics.horiBearingY >> 6) / cast(float, font.resolution);
    glyph.vert_bearing.x = (slot.metrics.vertBearingX >> 6) / cast(float, font.resolution);
    glyph.vert_bearing.y = (slot.metrics.vertBearingY >> 6) / cast(float, font.resolution);
    glyph.hori_advance = (slot.metrics.horiAdvance >> 6) / cast(float, font.resolution);
    glyph.vert_advance = (slot.metrics.vertAdvance >> 6) / cast(float, font.resolution);

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
        bitmap_x / cast(float, packer.width), (bitmap_y + bitmap_height) / cast(float, packer.height),
        bitmap_width / cast(float, packer.width), -(bitmap_height / cast(float, packer.height)),
    };

    return table_add(*font.glyph_map, codepoint, glyph);
}
