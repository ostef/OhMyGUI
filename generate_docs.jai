#import "Basic";
#import "Compiler";
#import "File";
#import "String";
#import "Hash_Table";
#import "Sort";

DocElement :: struct {
    parent : *DocElement;

    node : *Code_Node;
    full_name : string;
    name : string;
    kind : enum {
        File;
        Struct;
        StructMember;
        Enum;
        EnumValue;
        Function;
    };

    raw_comment : string;
    brief : string;
    description : string;
    params : [..]string;
    returns : string;
    see_also : [..]string;
}

DocFile :: struct {
    #as using base : DocElement;
    base.kind = .File;

    filename : string;
    short_filename : string;
    contents : string;
    line_offsets : [..]int;

    structs : [..]*DocStruct;
    enums : [..]*DocEnum;
    functions : [..]*DocFunction;
}

GetFile :: (doc : *DocElement) -> *DocFile {
    while doc && doc.kind != .File {
        doc = doc.parent;
    }

    return xx doc;
}

DocStructMember :: struct {
    #as using base : DocElement;
    base.kind = .StructMember;

    type : *Type_Info;
    anonymous_type_documentation : *DocElement;
}

DocStruct :: struct {
    #as using base : DocElement;
    base.kind = .Struct;

    members : [..]DocStructMember;
    sub_structs : [..]*DocStruct;
    sub_enums : [..]*DocEnum;
    sub_functions : [..]*DocFunction;

    related_functions : [..]*DocFunction;
}

DocEnumValue :: struct {
    #as using base : DocElement;
    base.kind = .EnumValue;
}

DocEnum :: struct {
    #as using base : DocElement;
    base.kind = .Enum;

    values : [..]DocEnumValue;

    related_functions : [..]*DocFunction;
}

DocFunction :: struct {
    #as using base : DocElement;
    base.kind = .Function;
}

g_files : [..]*DocFile;
g_all_docs : Table(*Code_Node, *DocElement);
g_all_docs_by_name : Table(string, *DocElement);

CreateDoc :: ($T : Type, parent : *DocElement, node : *Code_Node) -> *T {
    doc := New(T);
    doc.parent = parent;
    doc.node = node;
    table_set(*g_all_docs, node, doc);

    return doc;
}

SetName :: (doc : *DocElement, name : string) {
    doc.name = name;
    if doc.parent && doc.parent.kind != .File {
        if !doc.parent.full_name {
            return;
        }

        doc.full_name = sprint("%.%", doc.parent.full_name, doc.name);
    } else {
        doc.full_name = name;
    }

    table_set(*g_all_docs_by_name, doc.full_name, doc);
}

LoadFile :: (filename : string) -> *DocFile {
    for g_files {
        if it.filename == filename {
            return it;
        }
    }

    file_contents, ok := read_entire_file(filename);
    if ok {
        file := New(DocFile);
        array_add(*g_files, file);

        file.filename = filename;
        file.short_filename = advance(filename, #filepath.count);

        file.name = copy_string(file.short_filename);
        for i : 0..file.name.count - 1 {
            if !is_alnum(file.name[i]) {
                file.name[i] = #char "_";
            }
        }

        file.full_name = file.name;
        table_set(*g_all_docs_by_name, file.full_name, file);

        file.contents = file_contents;

        byte := 0;
        line := 0;
        array_add(*file.line_offsets, 0);

        while byte < file_contents.count {
            if file_contents[byte] == #char "\n" {
                array_add(*file.line_offsets, byte + 1);
            }

            byte += 1;
        }

        array_add(*file.line_offsets, byte);

        return file;
    }

    return null;
}

GetDeclarationRange :: (decl : *Code_Declaration) -> line_start : int, line_end : int, char_start : int, char_end : int {
    if !decl.expression {
        return decl.l0, decl.l1, decl.c0, decl.c1;
    }

    if decl.expression.kind == {
    case .STRUCT;
        struct_node := cast(*Code_Struct, decl.expression);
        return decl.l0, struct_node.block.l1, decl.c0, struct_node.block.c1;
    case .PROCEDURE_HEADER;
        proc := cast(*Code_Procedure_Header, decl.expression);
        end := ifx proc.returns.count > 0 then *proc.returns[proc.returns.count - 1].base else *proc.base;
        return decl.l0, end.l1, decl.c0, end.c1;
    case .ENUM;
        enum_node := cast(*Code_Enum, decl.expression);
        return decl.l0, enum_node.block.l1, decl.c0, enum_node.block.c1;
    case;
        return decl.l0, decl.l1, decl.c0, decl.c1;
    }
}

GetNodeText :: (node : *Code_Node) -> string {
    if !node.enclosing_load {
        return "";
    }

    file := LoadFile(node.enclosing_load.fully_pathed_filename);
    if !file {
        return "";
    }

    l0, c0, l1, c1 : int;
    if node.kind == .DECLARATION {
        l0, l1, c0, c1 = GetDeclarationRange(xx node);
    } else {
        l0 = node.l0;
        l1 = node.l1;
        c0 = node.c0;
        c1 = node.c1;
    }

    line_start := file.line_offsets[l0 - 1] + c0 - 1;
    line_end := file.line_offsets[l1 - 1] + c1 - 1;

    return .{data=file.contents.data + line_start, count=line_end - line_start};
}

GetFollowingComment :: (decl : *Code_Declaration) -> string {
    if !decl.enclosing_load {
        return "";
    }

    file := LoadFile(decl.enclosing_load.fully_pathed_filename);
    if !file {
        return "";
    }

    l0, l1, c0, c1 := GetDeclarationRange(decl);

    line_start := file.line_offsets[l1 - 1] + c1;
    line_end := file.line_offsets[l1];
    line_str := string.{data=file.contents.data + line_start, count=line_end - line_start - 1};
    while line_str.count > 0 && is_space(line_str[0]) {
        advance(*line_str);
    }

    if !begins_with(line_str, "///>") && !begins_with(line_str, "/**") {
        return "";
    }

    return line_str;
}

GetLeadingComment :: (node : *Code_Node) -> string, indentation : int {
    EndsWith :: (str : string, with : string, offset_from_end : int) -> bool {
        if str.count - offset_from_end < with.count {
            return false;
        }

        _s := str;
        _s.data += _s.count - offset_from_end - with.count;
        _s.count = with.count;

        return _s == with;
    }

    if !node.enclosing_load {
        return "", 0;
    }

    loc := make_location(node);
    file := LoadFile(loc.fully_pathed_filename);
    if !file {
        return "", 0;
    }

    if loc.line_number < 1 || loc.line_number > file.line_offsets.count {
        return "", 0;
    }

    line_index := loc.line_number - 1;
    if line_index < 0 {
        return "", 0;
    }

    byte_offset := file.line_offsets[line_index] - 2;

    comment_start_offset, comment_end_offset := -1;
    comment_level := -1;
    while byte_offset >= 0 {
        if comment_level >= 0 && EndsWith(file.contents, "/*", file.contents.count - 1 - byte_offset) {
            comment_level -= 1;
            byte_offset -= 2;

            if comment_level < 0 {
                comment_start_offset = byte_offset + 1;
                break;
            }
        } else if EndsWith(file.contents, "*/", file.contents.count - 1 - byte_offset) {
            if comment_level < 0 {
                comment_end_offset = byte_offset;
            }

            comment_level += 1;
            byte_offset -= 2;
        } else if comment_level < 0 && (file.contents[byte_offset] == "\n" || !is_space(file.contents[byte_offset])) {
            return "", 0;
        } else {
            byte_offset -= 1;
        }
    }

    if comment_start_offset >= 0 && comment_end_offset >= 0 {
        i := comment_start_offset;
        while i > 0 && file.contents[i - 1] != #char "\n" {
            i -= 1;
        }

        comment_str := string.{
            data=file.contents.data + comment_start_offset,
            count=comment_end_offset - comment_start_offset + 1,
        };

        if begins_with(comment_str, "/**") || begins_with(comment_str, "///") {
            return comment_str, comment_start_offset - i;
        }
    }

    return "", 0;
}

ParseDocumentation :: (doc : *DocElement, indentation : int) {
    str := doc.raw_comment;
    if begins_with(str, "///>") {
        str = advance(str, "///>".count);

        doc.description = trim(str);

        return;
    }

    if begins_with(str, "/**") {
        advance(*str, "/**".count);
        str.count -= "*/".count;

        str = trim(str, " \t");
    }

    lines := split(str, "\n");
    for lines {
        s := it;

        for i : 0..indentation - 1 {
            if s.count <= 0 {
                break;
            }

            if is_space(s[0]) {
                s = advance(s);
            }
        }

        if begins_with(s, " *") {
            s = advance(s, " *".count);
        }

        s = trim(s);
        if begins_with(s, "@brief ") {
            s = advance(s, "@brief ".count);
            s = trim(s);

            doc.brief = s;
        } else if begins_with(s, "@returns ") {
            s = advance(s, "@returns ".count);
            s = trim(s);

            doc.returns = s;
        } else if begins_with(s, "@param ") {
            s = advance(s, "@param ".count);
            s = trim(s);

            array_add(*doc.params, s);
        } else if begins_with(s, "@see ") {
            s = advance(s, "@see ".count);
            s = trim(s);

            array_add(*doc.see_also, s);
        } else if s.count > 0 {
            if doc.description {
                doc.description = join(doc.description, s, separator=" ");
            } else {
                doc.description = s;
            }
        }
    }
}

HandleStructMember :: (doc : *DocStruct, node : *Code_Node) {
    original_node := node;

    if node.kind == .USING {
        node = cast(*Code_Using, node).expression;
    }

    if node.kind != .DECLARATION {
        return;
    }

    member_decl := cast(*Code_Declaration, node);
    if member_decl.flags & .IS_CONSTANT {
        sub_doc := HandleDeclaration(member_decl);
        if sub_doc {
            if sub_doc.kind == {
            case .Struct;
                array_add(*doc.sub_structs, xx sub_doc);
            case .Enum;
                array_add(*doc.sub_enums, xx sub_doc);
            case .Function;
                array_add(*doc.sub_functions, xx sub_doc);
            }
        }

        return;
    }

    member_doc := array_add(*doc.members);
    member_doc.parent = doc;
    SetName(member_doc, member_decl.name);
    member_doc.type = member_decl.type;

    following_comment := GetFollowingComment(member_decl);
    if following_comment {
        member_doc.raw_comment = following_comment;
        ParseDocumentation(member_doc, 0);
    } else {
        leading_comment, indentation := GetLeadingComment(original_node);
        if leading_comment {
            member_doc.raw_comment = leading_comment;
            ParseDocumentation(member_doc, indentation);
        }
    }

    // Handle anonymous structs and enums
    if member_decl.type_inst && member_decl.type_inst.type_valued_expression {
        if member_decl.type_inst.type_valued_expression.kind == {
        case .STRUCT;
            struct_node := cast(*Code_Struct, member_decl.type_inst.type_valued_expression);
            sub_struct := CreateDoc(DocStruct, doc, struct_node);
            HandleStruct(sub_struct, struct_node);
            member_doc.anonymous_type_documentation = sub_struct;

        case .ENUM;
            enum_node := cast(*Code_Enum, member_decl.type_inst.type_valued_expression);
            sub_enum := CreateDoc(DocEnum, doc, enum_node);
            HandleEnum(sub_enum, enum_node);
            member_doc.anonymous_type_documentation = sub_enum;
        }
    }
}

HandleStruct :: (doc : *DocStruct, struct_node : *Code_Struct) {
    for struct_node.block.statements {
        HandleStructMember(doc, it);
    }
}

HandleEnum :: (doc : *DocEnum, enum_node : *Code_Enum) {
    for enum_node.block.members {
        if it.kind != .DECLARATION {
            continue;
        }

        member_decl := cast(*Code_Declaration, it);

        member_doc := array_add(*doc.values);
        member_doc.parent = doc;
        SetName(member_doc, member_decl.name);

        following_comment := GetFollowingComment(member_decl);
        if following_comment {
            member_doc.raw_comment = following_comment;
            ParseDocumentation(member_doc, 0);
        } else {
            leading_comment, indentation := GetLeadingComment(member_decl);
            if leading_comment {
                member_doc.raw_comment = leading_comment;
                ParseDocumentation(member_doc, indentation);
            }
        }
    }
}

HandleDeclaration :: (decl : *Code_Declaration) -> *DocElement {
    if !decl.expression {
        return null;
    }

    for decl.name {
        if !is_alnum(it) {
            return null;
        }
    }

    doc : *DocElement;
    file := LoadFile(decl.enclosing_load.fully_pathed_filename);
    if !file {
        return null;
    }

    if decl.expression.kind == {
    case .STRUCT;
        doc = CreateDoc(DocStruct, file, decl);
        if decl.flags & .IS_GLOBAL {
            array_add(*file.structs, xx doc);
        }
    case .ENUM;
        doc = CreateDoc(DocEnum, file, decl);
        if decl.flags & .IS_GLOBAL {
            array_add(*file.enums, xx doc);
        }
    case .PROCEDURE_HEADER;
        doc = CreateDoc(DocFunction, file, decl);
        if decl.flags & .IS_GLOBAL {
            array_add(*file.functions, xx doc);
        }
    }

    if !doc {
        return null;
    }

    SetName(doc, decl.name);

    leading_comment, indentation := GetLeadingComment(decl);
    if leading_comment {
        doc.raw_comment = leading_comment;
        ParseDocumentation(doc, indentation);
    }

    if decl.expression.kind == {
    case .STRUCT;
        HandleStruct(xx doc, xx decl.expression);

    case .ENUM;
        HandleEnum(xx doc, xx decl.expression);
    }

    return doc;
}

HandleCompilerMessage :: (msg : *Message) {
    if msg.kind == {
    case .TYPECHECKED;
        typechecked := cast(*Message_Typechecked, msg);
        for typechecked.declarations {
            decl := it.expression;
            if decl.flags & .SCOPE_FILE {
                continue;
            }
            if !decl.expression {
                continue;
            }

            if decl.enclosing_load && decl.enclosing_load.enclosing_import && decl.enclosing_load.enclosing_import.module_type != .MAIN_PROGRAM {
                continue;
            }

            HandleDeclaration(decl);
        }
    }
}

AppendRef :: (builder : *String_Builder, doc : *DocElement) {
    AppendPath :: (builder : *String_Builder, doc : *DocElement) {
        root := doc;
        while root.parent {
            root = root.parent;
        }

        print_to_builder(builder, "/docs/files/file_%#%_%", root.name, to_lower_copy(doc.name), cast(u64, doc));
    }

    print_to_builder(builder, "[%](", doc.name);
    AppendPath(builder, doc);
    print_to_builder(builder, ")");
}

AppendFileHeader :: (builder : *String_Builder, file : *DocFile) {
    AppendIndex :: (builder : *String_Builder, file : *DocFile, name : string, docs : []*$T) {
        if docs.count <= 0 {
            return;
        }

        print_to_builder(builder, "%:\n\n", name);
        print_to_builder(builder, "| Name | Brief Description |\n");
        print_to_builder(builder, "| - | - |\n");

        for docs {
            print_to_builder(builder, "| ");
            AppendRef(builder, it);
            print_to_builder(builder, " | % |\n", it.brief);
        }

        print_to_builder(builder, "\n");
    }

    print_to_builder(builder, "+++\n");
    print_to_builder(builder, "title = '%'\n", file.short_filename);
    print_to_builder(builder, "+++\n\n");

    print_to_builder(builder, "## Index\n");
    AppendIndex(builder, file, "Structs", file.structs);
    AppendIndex(builder, file, "Enums", file.enums);
    AppendIndex(builder, file, "Functions", file.functions);

    print_to_builder(builder, "\n");
}

AppendDocStructMembers :: (builder : *String_Builder, doc : *DocStruct) {
    print_to_builder(builder, "| Name | Type | Description |\n");
    print_to_builder(builder, "| - | -: | - |\n");

    has_anon_types := false;
    for doc.members {
        desc := ifx it.description then it.description else it.brief;
        print_to_builder(builder, "| % | % | % |\n", it.name, cast(*Type, *it.type).*, desc);

        if it.anonymous_type_documentation {
            has_anon_types = true;
        }
    }

    if has_anon_types || doc.sub_structs || doc.sub_enums || doc.sub_functions {
        print_to_builder(builder, "\n**Subtypes:**\n\n");
        for doc.members {
            if !it.anonymous_type_documentation {
                continue;
            }

            anon_type := it.anonymous_type_documentation;
            if anon_type.kind == {
            case .Struct;
                print_to_builder(builder, "Member ***%*** (struct):\n", it.name);
                AppendDocStructMembers(builder, xx anon_type);
            case .Enum;
                print_to_builder(builder, "Member ***%*** (enum):\n", it.name);
                AppendDocEnumValues(builder, xx anon_type);
            }
        }

        for doc.sub_structs {
            print_to_builder(builder, "Struct ***%***:\n", it.name);
            AppendDocStructMembers(builder, it);
        }

        for doc.sub_enums {
            print_to_builder(builder, "Enum ***%***:\n", it.name);
            AppendDocEnumValues(builder, it);
        }
    }

    print_to_builder(builder, "\n");
}

AppendAnchor :: (builder : *String_Builder, doc : *DocElement) {
    print_to_builder(builder, "{#%_%}", to_lower_copy(doc.full_name), cast(u64, doc));
}

AppendDocStruct :: (builder : *String_Builder, doc : *DocStruct) {
    print_to_builder(builder, "### %1 ", doc.full_name);
    AppendAnchor(builder, doc);
    print_to_builder(builder, "\n");

    if doc.description {
        print_to_builder(builder, "%\n", doc.description);
    } else if doc.brief {
        print_to_builder(builder, "%\n", doc.brief);
    }

    print_to_builder(builder, "\n");

    print_to_builder(builder, "Members:\n");
    AppendDocStructMembers(builder, doc);
}

AppendDocEnumValues :: (builder : *String_Builder, doc : *DocEnum) {
    print_to_builder(builder, "| Name | Description |\n");
    print_to_builder(builder, "| - | - |\n");

    for doc.values {
        desc := ifx it.description then it.description else it.brief;
        print_to_builder(builder, "| % | % |\n", it.name, desc);
    }

    print_to_builder(builder, "\n");
}

AppendDocEnum :: (builder : *String_Builder, doc : *DocEnum) {
    print_to_builder(builder, "### %1 ", doc.full_name);
    AppendAnchor(builder, doc);
    print_to_builder(builder, "\n");

    if doc.description {
        print_to_builder(builder, "%\n", doc.description);
    } else if doc.brief {
        print_to_builder(builder, "%\n", doc.brief);
    }

    print_to_builder(builder, "\n");

    print_to_builder(builder, "Values:\n");
    AppendDocEnumValues(builder, doc);
}

AppendDocFunction :: (builder : *String_Builder, doc : *DocFunction) {
    print_to_builder(builder, "### %1 ", doc.full_name);
    AppendAnchor(builder, doc);
    print_to_builder(builder, "\n");

    text := GetNodeText(doc.node);
    print_to_builder(builder, "```jai\n%\n```\n\n", text);

    if doc.description {
        print_to_builder(builder, "%\n\n", doc.description);
    } else if doc.brief {
        print_to_builder(builder, "%\n\n", doc.brief);
    }

    if doc.returns {
        print_to_builder(builder, "**Returns:** %\n\n", doc.returns);
    }

    if doc.see_also.count > 0 {
        print_to_builder(builder, "See also:\n");
        for doc.see_also {
            print_to_builder(builder, "* %\n", it);
        }

        print_to_builder(builder, "\n");
    }
}

#run {
    w := compiler_create_workspace("Docs");

    options := get_build_options(w);
    options.output_type = .NO_OUTPUT;
    set_build_options(options, w);

    compiler_begin_intercept(w);
    add_build_file("module.jai", w);

    while true {
        msg := compiler_wait_for_message();
        if msg.kind == .COMPLETE {
            break;
        }

        HandleCompilerMessage(msg);
    }

    compiler_end_intercept(w);

    builder : String_Builder;

    make_directory_if_it_does_not_exist("Docs");

    for g_files {
        quick_sort(it.structs, (a, b) => compare_strings(a.name, b.name));
        quick_sort(it.enums, (a, b) => compare_strings(a.name, b.name));
        quick_sort(it.functions, (a, b) => compare_strings(a.name, b.name));

        AppendFileHeader(*builder, it);

        if it.structs {
            print_to_builder(*builder, "## Structs\n");
        }
        for doc : it.structs {
            AppendDocStruct(*builder, doc);
        }

        if it.enums {
            print_to_builder(*builder, "## Enums\n");
        }
        for doc : it.enums {
            AppendDocEnum(*builder, doc);
        }

        if it.functions {
            print_to_builder(*builder, "## Functions\n");
        }
        for doc : it.functions {
            AppendDocFunction(*builder, doc);
        }

        result := builder_to_string(*builder);
        write_entire_file(tprint("Docs/file_%.md", it.name), result);
    }
}
