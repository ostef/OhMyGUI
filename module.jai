#import "Basic";
#import "Math";

#load "draw.jai";
#load "gl.jai";

Vec2f :: Vector2;
Vec4f :: Vector4;

// Basically a 2x3 matrix
Transform2D :: struct {
    a : float = 1;
    b : float;
    tx : float;

    c : float;
    d : float = 1;
    ty : float;
}

Mul :: inline (a : Transform2D, b : Transform2D) -> Transform2D {
    result : Transform2D = ---;
    result.a = a.a * b.a + a.b * b.c;
    result.b = a.a * b.b + a.b * b.d;

    result.c = a.c * b.a + a.d * b.c;
    result.d = a.c * b.b + a.d * b.d;

    result.tx = a.a * b.tx + a.b * b.ty + a.tx;
    result.ty = a.c * b.tx + a.d * b.ty + a.ty;

    return result;
}

operator* :: inline (a : Transform2D, b : Transform2D) -> Transform2D {
    return Mul(a, b);
}

// Creates a translation matrix
MakeTranslation2D :: inline (translation : Vec2f) -> Transform2D {
    return Transform2D.{
        1, 0, translation.x,
        0, 1, translation.y,
    };
}

// Creates a counter-clockwise rotation matrix
MakeRotation2D :: inline (angle_in_radians : float) -> Transform2D {
    cost := cos(angle_in_radians);
    sint := sin(angle_in_radians);

    return Transform2D.{
        cost, -sint, 0,
        sint,  cost, 0,
    };
}

InvertTransform2D :: (using transform : Transform2D, epsilon := 0.00001) -> Transform2D {
    det := a * d - b * c;
    if abs(det) < epsilon {
        return .{};
    }

    inv_det := 1 / det;

    // Invert linear part
    ra :=  d * inv_det;
    rb := -b * inv_det;
    rc := -c * inv_det;
    rd :=  a * inv_det;

    // Invert translation
    rtx := (-d * tx + b * ty) * inv_det;
    rty := ( c * tx - a * ty) * inv_det;

    return .{
        ra, rb, rtx,
        rc, rd, rty
    };
}

Init :: () {
}

Terminate :: () {
}
