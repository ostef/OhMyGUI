g_pose_empty_icon : OMG.TextureHandle;
g_pose_filled_icon : OMG.TextureHandle;

g_graph : Graph;

Graph :: struct {
    nodes : [..]*GraphNode;
}

GraphNode :: struct {
    id : u64;
    title : string;
    description : string;
    color : OMG.RGBA8;
    inputs : [..]*GraphNodePort;
    outputs : [..]*GraphNodePort;
}

GraphNodePort :: struct {
    Direction :: enum {
        Input;
        Output;
    }

    name : string;
    description : string;
    direction : Direction;
    type : *Type_Info;
    connections : [..]*GraphNodePort;
}

CreateNode :: (graph : *Graph) -> *GraphNode {
    #import "Random";

    node := New(GraphNode);
    node.id = random_get();
    array_add(*graph.nodes, node);

    return node;
}

AddInputPort :: (node : *GraphNode, name : string, type : Type) -> *GraphNodePort {
    port := New(GraphNodePort);
    port.name = name;
    port.direction = .Input;
    port.type = cast(*Type_Info, type);
    array_add(*node.inputs, port);

    return port;
}

AddOutputPort :: (node : *GraphNode, name : string, type : Type) -> *GraphNodePort {
    port := New(GraphNodePort);
    port.name = name;
    port.direction = .Output;
    port.type = cast(*Type_Info, type);
    array_add(*node.inputs, port);

    return port;
}

GetInputPort :: (node : *GraphNode, name : string) -> *GraphNodePort {
    for node.inputs {
        if it.name == name {
            return it;
        }
    }

    return null;
}

GetOutputPort :: (node : *GraphNode, name : string) -> *GraphNodePort {
    for node.outputs {
        if it.name == name {
            return it;
        }
    }

    return null;
}

CanPortTypesConnect :: (a : *Type_Info, b : *Type_Info) -> bool {
    if a.type == {
    case .INTEGER;
        return a.type == b.type;
    case .FLOAT;
        return a.type == b.type;
    case .BOOL;
        return a == b;
    case .STRING;
        return a == b;
    case .STRUCT;
        return a == b;
    case .ENUM;
        return a == b || b.type == .INTEGER;
    case;
        return false;
    }
}

Disconnect :: (port : *GraphNodePort, index : int) {
    connected := port.connections[index];
    for connected.connections {
        if it == port {
            remove it;
            break;
        }
    }

    array_unordered_remove_by_index(*port.connections, index);
}

Connect :: (a : *GraphNodePort, b : *GraphNodePort) -> bool {
    if !a || !b {
        return true;
    }

    if a.direction == b.direction {
        log_error("Cannot connect % port to % port", a.direction, b.direction);
        return true;
    }

    if !CanPortTypesConnect(a.type, b.type) {
        log_error("Cannot connect port of type % to port of type %", cast(*Type, *a.type).*, cast(*Type, *b.type).*);
        return true;
    }

    if a.direction == .Input && a.connections.count > 0 {
        while a.connections.count > 0 {
            Disconnect(a, 0);
        }
    }

    if b.direction == .Input && b.connections.count > 0 {
        while b.connections.count > 0 {
            Disconnect(b, 0);
        }
    }

    array_add(*a.connections, b);
    array_add(*b.connections, a);

    return true;
}

NodeGraphNode :: (parent : *OMG.Node, id : OMG.ID) -> *OMG.Node {
    node, is_new := OMG.GetNode(parent, id);
    if is_new {
        node.offset = .{100, 100};
    }

    OMG.SetBackgroundColor(node, OMG.ColorU32(0.1, 0.1, 0.1, 0.8));
    OMG.SetOuterShadowColor(node, OMG.ColorU32(0, 0, 0, 0.5));
    OMG.SetOuterShadowOffset(node, 0, 5);
    OMG.SetOuterShadowSize(node, 10);
    OMG.SetInnerShadowColor(node, OMG.ColorU32(0, 0, 0, 0.4));
    OMG.SetInnerShadowSize(node, 6); // @Todo @Fix: larger than corner radius produces intersecting triangles
    OMG.SetCornerRadius(node, 6);
    OMG.SetLayout(node, .TopToBottom);
    OMG.SetSize(node, OMG.SizeFit(), OMG.SizeFit());
    OMG.SetPadding(node, 2, 2);

    using _ := OMG.DragBehavior(node, node, .{xy=parent.rect.xy, zw=parent.rect.zw - node.size});
    if pressed || node.state_flags & .ActiveLastFrame {
        node.state_flags |= .Active;
    }

    if held && OMG.GetModState() == .Ctrl {
        node.offset.x = OMG.Snap(node.offset.x, 10);
        node.offset.y = OMG.Snap(node.offset.y, 10);
    }

    if OMG.HasCursorControl(node) {
        OMG.SetCursor(OMG.GetSystemCursor(.ResizeAll));
    }

    should_deactivate := OMG.IsKeyPressed(.Escape);
    should_deactivate |= OMG.IsAnyMouseButtonPressed() && !OMG.IsInTree(context.omg.mouse_hovered_node, node);
    if should_deactivate {
        node.state_flags &= ~.Active;
    }

    if node.state_flags & .Active {
        OMG.SetBorderColors(node,
            OMG.ColorU32(0.870, 0.718, 0.0435, 1), OMG.ColorU32(0.870, 0.718, 0.0435, 1),
            OMG.ColorU32(0.870, 0.512, 0.0435, 1), OMG.ColorU32(0.870, 0.512, 0.0435, 1)
        );
        OMG.SetBorderSize(node, 2);
        OMG.SetBorderInset(node, -2);
    } else {
        OMG.SetBorderColor(node, 0);
    }

    menu := OMG.ContextMenu(node);
    if menu {
        OMG.MenuItem(menu, "Delete");
        OMG.MenuItem(menu, "Duplicate");
    }

    return node;
}

NodeGraphTitleBar :: (parent : *OMG.Node, title : string, color : OMG.RGBA8) -> *OMG.Node {
    node := OMG.GetNode(parent, "title_bar");
    OMG.SetBackgroundColors(node, color, OMG.Darken(color, 0.15), OMG.Darken(color, 0.3), OMG.Darken(color, 0.5));
    OMG.SetBorderColors(node, OMG.ColorU32(1, 1, 1, 0.6), OMG.ColorU32(1, 1, 1, 0.6), 0, 0);
    OMG.SetBorderSize(node, 1);
    OMG.SetInnerShadowColor(node, OMG.SetAlpha(color, 0.6));
    OMG.SetInnerShadowSize(node, 5);
    OMG.SetSize(node, OMG.SizeFill(), OMG.SizeFit());
    OMG.SetMinWidthFit(node);
    OMG.SetMinWidth(node, 100);
    OMG.SetPadding(node, 12, 4);
    OMG.SetChildAlign(node, 0, 0.5);
    OMG.SetCornerRadiuses(node, parent.corner_radiuses.x, parent.corner_radiuses.y, 0, 0);

    style := OMG.GetStyle("text", OMG.TextStyle).*;
    style.font = OMG.GetFont("__default_medium");
    style.text_size = 14;
    OMG.Text(node, "%", title, style=*style);

    return node;
}

NodeGraphBody :: (parent : *OMG.Node) -> body : *OMG.Node {
    body := OMG.GetNode(parent, "body");
    OMG.SetLayout(body, .LeftToRight);
    OMG.SetSize(body, OMG.SizeFill(), OMG.SizeFit());
    OMG.SetMinWidthFit(body);

    inputs := OMG.GetNode(body, "inputs");
    OMG.SetLayout(inputs, .TopToBottom);
    OMG.SetSize(inputs, OMG.SizeFill(), OMG.SizeFit());
    OMG.SetMinWidth(inputs, 60);
    OMG.SetMinWidthFit(inputs);
    OMG.SetPadding(inputs, 6, 6);
    OMG.SetChildGap(inputs, 4, 4);

    outputs := OMG.GetNode(body, "outputs");
    OMG.SetLayout(outputs, .TopToBottom);
    OMG.SetSize(outputs, OMG.SizeFill(), OMG.SizeFit());
    OMG.SetMinWidth(outputs, 60);
    OMG.SetMinWidthFit(outputs);
    OMG.SetPadding(outputs, 6, 6);
    OMG.SetChildGap(outputs, 4, 4);

    return body;
}

NodeGraphPort :: (parent : *OMG.Node, port : *GraphNodePort) -> *OMG.Node {
    Draw :: (draw_list : *OMG.DrawList, node : *OMG.Node, $direction : GraphNodePort.Direction) {
        center := (node.rect.xy + node.rect.zw) * 0.5;

        if node.image {
            prev_texture := OMG.SetTexture(draw_list, node.image);
            defer OMG.SetTexture(draw_list, prev_texture);

            OMG.DrawRect(draw_list, node.rect, node.background_colors, uv_bounds=node.image_uv_bounds);
        } else {
            radius := 0.5 * min(node.rect.z - node.rect.x, node.rect.w - node.rect.y) * 0.5;
            OMG.DrawCircleOutline(draw_list, center, radius, node.background_colors.top_left, 2);
        }

        if node.state_flags & .Hot {
            OMG.PushDisableClipBox(draw_list);

            p0 := center;
            p3 := OMG.GetMousePosition(node.window);
            p1 := OMG.Vec2f.{lerp(p0.x, p3.x, 0.6), p0.y};
            p2 := OMG.Vec2f.{lerp(p3.x, p0.x, 0.6), p3.y};

            if direction == .Input {
                p1.x = min(p0.x - 100, p1.x);
                p2.x = max(p3.x + 100, p2.x);
            } else {
                p1.x = max(p0.x + 100, p1.x);
                p2.x = min(p3.x - 100, p2.x);
            }

            OMG.PathPushBezierCubic(*draw_list.path, p0, p1, p2, p3);
            OMG.DrawPolygonLine(draw_list, draw_list.path, false, 2, node.background_colors.top_left);
            array_reset_keeping_memory(*draw_list.path);

            OMG.PopClipBox(draw_list);
        }
    }

    parent = ifx port.direction == .Input then OMG.FindNode(parent, "inputs") else OMG.FindNode(parent, "outputs");

    container := OMG.GetNode(parent, cast(OMG.ID, port));
    OMG.SetSize(container, OMG.SizeFill(), OMG.SizeFit());
    OMG.SetMinWidthFit(container);
    OMG.SetChildAlign(container, 0, 0.5);
    OMG.SetPadding(container, 5, 2);
    OMG.SetChildGap(container, 5, 0);
    container.flags |= .NoPaddedClip;

    if port.description {
        OMG.FocusTooltip(container, "Type: %\n%", cast(*Type, *port.type).*, port.description);
    } else {
        OMG.FocusTooltip(container, "Type: %", cast(*Type, *port.type).*);
    }

    if port.direction == .Input {
        OMG.SetLayout(container, .LeftToRight);
    } else {
        OMG.SetLayout(container, .RightToLeft);
    }

    knob := OMG.GetNode(container);
    OMG.SetSize(knob, OMG.SizePx(20), OMG.SizePx(20));
    SetPortStyle(port, knob);

    if port.direction == .Input {
        OMG.SetDraw(knob, #bake_arguments Draw(direction=.Input));
    } else {
        OMG.SetDraw(knob, #bake_arguments Draw(direction=.Output));
    }

    OMG.Text(container, "%", port.name);

    using _ := OMG.ButtonBehavior(container);
    if container.state_flags & (.Focused | .Hot) {
        color := knob.background_colors.top_left;
        left_color := ifx port.direction == .Input then OMG.SetAlpha(color, 0.7) else OMG.SetAlpha(color, 0);
        right_color := ifx port.direction == .Input then OMG.SetAlpha(color, 0) else OMG.SetAlpha(color, 0.7);
        OMG.SetBackgroundColors(container, left_color, right_color, left_color, right_color);
    } else {
        OMG.SetBackgroundColor(container, 0);
    }

    knob.state_flags |= container.state_flags;

    return container;
}

ShowGraphNode :: (parent : *OMG.Node, graph_node : *GraphNode) {
    node := NodeGraphNode(parent, cast(OMG.ID, graph_node));
    if graph_node.description {
        OMG.FocusTooltip(node, "%", graph_node.description);
    }

    NodeGraphTitleBar(node, graph_node.title, graph_node.color);

    body := NodeGraphBody(node);
    for graph_node.inputs {
        NodeGraphPort(body, it);
    }

    for graph_node.outputs {
        NodeGraphPort(body, it);
    }
}

AnimPose :: struct {}

SetPortStyle :: (port : *GraphNodePort, node : *OMG.Node) {
    if port.type.type == {
    case .FLOAT;
        OMG.SetBackgroundColor(node, OMG.ColorU32(0.0435, 0.870, 0.209, 1));

    case .INTEGER;
        OMG.SetBackgroundColor(node, OMG.ColorU32(0.161, 0.950, 0.635, 1));

    case .BOOL;
        OMG.SetBackgroundColor(node, OMG.ColorU32(0.720, 0.115, 0.115, 1));

    case .STRING;
        OMG.SetBackgroundColor(node, OMG.ColorU32(0.772, 0.218, 0.910, 1));

    case .ENUM;
        OMG.SetBackgroundColor(node, OMG.ColorU32(0.163, 0.740, 0.480, 1));

    case .STRUCT;
        if port.type == type_info(AnimPose) {
            OMG.SetBackgroundColor(node, OMG.ColorU32(1,1,1,1));
            OMG.SetImage(node, ifx port.connections.count > 0 then g_pose_filled_icon else g_pose_empty_icon);
        } else if port.type == type_info(Vector2) || port.type == type_info(Vector3) || port.type == type_info(Vector4) {
            OMG.SetBackgroundColor(node, OMG.ColorU32(0.910, 0.813, 0.0819, 1));
        } else if port.type == type_info(Quaternion) {
            OMG.SetBackgroundColor(node, OMG.ColorU32(0.525, 0.380, 1.00, 1));
        } else {
            OMG.SetBackgroundColor(node, OMG.ColorU32(0.130, 0.333, 1.00, 1));
        }
    }
}

CreateBlendSpacePlayerNode :: (graph : *Graph) -> *GraphNode {
    node := CreateNode(graph);
    node.title = "Blend Space Player";
    node.description = "Play a blend space";
    node.color = OMG.ColorU32(0.178, 0.810, 0.399, 1);
    AddInputPort(node, "X", float);
    AddInputPort(node, "Y", float);
    AddOutputPort(node, "Pose", AnimPose);

    return node;
}

CreateAnimationPlayerNode :: (graph : *Graph) -> *GraphNode {
    node := CreateNode(graph);
    node.title = "Animation Player";
    node.description = "Play an animation clip";
    node.color = OMG.ColorU32(0.178, 0.810, 0.399, 1);
    AddInputPort(node, "Speed", float);
    AddOutputPort(node, "Pose", AnimPose);

    return node;
}

CreateBlendPosesNode :: (graph : *Graph) -> *GraphNode {
    node := CreateNode(graph);
    node.title = "Blend Poses";
    node.description = "Blend two poses together";
    node.color = OMG.ColorU32(0.772, 0.780, 0.655, 1);
    AddInputPort(node, "A", AnimPose);
    AddInputPort(node, "B", AnimPose);
    AddInputPort(node, "Alpha", float);
    AddOutputPort(node, "Pose", AnimPose);

    return node;
}

NodeGraphFrame :: () {
    if !g_pose_empty_icon {
        g_pose_empty_icon = OMG.LoadImageFromFile("pose_empty_icon.png");
    }
    if !g_pose_filled_icon {
        g_pose_filled_icon = OMG.LoadImageFromFile("pose_filled_icon.png");
    }

    window := OMG.GetWindow(g_window);
    popups := OMG.GetPopupRoot(window);

    background := OMG.GetNode(window);
    background = OMG.GetNode(background); // Context menu does not work on the root node
    OMG.SetSize(background, OMG.SizeFill(), OMG.SizeFill());
    OMG.SetBackgroundColor(background, OMG.ColorU32(0.15, 0.15, 0.15, 1));
    OMG.SetInnerShadowColor(background, OMG.ColorU32(0, 0, 0, 0.3));
    OMG.SetInnerShadowSize(background, 50);
    OMG.SetTextColor(background, OMG.ColorU32(0.2, 0.2, 0.2, 1));

    OMG.SetDraw(background, (draw_list : *OMG.DrawList, node : *OMG.Node) {
        OMG.DrawNodeDefault(draw_list, node);

        line_color := node.text_color;

        ix := 0;
        x := node.rect.x;
        while x < node.rect.z {
            defer {
                x += 10;
                ix += 1;
            }

            if ix % 10 == 0 {
                continue;
            }

            y0 := node.rect.y;
            y1 := node.rect.w;

            OMG.DrawLine(draw_list, .{x + 0.5, y0}, .{x + 0.5, y1}, 1, line_color);
        }

        iy := 0;
        y := node.rect.y;
        while y < node.rect.w {
            defer {
                y += 10;
                iy += 1;
            }

            if iy % 10 == 0 {
                continue;
            }

            x0 := node.rect.x;
            x1 := node.rect.z;

            OMG.DrawLine(draw_list, .{x0, y + 0.5}, .{x1, y + 0.5}, 1, line_color);
        }

        line_color = OMG.Darken(line_color, 0.2);

        x = node.rect.x;
        while x < node.rect.z {
            defer x += 100;

            OMG.DrawLine(draw_list, .{x + 0.5, node.rect.y}, .{x + 0.5, node.rect.w}, 1, line_color);

        }

        y = node.rect.y;
        while y < node.rect.w {
            defer y += 100;

            OMG.DrawLine(draw_list, .{node.rect.x, y + 0.5}, .{node.rect.z, y + 0.5}, 1, line_color);
        }
    });

    stats := OMG.GetNode(background);
    OMG.SetLayout(stats, .TopToBottom);
    OMG.SetPadding(stats, 20, 20);

    OMG.Text(stats, "% nodes", context.omg.node_pool.count);
    OMG.Text(stats, "FPS: %", cast(int, 1 / g_delta_time));
    OMG.Text(stats, "CPU: % ms", (g_user_time + context.omg.total_time_last_frame) * 1000);
    OMG.Text(stats, "\tUser: % ms", g_user_time * 1000);
    OMG.Text(stats, "\tRender: % ms", context.omg.total_time_last_frame * 1000);
    OMG.Text(stats, "\t\tLayout: % ms", context.omg.layout_time_last_frame * 1000);
    OMG.Text(stats, "\t\tDraw: % ms", context.omg.draw_time_last_frame * 1000);
    OMG.Text(stats, "\t\tOther: % ms", (context.omg.total_time_last_frame - context.omg.layout_time_last_frame - context.omg.draw_time_last_frame) * 1000);
    OMG.Text(stats, "GPU: % ms", g_gpu_time * 1000);
    OMG.Text(stats, "Num vertices: %", context.omg.num_vertices_last_frame);
    OMG.Text(stats, "Num indices: %", context.omg.num_indices_last_frame);

    for g_graph.nodes {
        ShowGraphNode(popups, it);
    }

    menu := OMG.ContextMenu(background);
    if menu {
        if OMG.MenuItem(menu, "Blend Space Player") {
            CreateBlendSpacePlayerNode(*g_graph);
        }
        if OMG.MenuItem(menu, "Animation Player") {
            CreateAnimationPlayerNode(*g_graph);
        }
        if OMG.MenuItem(menu, "Blend Poses") {
            CreateBlendPosesNode(*g_graph);
        }
    }
}
