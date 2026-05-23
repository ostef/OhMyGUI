Theme :: struct {
    styles : Table(string, Any);
}

SetStyle :: (theme : *Theme, name : string, value : Any) {
    table_set(*theme.styles, name, value);
}

GetStyle :: (theme : *Theme, name : string, $T : Type) -> *T {
    exists, any := table_find(*theme.styles, name);
    if !exists {
        return null;
    }

    if any.type != type_info(T) {
        return null;
    }

    return xx any.value_pointer;
}

BoxStyle :: struct {
    padding : Vec4f;
    child_gap : Vec2f;

    corner_radiuses : Vec4f;
    background_color : u32;
    border_color : u32;
    border_size : float;
    border_inset : float;
    outer_shadow_blur : float;
    outer_shadow_offset : Vec2f;
    outer_shadow_color : u32;
}

Apply :: inline (node : *Node, style : BoxStyle) {
    node.padding = style.padding;
    node.child_gap = style.child_gap;
    node.corner_radiuses = style.corner_radiuses;
    node.background_color = style.background_color;
    node.border_color = style.border_color;
    node.border_size = style.border_size;
    node.border_inset = style.border_inset;
    node.outer_shadow_blur = style.outer_shadow_blur;
    node.outer_shadow_offset = style.outer_shadow_offset;
    node.outer_shadow_color = style.outer_shadow_color;
}

TextStyle :: struct {
    font : *Font;
    text_size : float;
    text_color : u32;
    outer_shadow_blur : float;
    outer_shadow_offset : Vec2f;
    outer_shadow_color : u32;
}

Apply :: inline (node : *Node, style : TextStyle) {
    node.font = style.font;
    node.text_size = style.text_size;
    node.text_color = style.text_color;
    node.outer_shadow_blur = style.outer_shadow_blur;
    node.outer_shadow_offset = style.outer_shadow_offset;
    node.outer_shadow_color = style.outer_shadow_color;
}

StateStyle :: struct(T : Type) {
    active : T;
    hot : T;
    focused : T;
    disabled : T;
    normal : T;

    #overlay(active)
    states : [Num_Node_States]T;
}

// AnimateProc :: #type (a : float, b : float, t : float) -> float;

// AnimateStyle :: (a : $T, b : T, time : float, speed : float, animate : AnimateProc) {
//     t := time / speed;

//     #insert -> string {
//         AppendAnimate :: (

//         builder : String_Builder;

//         info := type_info(T);
//         for info.members {
//             type := it.type;
//             if type == type_info(Vec2f) {
//             } else if type == type_info(Vec4f) {
//             } else if type == type_info(RGBA8) {
//             } else if type.kind == {
//             }
//         }

//         return builder_to_string(*builder);
//     }
// }
