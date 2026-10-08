DebugViewStyle :: struct {
    gap : s8;
    properties : struct {
        padding : Vec4b;
        background_colors : BoxColors;
        alternate_background_colors : BoxColors;
    };
    selected_overlay : BoxStyle;
    hovered_overlay : BoxStyle;
}

DebugViewData :: struct {
    selected_node_id : ID;
    hovered_node_id : ID;
}

#scope_file

FormatNodeIDShort :: inline (id : ID) -> FormatInt {
    return FormatInt.{value=id & 0xffffffff, base=16, minimum_digits=8};
}

FormatNodeID :: inline (id : ID) -> FormatInt {
    return FormatInt.{value=id, base=16, minimum_digits=16};
}

FormatSize1D :: (size : Size1D) -> string {
    if #complete size.kind == {
    case .Pixels;
        return tprint("% px", size.value);
    case .FitChildren;
        return "fit";
    case .FillParent;
        return tprint("fill (%)", size.value);
    case .ParentPercent;
        return tprint("%\%", size.value * 100);
    }
}

FormatColor :: inline (color : RGBA8) -> string {
    return tprint("#%", FormatInt.{value=color, base=16, minimum_digits=8});
}

#scope_export

DebugViewNodeTree :: (data : *DebugViewData, parent : *Node) {
    NodeTree :: (data : *DebugViewData, parent : *Node, node : *Node, name := "") {
        PushID(node.id);
        defer PopID();

        flags := TreeNodeFlags.InteractOnArrow;
        if node.tree_last_frame.num_children == 0 {
            flags |= .Leaf;
        }
        if data.selected_node_id == node.id {
            flags |= .Selected;
        }

        label := ifx name then name else tprint("%", FormatNodeIDShort(node.id));
        if node.text {
            label = tprint("% \"%\"", label, node.text);
        }

        tree, item := TreeNode(parent, label, flags);

        if ButtonBehavior(item).released {
            data.selected_node_id = node.id;
        }
        if item.state_flags & .Focused {
            data.hovered_node_id = node.id;
        }

        if tree {
            for :PrevFrameChildren node {
                NodeTree(data, tree, it);
            }
        }
    }

    for :Windows context.omg {
        PushID(GetID(it));
        defer PopID();

        window_tree := TreeNode(parent, PlatformGetWindowTitle(it.platform_handle ,, temp));
        if !window_tree {
            continue;
        }

        NodeTree(data, window_tree, it.root_node, "Nodes");
        NodeTree(data, window_tree, it.popup_root_node, "Popups");
    }
}

DebugViewProperty :: (parent : *Node, alternate : *bool, label : string, fmt_str : string, args : ..Any, style : *DebugViewStyle = null, location := #caller_location) {
    label_and_content_style := GetStyle("label_and_content", LabelAndContentStyle).*;
    label_and_content_style.padding = style.properties.padding;

    content, container := LabelAndContent(parent, label, style=*label_and_content_style, location=location);
    if alternate.* {
        SetBackgroundColors(container, style.properties.alternate_background_colors);
    } else {
        SetBackgroundColors(container, style.properties.background_colors);
    }
    alternate.* = !alternate.*;

    Text(content, fmt_str, ..args);
}

DebugViewNodeProperties :: (data : *DebugViewData, parent : *Node, style : *DebugViewStyle) {
    if data.selected_node_id == 0 {
        container := GetNode(parent);
        SetSize(container, SizeFill(), SizeFill());
        SetChildAlign(container, 0.5, 0.5);

        Text(container, "No node selected");

        return;
    }

    selected_node := GetNodeByGlobalID(data.selected_node_id);
    if !selected_node {
        data.selected_node_id = 0;
        return;
    }

    SetLayout(parent, .TopToBottom);

    alternate := false;
    DebugViewProperty(parent, *alternate, "ID", "%", FormatNodeID(selected_node.id), style=style);
    DebugViewProperty(parent, *alternate, "Local ID", "%", FormatNodeID(selected_node.local_id), style=style);
    DebugViewProperty(parent, *alternate, "Parent ID", "%", ifx selected_node.parent then FormatNodeID(selected_node.parent.id) else FormatInt.{value=0}, style=style);
    DebugViewProperty(parent, *alternate, "Z Index", "%", selected_node.z_index, style=style);
    DebugViewProperty(parent, *alternate, "State Flags", "%", selected_node.state_flags, style=style);
    DebugViewProperty(parent, *alternate, "Mouse Interaction", "%", selected_node.interacting_mouse_buttons, style=style);

    HorizontalSeparatorText(parent, "Layout");
    DebugViewProperty(parent, *alternate, "Size", "%, %", selected_node.size.x, selected_node.size.y, style=style);
    DebugViewProperty(parent, *alternate, "Children Size", "%, %", selected_node.children_size.x, selected_node.children_size.y, style=style);
    DebugViewProperty(parent, *alternate, "Relative Position", "%, %", selected_node.relative_position.x, selected_node.relative_position.y, style=style);
    DebugViewProperty(parent, *alternate, "Rect", "%, %, %, %", selected_node.rect.x, selected_node.rect.y, selected_node.rect.z, selected_node.rect.w, style=style);
    DebugViewProperty(parent, *alternate, "Clipped Rect", "%, %, %, %", selected_node.clipped_rect.x, selected_node.clipped_rect.y, selected_node.clipped_rect.z, selected_node.clipped_rect.w, style=style);

    HorizontalSeparatorText(parent, "Properties");
    DebugViewProperty(parent, *alternate, "Font", "%, size %", ifx selected_node.font then selected_node.font.name else "null", selected_node.text_size, style=style);
    DebugViewProperty(parent, *alternate, "Text", "\"%\"", selected_node.text, style=style);
    DebugViewProperty(parent, *alternate, "Flags", "%", selected_node.flags, style=style);
    DebugViewProperty(parent, *alternate, "Offset", "%, %", selected_node.offset.x, selected_node.offset.y, style=style);
    DebugViewProperty(parent, *alternate, "Scroll", "%, %", selected_node.scroll.x, selected_node.scroll.y, style=style);
    DebugViewProperty(parent, *alternate, "Child align", "%, %", selected_node.child_align.x, selected_node.child_align.y, style=style);
    DebugViewProperty(parent, *alternate, "Desired size", "%, %", FormatSize1D(selected_node.desired_size.x), FormatSize1D(selected_node.desired_size.y), style=style);
    DebugViewProperty(parent, *alternate, "Min Size", "%0%, %0%", selected_node.min_size.x, ifx selected_node.min_size_fit & .Width then " fit", selected_node.min_size.y, ifx selected_node.min_size_fit & .Height then " fit", style=style);
    DebugViewProperty(parent, *alternate, "Max Size", "%, %", selected_node.max_size.x, selected_node.max_size.y, style=style);
    DebugViewProperty(parent, *alternate, "Child Gap", "%, %", selected_node.child_gap.x, selected_node.child_gap.y, style=style);
    DebugViewProperty(parent, *alternate, "Padding", "%, %", selected_node.padding.x, selected_node.padding.y, style=style);
    DebugViewProperty(parent, *alternate, "Layout mode", "%", selected_node.child_layout_mode, style=style);

    HorizontalSeparatorText(parent, "Styling");
    DebugViewProperty(parent, *alternate, "Image UV", "%, %, %, %", selected_node.image_uv_bounds.x, selected_node.image_uv_bounds.y, selected_node.image_uv_bounds.z, selected_node.image_uv_bounds.w, style=style);
    DebugViewProperty(parent, *alternate, "Corner Radiuses", "%, %, %, %", selected_node.corner_radiuses.x, selected_node.corner_radiuses.y, selected_node.corner_radiuses.z, selected_node.corner_radiuses.w, style=style);
    DebugViewProperty(parent, *alternate, "Background Colors", "% tl, % tr, % bl, % br", FormatColor(selected_node.background_colors.top_left), FormatColor(selected_node.background_colors.top_right), FormatColor(selected_node.background_colors.bottom_left), FormatColor(selected_node.background_colors.bottom_right), style=style);
    DebugViewProperty(parent, *alternate, "Border Colors", "% tl, % tr, % bl, % br", FormatColor(selected_node.border_colors.top_left), FormatColor(selected_node.border_colors.top_right), FormatColor(selected_node.border_colors.bottom_left), FormatColor(selected_node.border_colors.bottom_right), style=style);
    DebugViewProperty(parent, *alternate, "Border Size", "%", selected_node.border_size, style=style);
    DebugViewProperty(parent, *alternate, "Border Inset", "%", selected_node.border_inset, style=style);
    DebugViewProperty(parent, *alternate, "Outer Shadow", "%, % px, offset %, %", FormatColor(selected_node.outer_shadow_color), selected_node.outer_shadow_size, selected_node.outer_shadow_offset.x, selected_node.outer_shadow_offset.y, style=style);
    DebugViewProperty(parent, *alternate, "Inner Shadow", "%, % px", FormatColor(selected_node.inner_shadow_color), selected_node.inner_shadow_size, style=style);
    DebugViewProperty(parent, *alternate, "Text", "%, %", FormatColor(selected_node.text_color), selected_node.text_effects, style=style);
}

DebugViewOverlay :: (data : *DebugViewData, window : *Window, style : *DebugViewStyle) {
    selected_node := GetNodeByGlobalID(data.selected_node_id);
    if selected_node {
        overlay := GetPopupNode(window);
        BringForward(overlay);

        SetSize(overlay, SizePx(selected_node.size.x), SizePx(selected_node.size.y));
        overlay.offset = selected_node.rect.xy;

        Apply(overlay, style.selected_overlay);
    } else {
        data.selected_node_id = 0;
    }

    hovered_node := GetNodeByGlobalID(data.hovered_node_id);
    if hovered_node {
        overlay := GetPopupNode(window);
        BringForward(overlay);

        SetSize(overlay, SizePx(hovered_node.size.x), SizePx(hovered_node.size.y));
        overlay.offset = hovered_node.rect.xy;

        Apply(overlay, style.hovered_overlay);
    } else {
        data.hovered_node_id = 0;
    }
}

DebugView :: (parent : *Node, style : *DebugViewStyle = null, location := #caller_location) {
    EnsureStyle(*style, "debug_view");

    parent = GetNode(parent, location);
    SetLayout(parent, .LeftToRight);
    SetSize(parent, SizeFill(), SizeFill());
    SetChildGap(parent, style.gap);

    data := AddUserData(parent, DebugViewData);
    data.hovered_node_id = 0;

    node_tree, node_tree_container := ScrollView(parent);
    SetWidth(node_tree_container, SizeFill(0.3));
    DebugViewNodeTree(data, node_tree);

    properties, properties_container := ScrollView(parent);
    SetWidth(properties_container, SizeFill(0.7));
    DebugViewNodeProperties(data, properties, style);

    DebugViewOverlay(data, parent.window, style);
}

DebugViewWindow :: (window : *Window, str_id : string, opened : *bool, style : *DebugViewStyle = null) {
    subwindow := Subwindow(window, "Debug View", str_id, opened, initial_size=.{600,400});
    if !subwindow {
        return;
    }

    DebugView(subwindow);
}
