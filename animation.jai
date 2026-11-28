Animation :: struct {
    prev: *Animation;
    next: *Animation;
    id: u64;
    duration: float;
    current_time: float;
    func: AnimationFunc;
    type: *Type_Info;
    byte_offset: int;
}

Animations :: (node: *Node, body: Code, flags: For_Flags) #expand {
    `it := node.animations;
    `it_index := 0;
    while it {
        next := it.next;
        defer {
            it = next;
            it_index += 1;
        }

        #insert body;
    }
}

GetAnimationStart :: inline (anim: *Animation) -> *void {
    return anim + 1;
}

GetAnimationTarget :: inline (anim: *Animation) -> *void {
    return GetAnimationStart(anim) + anim.type.runtime_size;
}

CancelAnimations :: (node: *Node) {
    for :Animations node {
        free(it);
    }
    node.animations = null;
}

AnimateProperty :: (node: *Node, prop_anim: PropertyAnimation, start: *void, target: *void) {
    for :Animations node {
        if it.id == prop_anim.id {
            return;
        }
    }

    anim: *Animation = alloc(size_of(Animation) + 2 * prop_anim.type.runtime_size);
    anim.* = .{};

    anim.next = node.animations;
    if !node.animations {
        node.animations = anim;
    } else {
        node.animations.prev = anim;
    }

    anim.id = prop_anim.id;
    anim.duration = prop_anim.duration;
    anim.func = prop_anim.func;
    anim.type = prop_anim.type;
    anim.byte_offset = prop_anim.byte_offset;

    start_ptr := GetAnimationStart(anim);
    target_ptr := GetAnimationTarget(anim);

    memcpy(start_ptr, start, anim.type.runtime_size);
    memcpy(target_ptr, target, anim.type.runtime_size);
}

ApplyAnimation :: (node: *Node, anim: *Animation) {
    start := GetAnimationStart(anim);
    target := GetAnimationTarget(anim);
    current := cast(*void, *node.styling) + anim.byte_offset;

    Animate(anim.type, current, start, target, anim.current_time / anim.duration, anim.func);
}

Animate :: (type: *Type_Info, current: *void, start: *void, target: *void, t: float, func: AnimationFunc) {
    if type == type_info(RGBA8) {
        cast(*RGBA8, current).* = Animate(cast(*RGBA8, start).*, cast(*RGBA8, target).*, t, func);
    } else if type.type == {
    case .FLOAT;
        if type.runtime_size == 4 {
            cast(*float32, current).* = Animate(cast(*float32, start).*, cast(*float32, target).*, t, func);
        } else {
            cast(*float64, current).* = Animate(cast(*float64, start).*, cast(*float64, target).*, t, func);
        }
    case .INTEGER;
        int_type := cast(*Type_Info_Integer, type);
        if int_type.signed {
            if int_type.runtime_size == {
            case 1; cast(*s8, current).*  = Animate(cast(*s8, start).*,  cast(*s8, target).*,  t, func);
            case 2; cast(*s16, current).* = Animate(cast(*s16, start).*, cast(*s16, target).*, t, func);
            case 4; cast(*s32, current).* = Animate(cast(*s32, start).*, cast(*s32, target).*, t, func);
            case 8; cast(*s64, current).* = Animate(cast(*s64, start).*, cast(*s64, target).*, t, func);
            }
        } else {
            if int_type.runtime_size == {
            case 1; cast(*u8, current).*  = Animate(cast(*u8, start).*,  cast(*u8, target).*,  t, func);
            case 2; cast(*u16, current).* = Animate(cast(*u16, start).*, cast(*u16, target).*, t, func);
            case 4; cast(*u32, current).* = Animate(cast(*u32, start).*, cast(*u32, target).*, t, func);
            case 8; cast(*u64, current).* = Animate(cast(*u64, start).*, cast(*u64, target).*, t, func);
            }
        }

    case .ARRAY;
    case .STRUCT;
        struct_type := cast(*Type_Info_Struct, type);

        highest_byte_offset := -1;
        for struct_type.members {
            if it.offset_in_bytes <= highest_byte_offset {
                continue;
            }

            highest_byte_offset = it.offset_in_bytes + it.size;

            Animate(it.type, current + it.offset_in_bytes, start + it.offset_in_bytes, target + it.offset_in_bytes, t, func);
        }

    case;
        t = Animate(0.0, 1.0, t, func);
        if t < 0.5 {
            memcpy(current, start, type.runtime_size);
        } else {
            memcpy(current, target, type.runtime_size);
        }
    }
}

AnimationFunc :: enum u8 {
    Linear;
    CubicIn;
    CubicOut;
    CubicInOut;
    ElasticIn;
    ElasticOut;
    ElasticInOut;
    BackIn;
    BackOut;
    BackInOut;
}

Animate :: inline (a: $T/.[float32,float64,s8,s16,s32,s64,u8,u16,u32,u64], b: T, t: float, func: AnimationFunc) -> T {
    if t < 0 {
        return a;
    }
    if t > 1 {
        return b;
    }

    if #complete func == {
    case .Linear;
        // t = t
    case .CubicIn;
        t = t * t * t;
    case .CubicOut;
        t = 1 - t;
        t = 1 - (t * t * t);
    case .CubicInOut;
        if t < 0.5 {
            t = 4 * t * t * t;
        } else {
            t = -2 * t;
            t = 1 - (t * t * t) * 0.5;
        }
    case .ElasticIn;
        if t > 0 && t < 1 {
            t = -pow(2, 10 * t - 10) * sin(t * 10 - 10.75) * (2 * PI / 3);
        }
    case .ElasticOut;
        if t > 0 && t < 1 {
            t = 1 + pow(2, -10 * t) * sin((t * 10 - 10.75) * (2 * PI / 3));
        }
    case .ElasticInOut;
        if t > 0 {
            if t < 0.5 {
                t = -pow(2, 20 * t - 10) * sin(t * 20 - 11.125) * (2 * PI / 4.5) / 2;
            } else if t < 1 {
                t = 1 + pow(2, -20 * t + 10) * sin(t * 20 - 11.125) * (2 * PI / 4.5) / 2;
            }
        }
    case .BackIn;
        C1 :: 1.70158;
        C3 :: C1 + 1;
        t = C3 * t * t * t - C1 * t * t;
    case .BackOut;
        C1 :: 1.70158;
        C3 :: C1 + 1;
        t -= 1;
        t = 1 + C3 * t * t * t + C1 * t * t;
    case .BackInOut;
        C1 :: 1.70158;
        C2 :: C1 * 1.525;
        if t < 0.5 {
            t = t * 2;
            t = (t * t * ((C2 + 1) * t - C2)) / 2;
        } else {
            t = t * 2 - 2;
            t = (t * t * ((C2 + 1) * t + C2) + 2) / 2;
        }
    }

    return xx (a * (1 - t) + b * t);
}

Animate :: inline (a: RGBA8, b: RGBA8, t: float, func: AnimationFunc) -> RGBA8 {
    a4f := ToVec4f(a);
    b4f := ToVec4f(b);

    return MakeRGBA8(
        Animate(a4f.x, b4f.x, t, func),
        Animate(a4f.y, b4f.y, t, func),
        Animate(a4f.z, b4f.z, t, func),
        Animate(a4f.w, b4f.w, t, func),
    );
}
