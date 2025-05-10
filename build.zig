const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const linkage = b.option(std.builtin.LinkMode, "linkage", "Choose static or dynamic linkage") orelse .static;

    const plutovg = b.dependency("plutovg", .{});

    // Now, we will create a static library based on the module we created above.
    // This creates a `std.Build.Step.Compile`, which is the build step responsible
    // for actually invoking the compiler.
    const vg_lib = b.addLibrary(.{
        .name = "plutovg",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = linkage,
    });

    vg_lib.addCSourceFiles(.{
        .root = plutovg.path("source"),
        .files = &.{
            "plutovg-blend.c",
            "plutovg-canvas.c",
            "plutovg-font.c",
            "plutovg-matrix.c",
            "plutovg-paint.c",
            "plutovg-path.c",
            "plutovg-rasterize.c",
            "plutovg-surface.c",
            "plutovg-ft-math.c",
            "plutovg-ft-raster.c",
            "plutovg-ft-stroker.c",
        },
    });
    vg_lib.addIncludePath(plutovg.path("include"));
    vg_lib.installHeadersDirectory(plutovg.path("include"), "", .{});

    b.installArtifact(vg_lib);

    const plutosvg = b.dependency("plutosvg", .{});

    const svg_lib = b.addLibrary(.{
        .name = "plutosvg",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = linkage,
    });

    svg_lib.addCSourceFiles(.{
        .root = plutosvg.path("source"),
        .files = &.{"plutosvg.c"},
    });
    svg_lib.installHeadersDirectory(plutosvg.path("source"), "", .{});
    svg_lib.linkLibrary(vg_lib);
    svg_lib.installLibraryHeaders(vg_lib);

    b.installArtifact(svg_lib);

    // Export the Zig module downstream
    const plutosvg_mod = b.addModule("plutosvg", .{
        .root_source_file = b.path("lib/plutosvg.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    plutosvg_mod.linkLibrary(vg_lib);
    plutosvg_mod.linkLibrary(svg_lib);

    // Add example executable
    const example = b.addExecutable(.{
        .name = "camera2png",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    example.addCSourceFile(.{ .file = plutosvg.path("examples/camera2png.c") });
    example.linkLibrary(svg_lib);

    const example_svg = b.addInstallFileWithDir(plutosvg.path("examples/camera.svg"), .bin, "camera.svg");
    b.getInstallStep().dependOn(&example_svg.step);

    b.installArtifact(example);

    // Add unit tests
    const test_exe = b.addTest(.{
        .root_module = plutosvg_mod,
    });

    const run_step = b.addRunArtifact(test_exe);
    run_step.has_side_effects = true; // Force the test to always be run on command
    const step = b.step("test", "");
    step.dependOn(&run_step.step);
}
