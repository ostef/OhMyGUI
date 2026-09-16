#import "Basic";
#import "Compiler";
#import "File";
#import "String";
#import "Hash_Table";

LoadedFile :: struct {
    filename : string;
    contents : string;
    line_offsets : [..]int;
}

Documentation :: struct {
    raw_comment : string;
    brief : string;
    description : string;
    see : [..]string;
}

g_files : [..]LoadedFile;
g_doc_entries : Table(*Code_Declaration, Documentation);

LoadFile :: (filename : string) -> *LoadedFile {
    for * g_files {
        if it.filename == filename {
            return it;
        }
    }

    file_contents, ok := read_entire_file(filename);
    if ok {
        file := array_add(*g_files);
        file.filename = filename;
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

GetLeadingComment :: (decl : *Code_Declaration) -> string {
    EndsWith :: (str : string, with : string, offset_from_end : int) -> bool {
        if str.count - offset_from_end < with.count {
            return false;
        }

        _s := str;
        _s.data += _s.count - offset_from_end - with.count;
        _s.count = with.count;

        return _s == with;
    }

    if !decl.enclosing_load {
        return "";
    }

    loc := make_location(decl);
    file := LoadFile(loc.fully_pathed_filename);
    if !file {
        return "";
    }

    if loc.line_number < 1 || loc.line_number > file.line_offsets.count {
        return "";
    }

    line_index := loc.line_number - 1;
    if line_index < 0 {
        return "";
    }

    byte_offset := file.line_offsets[line_index] - 1 + loc.character_number - 1;

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
        } else if comment_level < 0 && !is_space(file.contents[byte_offset]) {
            return "";
        } else {
            byte_offset -= 1;
        }
    }

    if comment_start_offset >= 0 && comment_end_offset >= 0 {
        comment_str := string.{
            data=file.contents.data + comment_start_offset,
            count=comment_end_offset - comment_start_offset + 1,
        };

        if begins_with(comment_str, "/**") || begins_with(comment_str, "///") {
            return comment_str;
        }
    }

    return "";
}

AddDocumentation :: (decl : *Code_Declaration, raw_comment : string) {
    doc := find_or_add(*g_doc_entries, decl);
    doc.raw_comment = raw_comment;
    ParseDocumentation(doc);
}

ParseDocumentation :: (doc : *Documentation) {
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
        if begins_with(s, " *") {
            s = advance(s, " *".count);
        }

        s = trim(s);
        if begins_with(s, "@brief ") {
            s = advance(s, "@brief ".count);
            s = trim(s);

            doc.brief = s;
        } else if begins_with(s, "@see ") {
            s = advance(s, "@see ".count);
            s = trim(s);

            array_add(*doc.see, s);
        } else if s.count > 0 {
            if doc.description {
                doc.description = join(doc.description, s, separator=" ");
            } else {
                doc.description = s;
            }
        }
    }
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

            loc := make_location(decl);

            if decl.enclosing_load && decl.enclosing_load.enclosing_import && decl.enclosing_load.enclosing_import.module_type != .MAIN_PROGRAM {
                continue;
            }

            leading_comment := GetLeadingComment(decl);
            if leading_comment {
                AddDocumentation(decl, leading_comment);
            }

            if !decl.expression {
                continue;
            }

            if decl.expression.kind == {
            case .STRUCT;
                struct_node := cast(*Code_Struct, decl.expression);
                for struct_node.block.members {
                    if it.kind != .DECLARATION {
                        continue;
                    }

                    member_decl := cast(*Code_Declaration, it);
                    following_comment := GetFollowingComment(member_decl);
                    if following_comment {
                        AddDocumentation(member_decl, following_comment);
                        continue;
                    }

                    leading_comment := GetLeadingComment(member_decl);
                    if leading_comment {
                        AddDocumentation(member_decl, leading_comment);
                        continue;
                    }
                }
            }
        }
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

    for doc, decl : g_doc_entries {
        print("%:\n", decl.name);
        if doc.brief {
            print("Brief: %\n", doc.brief);
        }
        if doc.description {
            print("%\n", doc.description);
        }

        if doc.see.count > 0 {
            print("See:\n");
            for doc.see {
                print("  %\n", it);
            }
        }

        print("\n");
    }
}
