AT_COMPILE_TIME :: true;

NINTENDO_SUPPORT :: #run to_string(getenv("NINTENDO_SDK_ROOT")) != "";
PS5_SUPPORT      :: #run to_string(getenv("SCE_PROSPERO_SDK_DIR")) != "";

// We don't ship the source code with this module. If you download it yourself or update to a newer version, be aware that
// "FT_CONFIG_OPTION_ENVIRONMENT_PROPERTIES" needs to be disabled in ftoption.h to compile on platforms without getenv support.
// -rluba, 2025-10-06
FREETYPE_PATH :: "src/freetype-2.12.1";

LIVE_OUTPUT :: true;

TYPES_TO_OMIT :: string.[
    "HAVE_UNISTD_H",
    "HAVE_FCNTL_H",
];

#if AT_COMPILE_TIME {
    #run,stallable {
        set_build_options_dc(.{do_output=false});
        options := get_build_options();
        args := options.compile_time_command_line;
        if !generate_bindings(args) {
            compiler_set_workspace_status(.FAILED);
        }
    }
} else {
    #import "System";

    main :: () {
        set_working_directory(path_strip_filename(get_path_of_running_executable()));
        if !generate_bindings(get_command_line_arguments()) {
            exit(1);
        }
    }
}

generate_bindings :: (args: [] string) -> bool {
    using BG;
    target_android := array_find(args, "-android");
    target_ios     := array_find(args, "-ios");
    target_switch2   := array_find(args, "-switch2");
    target_ps5     := array_find(args, "-ps5");

    target_x64     := array_find(args, "-x64");
    target_arm     := array_find(args, "-arm64");
    compile        := array_find(args, "-compile");
    compile_debug  := array_find(args, "-debug");

    os_target  := OS;
    cpu_target := CPU;
    if target_android os_target  = .ANDROID;
    if target_ios     os_target  = .IOS;
    if target_switch2   os_target  = .NN_SWITCH2;
    if target_ps5     os_target  = .PS5;

    if target_x64     cpu_target = .X64;
    if target_arm     cpu_target = .ARM64;

    build_dynamic_lib := true;
    lib_directory: string;
    if os_target == {
        case .WINDOWS;
            lib_directory = "windows";
        case .LINUX;
            lib_directory = "linux";
        case .MACOS;
            lib_directory = "macos";
        case .IOS;
            lib_directory = "ios";
        case .ANDROID;
            lib_directory = ifx cpu_target == .X64 then "android/x64" else "android/arm64";
        case .NN_SWITCH2;
            build_dynamic_lib = false;
            lib_directory = "switch2";
        case .PS5;
            build_dynamic_lib = false;
            lib_directory = "ps5";
        case;
            assert(false);
    }

    if compile {
        if os_target == .MACOS {
            minimum_x64_version:   Build_Options.Os_Version = .{10, 13};
            minimum_arm64_version: Build_Options.Os_Version = .{11, 0};
            success,  static_x64_path,   dynamic_x64_path   := compile_freetype_variant(os_target, .X64,   minimum_x64_version,   lib_directory, compile_debug = compile_debug, suffix = "_x64");
            if !success return false;
            success=, static_arm64_path, dynamic_arm64_path := compile_freetype_variant(os_target, .ARM64, minimum_arm64_version, lib_directory, compile_debug = compile_debug, suffix = "_arm64");
            if !success return false;
            // Create universal binaries out of the two arch builds:
            run_or_exit(.["lipo", "-create", dynamic_x64_path, dynamic_arm64_path, "-output", tprint("%/freetype.dylib", lib_directory)], "");
            run_or_exit(.["lipo", "-create", static_x64_path,  static_arm64_path,  "-output", tprint("%/freetype.a",     lib_directory)], "");
        } else {
            minimum_os_version:   Build_Options.Os_Version;
            if os_target == .IOS {
                minimum_os_version = .{12, 0};
            }
            success := compile_freetype_variant(os_target, cpu_target, minimum_os_version, lib_directory, compile_debug = compile_debug, compile_dynamic_lib = build_dynamic_lib);
            if !success return false;
        }
    }

    freetype_include := tprint("%/include", FREETYPE_PATH);

    options: Generate_Bindings_Options;
    options.os  = os_target;
    options.cpu = cpu_target;
    output_name: string;
    {
        using options;

        if os_target == {
            case .WINDOWS;
                output_name = "windows.jai";
            case .LINUX; #through;
            case .MACOS; #through;
            case .IOS; #through;
            case .ANDROID;
                output_name = "unix.jai";
                generate_library_declarations = false;
                footer = UNIX_FOOTER;
            case .NN_SWITCH2;
                output_name = "switch2.jai";
            case .PS5;
                output_name = "ps5.jai";
            case;
                assert(false);
        }

        array_add(*library_search_paths, lib_directory);
        sources := string.[
            "freetype/freetype.h",
            "freetype/tttables.h",
        ];

        array_add(*libraries, .{filename="freetype"});
        array_add(*include_paths, freetype_include);
        for source: sources {
            array_add(*source_files,  tprint("%/%", freetype_include, source));
        }
        auto_detect_enum_prefixes = true;
        log_stripped_declarations = false;
        generate_compile_time_struct_checks = false;
    }

    return generate_bindings(options, output_name);
}


compile_freetype_variant :: (os_target: Operating_System_Tag, cpu_target: CPU_Tag, minimum_os_version: Build_Options.Os_Version, target_directory: string, compile_debug: bool, suffix := "", compile_dynamic_lib := true) -> bool, static_lib_path: string, dynamic_lib_path: string {
    build_type := ifx compile_debug then "Debug" else "Release";

	absolute_build_dir := tprint("%/%_build%", get_absolute_path("."), target_directory, suffix);

    static_library_extension: string;
    static_config_command: [..] string;
    array_add(*static_config_command,
        "cmake",
        tprint("-B%", absolute_build_dir),
        "-DFT_DISABLE_ZLIB=TRUE",
        "-DFT_DISABLE_BZIP2=TRUE",
        "-DFT_DISABLE_PNG=TRUE",
        "-DFT_DISABLE_HARFBUZZ=TRUE",
        "-DFT_DISABLE_BROTLI=TRUE",
    );

    dynamic_library_extension: string;
    dynamic_config_command: [..] string;
    array_add(*dynamic_config_command,
        "cmake",
        tprint("-B%", absolute_build_dir),
        "-DFT_DISABLE_ZLIB=TRUE",
        "-DFT_DISABLE_BZIP2=TRUE",
        "-DFT_DISABLE_PNG=TRUE",
        "-DFT_DISABLE_HARFBUZZ=TRUE",
        "-DFT_DISABLE_BROTLI=TRUE",
        "-DBUILD_SHARED_LIBS=true",
    );
    array_add(*static_config_command,  tprint("-DCMAKE_BUILD_TYPE=%", build_type));
    array_add(*dynamic_config_command, tprint("-DCMAKE_BUILD_TYPE=%", build_type));

    source_library_name := "libfreetype";
    if compile_debug {
        source_library_name = "libfreetyped";
    }
    build_dir_suffix: string;
    if os_target == {
        case .WINDOWS;
            static_library_extension = "lib";
            dynamic_library_extension = "dll";
            source_library_name = "freetype";
            build_dir_suffix = "Release/";
            array_add(*static_config_command,  tprint("-DCMAKE_CONFIGURATION_TYPES=%", build_type));
            array_add(*dynamic_config_command, tprint("-DCMAKE_CONFIGURATION_TYPES=%", build_type));
        case .MACOS; #through;
        case .IOS;
            static_library_extension = "a";
            dynamic_library_extension = "dylib";
            arch_name := ifx cpu_target == .X64 then "x86_64" else "arm64";
            arch_arg := tprint("-DCMAKE_OSX_ARCHITECTURES=%", arch_name);
            version_arg := tprint("-DCMAKE_OSX_DEPLOYMENT_TARGET=%.%", minimum_os_version.major, minimum_os_version.minor);
            array_add(*static_config_command,  arch_arg, version_arg);
            array_add(*dynamic_config_command, arch_arg, version_arg);
            if os_target == .IOS {
                sdk_path := get_ios_sdk_path();
                sysroot_arg := tprint("-DCMAKE_OSX_SYSROOT=%", sdk_path);
                array_add(*static_config_command,  "-DCMAKE_SYSTEM_NAME=iOS", sysroot_arg);
                array_add(*dynamic_config_command, "-DCMAKE_SYSTEM_NAME=iOS", sysroot_arg);
            }
        case .LINUX;
            static_library_extension = "a";
            dynamic_library_extension = "so";
            array_add(*static_config_command, "-DCMAKE_POSITION_INDEPENDENT_CODE=ON");
        case .ANDROID;
            static_library_extension = "a";
            dynamic_library_extension = "so";
            ndk := get_ndk_paths();
            toolchain_arg := tprint("-DCMAKE_TOOLCHAIN_FILE=%/build/cmake/android.toolchain.cmake", ndk.root);
            abi_arg       := tprint("-DANDROID_ABI=%", ifx cpu_target == .X64 then "x86_64" else "arm64-v8a");
            platform_arg  := tprint("-DANDROID_PLATFORM=%", ANDROID_SDK_LEVEL);
            array_add(*static_config_command,  toolchain_arg, abi_arg, platform_arg);
            // , "-DCMAKE_POSITION_INDEPENDENT_CODE=ON");
            array_add(*dynamic_config_command, toolchain_arg, abi_arg, platform_arg);
        case .NN_SWITCH2;
            #if NINTENDO_SUPPORT {
                static_library_extension = "a";
                toolchain_arg := tprint("-DCMAKE_TOOLCHAIN_FILE=%", NT.get_switch2_cmake_toolchain_path());
                array_add(*static_config_command, "-G", "Unix Makefiles", toolchain_arg);
            }
        case .PS5;
            #if PS5_SUPPORT {
                static_library_extension = "a";
                toolchain_arg := tprint("-DCMAKE_TOOLCHAIN_FILE=%", PS5T.get_ps5_cmake_toolchain_path());
                array_add(*static_config_command, "-G", "Unix Makefiles", toolchain_arg);
            }
        case;
            assert(false); // Unknown OS
    }

    build_command: [..] string;
    array_add(*build_command, "cmake", "--build", absolute_build_dir);
    if OS == .WINDOWS {
        array_add(*build_command, tprint("--config=%", build_type));
    }

    success := make_directory_if_it_does_not_exist(target_directory, recursive = true);
    if !success {
        log_error("Failed to make directory \"%\"", target_directory);
        return false, "", "";
    }


	if file_exists(absolute_build_dir) {
		success := delete_directory(absolute_build_dir);
		if !success {
			log_error("Could not delete old build directory");
			return false, "", "";
		}
	}

    log("Configuring to build the static lib: %", static_config_command);
    run_or_exit(static_config_command, FREETYPE_PATH);

    log("Building the static lib");
    run_or_exit(build_command, FREETYPE_PATH);

    static_lib_source := tprint("%1/%2%3.%4", absolute_build_dir, build_dir_suffix, source_library_name, static_library_extension);
    static_lib_dest   := tprint("%/freetype%.%", target_directory, suffix, static_library_extension);
    if !copy_library(static_lib_source, static_lib_dest)  return false, "", "";


    success = delete_directory(absolute_build_dir);
    if !success {
        log_error("Could not delete old build directory");
        return false, "", "";
    }

    dynamic_lib_dest: string;
    if compile_dynamic_lib {
        log("Configuring to build the dynamic lib");
        run_or_exit(dynamic_config_command, FREETYPE_PATH);

        log("Building the dynamic lib");
        run_or_exit(build_command, FREETYPE_PATH);

        dynamic_lib_source := tprint("%1/%2%3.%4", absolute_build_dir, build_dir_suffix, source_library_name, dynamic_library_extension);
        dynamic_lib_dest   = tprint("%/freetype%.%", target_directory, suffix, dynamic_library_extension);
        if !copy_library(dynamic_lib_source, dynamic_lib_dest)  return false, "", "";

        delete_directory(absolute_build_dir);
    }

    log("Built freetype successfully");
    return true, static_lib_dest, dynamic_lib_dest;
}

copy_library :: (src: string, dest: string) -> bool {
    if file_exists(dest) {
        success := file_delete(dest);
        if !success {
            log_error("Failed to delete old \"%\"", dest);
            return false;
        }
    }

    success := copy_file(src, dest);
    if !success {
        log_error("Failed to copy file \"%\" to \"%\"", src, dest);
        return false;
    }

    return true;
}


run_or_exit :: (command: [] string, working_directory: string) {
    // Enable this to see the commands being executed.
    // print("Executing command \"%\" in directory \"%\"\n", join(..command, separator = " "), working_directory);

    result, output_string, error_string := run_command(..command, working_directory = working_directory, capture_and_return_output = true, print_captured_output = LIVE_OUTPUT);
    defer {
        free(output_string);
        free(error_string);
    }
    if result.exit_code != 0 {
        log_error("Could not run command \"%\" in directory \"%\". Exit code: %\nError:\n%", get_quoted_command_string(command), working_directory, result.exit_code, error_string);
        exit(1);
    }
}

#import "Basic";
BG :: #import "Bindings_Generator"(PS5_SUPPORT = PS5_SUPPORT, NINTENDO_SUPPORT = NINTENDO_SUPPORT);
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "Process";
#import "String";
#import "Android/Toolchain";
#import "iOS/Toolchain";
#if NINTENDO_SUPPORT {
    NT :: #import "Nintendo/Toolchain";
}
#if PS5_SUPPORT {
    PS5T :: #import "ps5/Toolchain";
}
#if OS == .WINDOWS {
    #import "Windows";
} else {
    #import "POSIX";
}


UNIX_FOOTER :: #string END
#scope_file

#if OS == .LINUX {
    freetype :: #library "linux/freetype";
} else #if OS == .MACOS {
    freetype :: #library "macos/freetype";
} else #if OS == .IOS {
    freetype :: #library "ios/freetype";
} else #if OS == .ANDROID {
    #if CPU == .X64 {
        freetype :: #library "android/x64/freetype";
    } else #if CPU == .ARM64 {
        freetype :: #library "android/arm64/freetype";
    }
} else {
    #assert false;
}

END

