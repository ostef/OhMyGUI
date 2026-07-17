DockSpaceData :: struct {
    split : enum u8 {
        None;
        Horizontal;
        Vertical;
    };
}

DockSpace :: (parent : *Node, str_id : string) -> space : *Node, content : *Node {
    content : *Node;
    node := GetNode(parent, str_id);
    {
        using data := AddUserData(node, DockSpaceData);

        SetSize(node, SizeFill(), SizeFill());
        SetBorderColor(node, 0xffffffff);
        SetBorderSize(node, 1);

        if split == {
        case .None;
            SetLayout(node, .None);

            content = GetNode(node, "content");
            SetSize(content, SizeFill(), SizeFill());

            overlay := GetNode(node, "overlay");
            SetSize(overlay, SizeFill(), SizeFill());

            SetDraw(overlay, (draw_list, node) => {
                if !IsHovered(node) {
                    return;
                }

                mouse := GetMousePosition(node.window);
                mouse -= node.rect.xy;

                top := mouse.y < node.size.y * 0.333333;
                bottom := mouse.y > node.size.y * 0.666666;
                left := mouse.x < node.size.x * 0.333333;
                right := mouse.x > node.size.x * 0.666666;

                if left && !top && !bottom {
                    size := Vec2f.{node.size.x * 0.5, node.size.y};
                    position := node.rect.xy;
                    DrawBox(draw_list, position + size * 0.5, size, ColorU32(0,0,1,0.5));
                }
                if right && !top && !bottom {
                    size := Vec2f.{node.size.x * 0.5, node.size.y};
                    position := Vec2f.{node.rect.z - size.x, node.rect.y};
                    DrawBox(draw_list, position + size * 0.5, size, ColorU32(0,0,1,0.5));
                }
                if top && !left && !right {
                    size := Vec2f.{node.size.x, node.size.y * 0.5};
                    position := node.rect.xy;
                    DrawBox(draw_list, position + size * 0.5, size, ColorU32(0,0,1,0.5));
                }
                if bottom && !left && !right {
                    size := Vec2f.{node.size.x, node.size.y * 0.5};
                    position := Vec2f.{node.rect.x, node.rect.w - size.y};
                    DrawBox(draw_list, position + size * 0.5, size, ColorU32(0,0,1,0.5));
                }
            });

            using _ := ButtonBehavior(overlay);
            if released {
                mouse := GetMousePosition(node.window);
                mouse -= overlay.rect.xy;

                top := mouse.y < overlay.size.y * 0.333333;
                bottom := mouse.y > overlay.size.y * 0.666666;
                left := mouse.x < overlay.size.x * 0.333333;
                right := mouse.x > overlay.size.x * 0.666666;

                if (left || right) && !top && !bottom {
                    split = .Vertical;
                }
                if (top || bottom) && !left && !right {
                    split = .Horizontal;
                }
            }

        case .Horizontal;
            SetLayout(node, .TopToBottom);

            DockSpace(node, "top");
            DockSpace(node, "bottom`");

        case .Vertical;
            SetLayout(node, .LeftToRight);

            DockSpace(node, "left");
            DockSpace(node, "right`");
        }
    }

    return node, content;
}
