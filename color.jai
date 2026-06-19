RGBA8 :: #type,isa u32; // We could make this a struct but then we wouldn't be able to use hex integer literals

SetRGB :: inline (color : *RGBA8, rgb : Vec3f) -> RGBA8 {
    color.* = SetRGB(color.*, rgb);
}

SetRGB :: inline (color : RGBA8, rgb : Vec3f) -> RGBA8 {
    rgba := ColorVec4f(color);
    rgba.xyz = rgb;
    return ColorU32(rgba);
}

GetRGB :: inline (color : RGBA8) -> Vec3f {
    rgba := ColorVec4f(color);

    return rgba.xyz;
}

SetAlpha :: inline (color : *RGBA8, alpha : float) {
    color.* = SetAlpha(color.*, alpha);
}

SetAlpha :: inline (color : RGBA8, alpha : float) -> RGBA8 {
    rgba := ColorVec4f(color);
    rgba.w = alpha;
    return ColorU32(rgba);
}

ColorU32 :: inline (rgb : Vec3f, alpha : float) -> RGBA8 {
    return ColorU32(rgb.x, rgb.y, rgb.z, alpha);
}

ColorU32 :: inline (rgba : Vec4f) -> RGBA8 {
    return ColorU32(rgba.x, rgba.y, rgba.z, rgba.w);
}

ColorU32 :: inline (r : float, g : float, b : float, a : float) -> RGBA8 {
    ur := cast(u32, clamp(r * 255, 0, 255));
    ug := cast(u32, clamp(g * 255, 0, 255));
    ub := cast(u32, clamp(b * 255, 0, 255));
    ua := cast(u32, clamp(a * 255, 0, 255));

    return cast(RGBA8, (ur << 24) | (ug << 16) | (ub << 8) | ua);
}

ColorVec4f :: inline (rgba : RGBA8) -> Vec4f {
    r := (cast(u32, rgba) >> 24) & 0xff;
    g := (cast(u32, rgba) >> 16) & 0xff;
    b := (cast(u32, rgba) >> 8)  & 0xff;
    a := (cast(u32, rgba) >> 0)  & 0xff;

    return .{r / 255.0, g / 255.0, b / 255.0, a / 255.0};
}

RGBToHSV :: inline (rgb : Vec3f) -> Vec3f {
    return RGBToHSV(rgb.x, rgb.y, rgb.z);
}

RGBToHSV :: (r : float, g : float, b: float) -> Vec3f {
    rgb_min := min(r, g, b);
    rgb_max := max(r, g, b);

    v := rgb_max;

    if v == 0 {
        return .{};
    }

    delta := rgb_max - rgb_min;

    s := delta / rgb_max;
    if s == 0 {
        return .{0,0,v};
    }

    h : float;
    K :: 43 / 255.0;
    if rgb_max == r {
        h = 0 + K * (g - b) / delta;
    } else if rgb_max == g {
        h = (85 / 255.0) + K * (b - r) / delta;
    } else {
        h = (171 / 255.0) + K * (r - g) / delta;
    }

    if h < 0 {
        h += 1;
    }

    return .{h * 360, s, v};
}

HSVToRGB :: (hsv : Vec3f) -> Vec3f {
    return HSVToRGB(hsv.x, hsv.y, hsv.z);
}

HSVToRGB :: inline (h : float, s : float, v : float) -> Vec3f {
    h /= 360;

    p := Vec3f.{
        clamp(abs(fract(h + 1)       * 6 - 3) - 1, 0, 1),
        clamp(abs(fract(h + 2 / 3.0) * 6 - 3) - 1, 0, 1),
        clamp(abs(fract(h + 1 / 3.0) * 6 - 3) - 1, 0, 1),
    };

    p.x = lerp(1, p.x, s);
    p.y = lerp(1, p.y, s);
    p.z = lerp(1, p.z, s);

    return v * p;
}

Darken :: inline (rgba : RGBA8, amount : float) -> RGBA8 {
    return SetRGB(rgba, Darken(GetRGB(rgba), amount));
}

Darken :: (rgb : Vec3f, amount : float) -> Vec3f {
    hsv := RGBToHSV(rgb);
    hsv.z = clamp(hsv.z - amount, 0, 1);

    return HSVToRGB(hsv);
}

Brighten :: inline (rgba : RGBA8, amount : float) -> RGBA8 {
    return SetRGB(rgba, Brighten(GetRGB(rgba), amount));
}

Brighten :: (rgb : Vec3f, amount : float) -> Vec3f {
    hsv := RGBToHSV(rgb);
    hsv.z = clamp(hsv.z + amount, 0, 1);

    return HSVToRGB(hsv);
}

Whiten :: inline (rgba : RGBA8, amount : float) -> RGBA8 {
    return SetRGB(rgba, Whiten(GetRGB(rgba), amount));
}

Whiten :: (rgb : Vec3f, amount : float) -> Vec3f {
    hsv := RGBToHSV(rgb);
    hsv.y = clamp(hsv.y - amount, 0, 1);
    hsv.z = clamp(hsv.z + amount, 0, 1);

    return HSVToRGB(hsv);
}

MakeTone :: inline (rgba : RGBA8, t : float) -> RGBA8 {
    return SetRGB(rgba, MakeTone(GetRGB(rgba), t));
}

MakeTone :: (rgb : Vec3f, t : float) -> Vec3f {
    t = clamp(t, 0, 1);

    hsv := RGBToHSV(rgb);
    hsv.y = lerp(hsv.y, 0, t);
    hsv.z = lerp(hsv.z, 0.5, t);

    return HSVToRGB(hsv);
}

InvertColor :: (rgba : RGBA8, t := 1.0) -> RGBA8 {
    rgb := GetRGB(rgba);
    rgb = lerp(rgb, Vec3f.{1,1,1} - rgb, t);
    return SetRGB(rgba, rgb);
}

InvertColor :: (rgb : Vec3f, t := 1.0) -> Vec3f {
    return lerp(rgb, Vec3f.{1,1,1} - rgb, t);
}

ComplementaryColor :: (rgb : Vec3f) -> Vec3f {
    hsv := RGBToHSV(rgb);
    hsv.x = fmod_cycling(hsv.x + 180, 360);

    return HSVToRGB(hsv);
}

SplitComplementaryColors :: (rgb : Vec3f, hue_shift := 30.0) -> Vec3f, Vec3f {
    hsv := RGBToHSV(rgb);

    a := hsv;
    a.x = fmod_cycling(a.x + 180 - hue_shift, 360);

    b := hsv;
    b.x = fmod_cycling(b.x + 180 + hue_shift, 360);

    return HSVToRGB(a), HSVToRGB(b);
}

AnalogousColors :: (rgb : Vec3f, hue_shift := 30.0) -> Vec3f, Vec3f {
    hsv := RGBToHSV(rgb);

    a := hsv;
    a.x = fmod_cycling(a.x - hue_shift, 360);

    b := hsv;
    b.x = fmod_cycling(b.x + hue_shift, 360);

    return HSVToRGB(a), HSVToRGB(b);
}

TriadicColors :: (rgb : Vec3f) -> Vec3f, Vec3f {
    hsv := RGBToHSV(rgb);

    K :: 360 / 3.0;

    a := hsv;
    a.x = fmod_cycling(a.x + K, 360);

    b := hsv;
    b.x = fmod_cycling(b.x - K, 360);

    return HSVToRGB(a), HSVToRGB(b);
}

TetradicColors :: (rgb : Vec3f, hue_shift := 30.0) -> Vec3f, Vec3f, Vec3f {
    hsv := RGBToHSV(rgb);

    a := hsv;
    a.x = fmod_cycling(a.x + hue_shift, 360); // Analogous

    b := a;
    b.x = fmod_cycling(b.x + 180, 360); // Complementary to analogous

    c := b;
    c.x = fmod_cycling(c.x - hue_shift, 360); // Analogous to complementary to analogous (complementary of original color)

    return HSVToRGB(a), HSVToRGB(b), HSVToRGB(c);
}

SquareColors :: (rgb : Vec3f, hue_shift := 30.0) -> Vec3f, Vec3f, Vec3f {
    hsv := RGBToHSV(rgb);

    a := hsv;
    a.x = fmod_cycling(a.x + 90, 360);

    b := a;
    b.x = fmod_cycling(b.x + 90, 360);

    c := b;
    c.x = fmod_cycling(c.x + 90, 360);

    return HSVToRGB(a), HSVToRGB(b), HSVToRGB(c);
}

PerceivedBrightnessYIQ :: inline (rgba : RGBA8) -> float {
    return PerceivedBrightnessYIQ(GetRGB(rgba));
}

PerceivedBrightnessYIQ :: inline (rgb : Vec3f) -> float {
    return 0.299 * rgb.x + 0.587 * rgb.y + 0.114 * rgb.z;
}

ChooseTextColor :: inline (background : RGBA8, dark : RGBA8 = 0x0d0d0dff, light : RGBA8 = 0xf2f2f2ff, $choose : (RGBA8) -> bool = (color) => PerceivedBrightnessYIQ(color) > 0.5) -> RGBA8 {
    return ifx choose(background) then dark else light;
}
