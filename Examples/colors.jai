ColorSet :: (parent : *OMG.Node, rgb : OMG.Vec3f, location := #caller_location) {
    Preview :: (parent : *OMG.Node, color : OMG.Vec3f, location := #caller_location) -> *OMG.Node {
        node := OMG.GetNode(parent, location);
        {
            OMG.SetSize(node, OMG.SizePx(25), OMG.SizePx(25));

            OMG.SetCornerRadius(node, 4);
            OMG.SetBackgroundColor(node, color.x, color.y, color.z, 1);
        }

        return node;
    }

    Group :: (parent : *OMG.Node, name : string, location := #caller_location) -> *OMG.Node {
        parent = OMG.GetNode(parent, location);
        {
            parent.flags |= .NoClip;

            OMG.SetLayout(parent, .TopToBottom);
            OMG.SetPadding(parent, 10, 10);
            OMG.SetChildGap(parent, 4, 4);

            OMG.Text(parent, name);

            node := OMG.GetNode(parent, name);
            {
                OMG.SetLayout(node, .LeftToRight);
                OMG.SetSize(node, OMG.SizeFit(), OMG.SizeFit());
                OMG.SetPadding(node, 5, 5);
                OMG.SetChildGap(node, 5, 5);

                OMG.SetCornerRadius(node, 4);
                OMG.SetBackgroundColor(node, 1, 1, 1, 1);
                OMG.SetOuterShadowOpacity(node, 0.5);
                OMG.SetOuterShadowOffset(node, 3, 3);
                OMG.SetOuterShadowBlur(node, 5);
            }

            return node;
        }
    }

    Operation :: (parent : *OMG.Node, name : string, base : OMG.Vec3f, callback : (OMG.Vec3f, float) -> OMG.Vec3f, location := #caller_location) {
        node := Group(parent, name, location);
        {
            N :: 30;
            for i : 0..N - 1 {
                OMG.PushIDOffset(i);
                defer OMG.PopIDOffset();

                color := callback(base, i / cast(float, N - 1));
                Preview(node, color);
            }
        }

        OMG.VerticalSeparator(node);

        t := fmod_cycling(g_time, 2.5) / 2;
        t = clamp(t, 0, 1);
        color := callback(base, t);
        Preview(node, color);
    }

    canvas := OMG.GetNode(parent, location);
    {
        OMG.SetLayout(canvas, .TopToBottom);
        OMG.SetSize(canvas, OMG.SizeFit(), OMG.SizeFit());
        OMG.SetPadding(canvas, 10, 10);
        OMG.SetChildGap(canvas, 5, 5);

        Operation(canvas, "Darken (decrease value)", rgb, (rgb, t) => OMG.Darken(rgb, t));

        Operation(canvas, "Subtract RGB", rgb, (rgb, t) => OMG.Vec3f.{clamp(rgb.x - t, 0, 1), clamp(rgb.y - t, 0, 1), clamp(rgb.z - t, 0, 1)});

        Operation(canvas, "Brighten (increase value)", rgb, (rgb, t) => OMG.Brighten(rgb, t));

        Operation(canvas, "Whiten (decrease saturation, increase value)", rgb, (rgb, t) => OMG.Whiten(rgb, t));

        Operation(canvas, "Add RGB", rgb, (rgb, t) => OMG.Vec3f.{clamp(rgb.x + t, 0, 1), clamp(rgb.y + t, 0, 1), clamp(rgb.z + t, 0, 1)});

        Operation(canvas, "Tones", rgb, (rgb, t) => OMG.MakeTone(rgb, t));

        harmonies := OMG.GetNode(canvas);
        {
            OMG.SetLayout(harmonies, .LeftToRight);

            analogous := Group(harmonies, "Analogous");
            {
                a, b := OMG.AnalogousColors(rgb);
                Preview(analogous, rgb);
                Preview(analogous, a);
                Preview(analogous, b);
            }

            complementaries := Group(harmonies, "Complementary");
            {
                Preview(complementaries, rgb);
                Preview(complementaries, OMG.ComplementaryColor(rgb));
            }

            split_complementaries := Group(harmonies, "Split Complementary");
            {
                a, b := OMG.SplitComplementaryColors(rgb);
                Preview(split_complementaries, rgb);
                Preview(split_complementaries, a);
                Preview(split_complementaries, b);
            }

            triadics := Group(harmonies, "Triadic");
            {
                a, b := OMG.TriadicColors(rgb);
                Preview(triadics, rgb);
                Preview(triadics, a);
                Preview(triadics, b);
            }

            tetradics := Group(harmonies, "Tetradic");
            {
                a, b, c := OMG.TetradicColors(rgb);
                Preview(tetradics, rgb);
                Preview(tetradics, a);
                Preview(tetradics, b);
                Preview(tetradics, c);
            }

            square := Group(harmonies, "Square");
            {
                a, b, c := OMG.SquareColors(rgb);
                Preview(square, rgb);
                Preview(square, a);
                Preview(square, b);
                Preview(square, c);
            }
        }

        Operation(canvas, "RGB Lerp To Complementary", rgb, (rgb, t) => lerp(rgb, OMG.ComplementaryColor(rgb), t));

        Operation(canvas, "Hue Lerp To Complementary", rgb, (rgb : OMG.Vec3f, t : float) -> OMG.Vec3f {
            hsv := OMG.RGBToHSV(rgb);
            complementary_hsv := OMG.RGBToHSV(OMG.ComplementaryColor(rgb));

            hsv = lerp(hsv, complementary_hsv, t);
            hsv.x = fmod_cycling(hsv.x, 360);

            return OMG.HSVToRGB(hsv);
        });
    }
}

ColorsFrame :: () {
    window := OMG.GetWindow(g_window);

    root := OMG.GetNode(window);
    {
        canvas := OMG.GetNode(root);
        {
            OMG.SetSize(canvas, OMG.SizeFill(), OMG.SizeFill());
            OMG.SetPadding(canvas, 20, 20);
            OMG.SetBackgroundColor(canvas, 1,1,1,1);

            ColorSet(canvas, .{1,0.2,0.5});
            // ColorSet(canvas, .{1,1,1});
        }
    }
}
