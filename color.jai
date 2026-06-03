RGBA8 :: #type,isa u32; // We could make this a struct but then we wouldn't be able to use hex integer literals

SetRGB :: inline (color : *RGBA8, rgb : Vec3f) -> RGBA8 {
    color.* = SetRGB(color.*, rgb);
}

SetRGB :: inline (color : RGBA8, rgb : Vec3f) -> RGBA8 {
    rgba := ColorVec4f(color);
    rgba.xyz = rgb;
    return ColorU32(rgba);
}

SetAlpha :: inline (color : *RGBA8, alpha : float) {
    color.* = SetAlpha(color.*, alpha);
}

SetAlpha :: inline (color : RGBA8, alpha : float) -> RGBA8 {
    rgba := ColorVec4f(color);
    rgba.w = alpha;
    return ColorU32(rgba);
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

RGBToHSV :: (rgb : Vec3f) -> Vec3f {
    r := rgb.x;
    g := rgb.y;
    b := rgb.z;

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

    return .{h * 360, s, v};
}

HSVToRGB :: (hsv : Vec3f) -> Vec3f {
    h := hsv.x / 360;
    s := hsv.y;
    v := hsv.z;

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

Darken :: (rgb : Vec3f, amount : float) -> Vec3f {
    hsv := RGBToHSV(rgb);
    hsv.z = clamp(hsv.z - amount, 0, 1);

    return HSVToRGB(hsv);
}

Brighten :: (rgb : Vec3f, amount : float) -> Vec3f {
    hsv := RGBToHSV(rgb);
    hsv.z = clamp(hsv.z + amount, 0, 1);

    return HSVToRGB(hsv);
}

Whiten :: (rgb : Vec3f, amount : float) -> Vec3f {
    hsv := RGBToHSV(rgb);
    hsv.y = clamp(hsv.y - amount, 0, 1);
    hsv.z = clamp(hsv.z + amount, 0, 1);

    return HSVToRGB(hsv);
}

MakeTone :: (rgb : Vec3f, t : float) -> Vec3f {
    t = clamp(t, 0, 1);

    hsv := RGBToHSV(rgb);
    hsv.y = lerp(hsv.y, 0, t);
    hsv.z = lerp(hsv.z, 0.5, t);

    return HSVToRGB(hsv);
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
