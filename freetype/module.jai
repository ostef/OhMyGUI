// Freetype 2.12.1

/**************************************************************************
*
* @macro:
*   FT_HAS_HORIZONTAL
*
* @description:
*   A macro that returns true whenever a face object contains horizontal
*   metrics (this is true for all font formats though).
*
* @also:
*   @FT_HAS_VERTICAL can be used to check for vertical metrics.
*
*/
FT_HAS_HORIZONTAL :: inline (face: FT_Face) -> bool {
    return !!(face.face_flags & FT_FACE_FLAG_HORIZONTAL);
}


/**************************************************************************
*
* @macro:
*   FT_HAS_VERTICAL
*
* @description:
*   A macro that returns true whenever a face object contains real
*   vertical metrics (and not only synthesized ones).
*
*/
FT_HAS_VERTICAL :: inline (face: FT_Face) -> bool {
    return !!(face.face_flags & FT_FACE_FLAG_VERTICAL);
}


/**************************************************************************
*
* @macro:
*   FT_HAS_KERNING
*
* @description:
*   A macro that returns true whenever a face object contains kerning data
*   that can be accessed with @FT_Get_Kerning.
*
*/
FT_HAS_KERNING :: inline (face: FT_Face) -> bool {
      return !!(face.face_flags & FT_FACE_FLAG_KERNING);
}


/**************************************************************************
*
* @macro:
*   FT_IS_SCALABLE
*
* @description:
*   A macro that returns true whenever a face object contains a scalable
*   font face (true for TrueType, Type~1, Type~42, CID, OpenType/CFF, and
*   PFR font formats).
*
*/
FT_IS_SCALABLE :: inline (face: FT_Face) -> bool {
      return !!(face.face_flags & FT_FACE_FLAG_SCALABLE);
}


/**************************************************************************
*
* @macro:
*   FT_IS_SFNT
*
* @description:
*   A macro that returns true whenever a face object contains a font whose
*   format is based on the SFNT storage scheme.  This usually means:
*   TrueType fonts, OpenType fonts, as well as SFNT-based embedded bitmap
*   fonts.
*
*   If this macro is true, all functions defined in @FT_SFNT_NAMES_H and
*   @FT_TRUETYPE_TABLES_H are available.
*
*/
FT_IS_SFNT :: inline (face: FT_Face) -> bool {
      return !!(face.face_flags & FT_FACE_FLAG_SFNT);
}


/**************************************************************************
*
* @macro:
*   FT_IS_FIXED_WIDTH
*
* @description:
*   A macro that returns true whenever a face object contains a font face
*   that contains fixed-width (or 'monospace', 'fixed-pitch', etc.)
*   glyphs.
*
*/
FT_IS_FIXED_WIDTH :: inline (face: FT_Face) -> bool {
      return !!(face.face_flags & FT_FACE_FLAG_FIXED_WIDTH);
}


/**************************************************************************
*
* @macro:
*   FT_HAS_FIXED_SIZES
*
* @description:
*   A macro that returns true whenever a face object contains some
*   embedded bitmaps.  See the `available_sizes` field of the @FT_FaceRec
*   structure.
*
*/
FT_HAS_FIXED_SIZES :: inline (face: FT_Face) -> bool {
      return !!(face.face_flags & FT_FACE_FLAG_FIXED_SIZES);
}


/**************************************************************************
*
* @macro:
*   FT_HAS_GLYPH_NAMES
*
* @description:
*   A macro that returns true whenever a face object contains some glyph
*   names that can be accessed through @FT_Get_Glyph_Name.
*
*/
FT_HAS_GLYPH_NAMES :: inline (face: FT_Face) -> bool {
      return !!(face.face_flags & FT_FACE_FLAG_GLYPH_NAMES);
}


/**************************************************************************
*
* @macro:
*   FT_HAS_MULTIPLE_MASTERS
*
* @description:
*   A macro that returns true whenever a face object contains some
*   multiple masters.  The functions provided by @FT_MULTIPLE_MASTERS_H
*   are then available to choose the exact design you want.
*
*/
FT_HAS_MULTIPLE_MASTERS :: inline (face: FT_Face) -> bool {
      return !!(face.face_flags & FT_FACE_FLAG_MULTIPLE_MASTERS);
}


/**************************************************************************
*
* @macro:
*   FT_IS_NAMED_INSTANCE
*
* @description:
*   A macro that returns true whenever a face object is a named instance
*   of a GX or OpenType variation font.
*
*   [Since 2.9] Changing the design coordinates with
*   @FT_Set_Var_Design_Coordinates or @FT_Set_Var_Blend_Coordinates does
*   not influence the return value of this macro (only
*   @FT_Set_Named_Instance does that).
*
* @since:
*   2.7
*
*/
FT_IS_NAMED_INSTANCE :: inline (face: FT_Face) -> bool {
      return !!(face.face_index & 0x7FFF0000);
}


/**************************************************************************
*
* @macro:
*   FT_IS_VARIATION
*
* @description:
*   A macro that returns true whenever a face object has been altered by
*   @FT_Set_MM_Design_Coordinates, @FT_Set_Var_Design_Coordinates, or
*   @FT_Set_Var_Blend_Coordinates.
*
* @since:
*   2.9
*
*/
FT_IS_VARIATION :: inline (face: FT_Face) -> bool {
      return !!(face.face_flags & FT_FACE_FLAG_VARIATION);
}


/**************************************************************************
*
* @macro:
*   FT_IS_CID_KEYED
*
* @description:
*   A macro that returns true whenever a face object contains a CID-keyed
*   font.  See the discussion of @FT_FACE_FLAG_CID_KEYED for more details.
*
*   If this macro is true, all functions defined in @FT_CID_H are
*   available.
*
*/
FT_IS_CID_KEYED :: inline (face: FT_Face) -> bool {
      return !!(face.face_flags & FT_FACE_FLAG_CID_KEYED);
}


/**************************************************************************
*
* @macro:
*   FT_IS_TRICKY
*
* @description:
*   A macro that returns true whenever a face represents a 'tricky' font.
*   See the discussion of @FT_FACE_FLAG_TRICKY for more details.
*
*/
FT_IS_TRICKY :: inline (face: FT_Face) -> bool {
      return !!(face.face_flags & FT_FACE_FLAG_TRICKY);
}


/**************************************************************************
*
* @macro:
*   FT_HAS_COLOR
*
* @description:
*   A macro that returns true whenever a face object contains tables for
*   color glyphs.
*
* @since:
*   2.5.1
*
*/
FT_HAS_COLOR :: inline (face: FT_Face) -> bool {
      return !!(face.face_flags & FT_FACE_FLAG_COLOR);
}


/**************************************************************************
*
* @macro:
*   FT_HAS_SVG
*
* @description:
*   A macro that returns true whenever a face object contains an 'SVG~'
*   OpenType table.
*
* @since:
*   2.12
*/
FT_HAS_SVG :: inline (face: FT_Face) -> bool {
      return !!(face.face_flags & FT_FACE_FLAG_SVG);
}


/**************************************************************************
*
* @macro:
*   FT_HAS_SBIX
*
* @description:
*   A macro that returns true whenever a face object contains an 'sbix'
*   OpenType table *and* outline glyphs.
*
*   Currently, FreeType only supports bitmap glyphs in PNG format for this
*   table (i.e., JPEG and TIFF formats are unsupported, as are
*   Apple-specific formats not part of the OpenType specification).
*
* @note:
*   For backward compatibility, a font with an 'sbix' table is treated as
*   a bitmap-only face.  Using @FT_Open_Face with
*   @FT_PARAM_TAG_IGNORE_SBIX, an application can switch off 'sbix'
*   handling so that the face is treated as an ordinary outline font with
*   scalable outlines.
*
*   Here is some pseudo code that roughly illustrates how to implement
*   'sbix' handling according to the OpenType specification.
*
* ```
*   if ( FT_HAS_SBIX( face ) )
*   {
*     // open font as a scalable one without sbix handling
*     FT_Face       face2;
*     FT_Parameter  param = { FT_PARAM_TAG_IGNORE_SBIX, NULL };
*     FT_Open_Args  args  = { FT_OPEN_PARAMS | ...,
*                             ...,
*                             1, &param };
*
*
*     FT_Open_Face( library, &args, 0, &face2 );
*
*     <sort `face->available_size` as necessary into
*      `preferred_sizes`[*]>
*
*     for ( i = 0; i < face->num_fixed_sizes; i++ )
*     {
*       size = preferred_sizes[i].size;
*
*       error = FT_Set_Pixel_Sizes( face, size, size );
*       <error handling omitted>
*
*       // check whether we have a glyph in a bitmap strike
*       error = FT_Load_Glyph( face,
*                              glyph_index,
*                              FT_LOAD_SBITS_ONLY          |
*                              FT_LOAD_BITMAP_METRICS_ONLY );
*       if ( error == FT_Err_Invalid_Argument )
*         continue;
*       else if ( error )
*         <other error handling omitted>
*       else
*         break;
*     }
*
*     if ( i != face->num_fixed_sizes )
*       <load embedded bitmap with `FT_Load_Glyph`,
*        scale it, display it, etc.>
*
*     if ( i == face->num_fixed_sizes  ||
*          FT_HAS_SBIX_OVERLAY( face ) )
*       <use `face2` to load outline glyph with `FT_Load_Glyph`,
*        scale it, display it on top of the bitmap, etc.>
*   }
* ```
*
* [*] Assuming a target value of 400dpi and available strike sizes 100,
* 200, 300, and 400dpi, a possible order might be [400, 200, 300, 100]:
* scaling 200dpi to 400dpi usually gives better results than scaling
* 300dpi to 400dpi; it is also much faster.  However, scaling 100dpi to
* 400dpi can yield a too pixelated result, thus the preference might be
* 300dpi over 100dpi.
*
* @since:
*   2.12
*/
FT_HAS_SBIX :: inline (face: FT_Face) -> bool {
      return !!(face.face_flags & FT_FACE_FLAG_SBIX);
}


/**************************************************************************
*
* @macro:
*   FT_HAS_SBIX_OVERLAY
*
* @description:
*   A macro that returns true whenever a face object contains an 'sbix'
*   OpenType table with bit~1 in its `flags` field set, instructing the
*   application to overlay the bitmap strike with the corresponding
*   outline glyph.  See @FT_HAS_SBIX for pseudo code how to use it.
*
* @since:
*   2.12
*/
FT_HAS_SBIX_OVERLAY :: inline (face: FT_Face) -> bool {
      return !!(face.face_flags & FT_FACE_FLAG_SBIX_OVERLAY);
}


TTAG_avar :u32: (#char "a" << 24) | (#char "v" << 16) | (#char "a" << 8) | (#char "r");
TTAG_BASE :u32: (#char "B" << 24) | (#char "A" << 16) | (#char "S" << 8) | (#char "E");
TTAG_bdat :u32: (#char "b" << 24) | (#char "d" << 16) | (#char "a" << 8) | (#char "t");
TTAG_BDF  :u32: (#char "B" << 24) | (#char "D" << 16) | (#char "F" << 8) | (#char " ");
TTAG_bhed :u32: (#char "b" << 24) | (#char "h" << 16) | (#char "e" << 8) | (#char "d");
TTAG_bloc :u32: (#char "b" << 24) | (#char "l" << 16) | (#char "o" << 8) | (#char "c");
TTAG_bsln :u32: (#char "b" << 24) | (#char "s" << 16) | (#char "l" << 8) | (#char "n");
TTAG_CBDT :u32: (#char "C" << 24) | (#char "B" << 16) | (#char "D" << 8) | (#char "T");
TTAG_CBLC :u32: (#char "C" << 24) | (#char "B" << 16) | (#char "L" << 8) | (#char "C");
TTAG_CFF  :u32: (#char "C" << 24) | (#char "F" << 16) | (#char "F" << 8) | (#char " ");
TTAG_CFF2 :u32: (#char "C" << 24) | (#char "F" << 16) | (#char "F" << 8) | (#char "2");
TTAG_CID  :u32: (#char "C" << 24) | (#char "I" << 16) | (#char "D" << 8) | (#char " ");
TTAG_cmap :u32: (#char "c" << 24) | (#char "m" << 16) | (#char "a" << 8) | (#char "p");
TTAG_COLR :u32: (#char "C" << 24) | (#char "O" << 16) | (#char "L" << 8) | (#char "R");
TTAG_CPAL :u32: (#char "C" << 24) | (#char "P" << 16) | (#char "A" << 8) | (#char "L");
TTAG_cvar :u32: (#char "c" << 24) | (#char "v" << 16) | (#char "a" << 8) | (#char "r");
TTAG_cvt  :u32: (#char "c" << 24) | (#char "v" << 16) | (#char "t" << 8) | (#char " ");
TTAG_DSIG :u32: (#char "D" << 24) | (#char "S" << 16) | (#char "I" << 8) | (#char "G");
TTAG_EBDT :u32: (#char "E" << 24) | (#char "B" << 16) | (#char "D" << 8) | (#char "T");
TTAG_EBLC :u32: (#char "E" << 24) | (#char "B" << 16) | (#char "L" << 8) | (#char "C");
TTAG_EBSC :u32: (#char "E" << 24) | (#char "B" << 16) | (#char "S" << 8) | (#char "C");
TTAG_feat :u32: (#char "f" << 24) | (#char "e" << 16) | (#char "a" << 8) | (#char "t");
TTAG_FOND :u32: (#char "F" << 24) | (#char "O" << 16) | (#char "N" << 8) | (#char "D");
TTAG_fpgm :u32: (#char "f" << 24) | (#char "p" << 16) | (#char "g" << 8) | (#char "m");
TTAG_fvar :u32: (#char "f" << 24) | (#char "v" << 16) | (#char "a" << 8) | (#char "r");
TTAG_gasp :u32: (#char "g" << 24) | (#char "a" << 16) | (#char "s" << 8) | (#char "p");
TTAG_GDEF :u32: (#char "G" << 24) | (#char "D" << 16) | (#char "E" << 8) | (#char "F");
TTAG_glyf :u32: (#char "g" << 24) | (#char "l" << 16) | (#char "y" << 8) | (#char "f");
TTAG_GPOS :u32: (#char "G" << 24) | (#char "P" << 16) | (#char "O" << 8) | (#char "S");
TTAG_GSUB :u32: (#char "G" << 24) | (#char "S" << 16) | (#char "U" << 8) | (#char "B");
TTAG_gvar :u32: (#char "g" << 24) | (#char "v" << 16) | (#char "a" << 8) | (#char "r");
TTAG_HVAR :u32: (#char "H" << 24) | (#char "V" << 16) | (#char "A" << 8) | (#char "R");
TTAG_hdmx :u32: (#char "h" << 24) | (#char "d" << 16) | (#char "m" << 8) | (#char "x");
TTAG_head :u32: (#char "h" << 24) | (#char "e" << 16) | (#char "a" << 8) | (#char "d");
TTAG_hhea :u32: (#char "h" << 24) | (#char "h" << 16) | (#char "e" << 8) | (#char "a");
TTAG_hmtx :u32: (#char "h" << 24) | (#char "m" << 16) | (#char "t" << 8) | (#char "x");
TTAG_JSTF :u32: (#char "J" << 24) | (#char "S" << 16) | (#char "T" << 8) | (#char "F");
TTAG_just :u32: (#char "j" << 24) | (#char "u" << 16) | (#char "s" << 8) | (#char "t");
TTAG_kern :u32: (#char "k" << 24) | (#char "e" << 16) | (#char "r" << 8) | (#char "n");
TTAG_lcar :u32: (#char "l" << 24) | (#char "c" << 16) | (#char "a" << 8) | (#char "r");
TTAG_loca :u32: (#char "l" << 24) | (#char "o" << 16) | (#char "c" << 8) | (#char "a");
TTAG_LTSH :u32: (#char "L" << 24) | (#char "T" << 16) | (#char "S" << 8) | (#char "H");
TTAG_LWFN :u32: (#char "L" << 24) | (#char "W" << 16) | (#char "F" << 8) | (#char "N");
TTAG_MATH :u32: (#char "M" << 24) | (#char "A" << 16) | (#char "T" << 8) | (#char "H");
TTAG_maxp :u32: (#char "m" << 24) | (#char "a" << 16) | (#char "x" << 8) | (#char "p");
TTAG_META :u32: (#char "M" << 24) | (#char "E" << 16) | (#char "T" << 8) | (#char "A");
TTAG_MMFX :u32: (#char "M" << 24) | (#char "M" << 16) | (#char "F" << 8) | (#char "X");
TTAG_MMSD :u32: (#char "M" << 24) | (#char "M" << 16) | (#char "S" << 8) | (#char "D");
TTAG_mort :u32: (#char "m" << 24) | (#char "o" << 16) | (#char "r" << 8) | (#char "t");
TTAG_morx :u32: (#char "m" << 24) | (#char "o" << 16) | (#char "r" << 8) | (#char "x");
TTAG_MVAR :u32: (#char "M" << 24) | (#char "V" << 16) | (#char "A" << 8) | (#char "R");
TTAG_name :u32: (#char "n" << 24) | (#char "a" << 16) | (#char "m" << 8) | (#char "e");
TTAG_opbd :u32: (#char "o" << 24) | (#char "p" << 16) | (#char "b" << 8) | (#char "d");
TTAG_OS2  :u32: (#char "O" << 24) | (#char "S" << 16) | (#char "/" << 8) | (#char "2");
TTAG_OTTO :u32: (#char "O" << 24) | (#char "T" << 16) | (#char "T" << 8) | (#char "O");
TTAG_PCLT :u32: (#char "P" << 24) | (#char "C" << 16) | (#char "L" << 8) | (#char "T");
TTAG_POST :u32: (#char "P" << 24) | (#char "O" << 16) | (#char "S" << 8) | (#char "T");
TTAG_post :u32: (#char "p" << 24) | (#char "o" << 16) | (#char "s" << 8) | (#char "t");
TTAG_prep :u32: (#char "p" << 24) | (#char "r" << 16) | (#char "e" << 8) | (#char "p");
TTAG_prop :u32: (#char "p" << 24) | (#char "r" << 16) | (#char "o" << 8) | (#char "p");
TTAG_sbix :u32: (#char "s" << 24) | (#char "b" << 16) | (#char "i" << 8) | (#char "x");
TTAG_sfnt :u32: (#char "s" << 24) | (#char "f" << 16) | (#char "n" << 8) | (#char "t");
TTAG_SING :u32: (#char "S" << 24) | (#char "I" << 16) | (#char "N" << 8) | (#char "G");
TTAG_SVG  :u32: (#char "S" << 24) | (#char "V" << 16) | (#char "G" << 8) | (#char " ");
TTAG_trak :u32: (#char "t" << 24) | (#char "r" << 16) | (#char "a" << 8) | (#char "k");
TTAG_true :u32: (#char "t" << 24) | (#char "r" << 16) | (#char "u" << 8) | (#char "e");
TTAG_ttc  :u32: (#char "t" << 24) | (#char "t" << 16) | (#char "c" << 8) | (#char " ");
TTAG_ttcf :u32: (#char "t" << 24) | (#char "t" << 16) | (#char "c" << 8) | (#char "f");
TTAG_TYP1 :u32: (#char "T" << 24) | (#char "Y" << 16) | (#char "P" << 8) | (#char "1");
TTAG_typ1 :u32: (#char "t" << 24) | (#char "y" << 16) | (#char "p" << 8) | (#char "1");
TTAG_VDMX :u32: (#char "V" << 24) | (#char "D" << 16) | (#char "M" << 8) | (#char "X");
TTAG_vhea :u32: (#char "v" << 24) | (#char "h" << 16) | (#char "e" << 8) | (#char "a");
TTAG_vmtx :u32: (#char "v" << 24) | (#char "m" << 16) | (#char "t" << 8) | (#char "x");
TTAG_VVAR :u32: (#char "V" << 24) | (#char "V" << 16) | (#char "A" << 8) | (#char "R");
TTAG_wOFF :u32: (#char "w" << 24) | (#char "O" << 16) | (#char "F" << 8) | (#char "F");
TTAG_wOF2 :u32: (#char "w" << 24) | (#char "O" << 16) | (#char "F" << 8) | (#char "2");

/* used by "Keyboard.dfont" on legacy Mac OS X */
TTAG_0xA5kbd :: cast(u32) ((0xA5 << 24) | (#char "k" << 16) | (#char "b" << 8) | (#char "d"));

/* used by "LastResort.dfont" on legacy Mac OS X */
TTAG_0xA5lst :: cast(u32) ((0xA5 << 24) | (#char "l" << 16) | (#char "s" << 8) | (#char "t"));

#scope_module

ptrdiff_t :: s64;

#if OS == .WINDOWS {
    #load "windows.jai";
} else #if OS == .NN_SWITCH2 {
    #if CPU == .ARM64  #load "switch2.jai";
    else               #load "windows.jai";
} else #if OS == .PS5 {
    #load "ps5.jai";
} else #if OS_IS_UNIX {
    #load "unix.jai";
} else {
    #assert false;
}
