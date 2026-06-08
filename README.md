# OhMyGUI
> &#9888;&#65039; This project is a work in progress

Tree based immediate mode GUI library in Jai inspired by Clay and PanGui.

## Main features
* Immediate mode API: declare the UI by code each frame, nodes are added/removed/persisted accordingly.
* Tree-based UI: unlike Dear ImGUI, OhMyGUI keeps track of the element tree. This allows for more layout options as well as extending/modifying nodes after they've been declared.
* Style aware: all the widgets can be called with an optional style parameter.
* Draw callbacks: drawing is done after layout at the end of the frame. This allows you to attach a different draw callback to any node that has already been declared to further customize its visuals.
* SDF fonts that look good at any size.

## How it works
Each frame, the user calls `GetNode` with an ID to declare a UI element or get a node that has been declared prior, or any of the widget functions. This builds a tree which is traversed at the end of the frame to lay UI elements out according to properties specified by the user, then draw UI elements that are visible.

UI widgets are simply a function or set of functions that encapsulate declaring the appropriate UI nodes, settings their properties as well as performing UI logic. For example, this the `Button` widget's function:

```jai
Button :: (parent : *Node, width : Size1D, height : Size1D, style : *ButtonStyle = null, location := #caller_location) -> clicked : bool, *Node {
    EnsureStyle(*style, "button"); // Make sure style is not null by retrieving the default style named 'button'

    node := GetNode(parent, location);
    {
        SetSize(node, width, height);
        SetChildAlign(node, 0.5, 0.5);

        button := ButtonBehavior(node);

        state := GetState(node);
        Apply(node, style.states[state].background); // Apply style

        return button.released, node;
    }
}

Button :: (parent : *Node, text : string, style : *ButtonStyle = null, location := #caller_location) -> clicked : bool, *Node {
    EnsureStyle(*style, "button");

    clicked, node := Button(parent, SizeFit(), SizeFit(), style, location);

    text_node := GetNode(node, "text");
    SetText(text_node, text);

    state := GetState(node);

    Apply(text_node, style.states[state].text);

    return clicked, node;
}

ButtonResult :: struct {
    pressed : bool;
    held : bool;
    released : bool;
}

ButtonBehavior :: (node : *Node) -> ButtonResult {
    node.flags |= .Focusable;

    if (IsMouseButtonReleased(.Left) || IsMouseButtonDown(.Left)) && context.omg.mouse_capturing_node == node {
        SetMouseCapture(node);
        SetMouseFocus(node);
    } else if node.state_flags & .Focused && IsMouseButtonPressed(.Left) {
        SetMouseCapture(node);
    }

    if context.omg.mouse_capturing_node == node {
        node.state_flags |= .Hot;
    }

    result : ButtonResult;
    if node.state_flags & .Hot {
        result.held = true;
        result.pressed = IsHovered(node) && IsMouseButtonPressed(.Left);
        result.released = IsHovered(node) && IsMouseButtonReleased(.Left);
    }

    return result;
}
```

Adding a button to your UI is then simply a matter of calling the `Button` function:
```jai
root := OMG.GetNode(window);

if OMG.Button(root, "Hello") {
    print("Hello!\n");
}
```

## Layout
Layout in OhMyGUI is done at the end of the frame based on different properties that the user can set. There are 5 layout modes currently available, which define how children are positioned:
* None
* LeftToRight
* RightToLeft
* TopToBottom
* BottomToTop

The None layout mode means child nodes are not positioned. This is useful for e.g. visual node editors, where nodes position themselves and can be freely moved by the user. The offset property of the node is used in that case as the position of the node relative to its parent.

Note that children cannot decide themselves that they want to be positionned differently.

Sizing can be parameterized in three ways, on both the X and Y axis:
* Pixels (`SizePx(value)` function)
* FitChildren (`SizeFit()` function)
* FillParent (`SizeFill(weight)` function)

Pixels will set the pixel size of the node to the specified value.

Fit children will set the size of the node to the sum of its children, plus the padding and the child gap.

Fill parent will fill the available space in the parent after nodes with fit and fixed sizing have been calculated. A weight value is used to determine the repartition of the space between the children.
