add_subdirectory("riscv-tests")

# Zig tests.

find_program(ZIG_BIN "zig")
if (NOT ZIG_BIN)
    message(FATAL_ERROR "zig not found. See README.md for installation instructions.")
endif()
message(STATUS "Found zig: ${ZIG_BIN}")

# This will always run zig build, but nop builds are extremely fast (a few ms)
# so we don't need to have CMake track dependencies too.
add_custom_target(zig_tests ALL
    ${ZIG_BIN} build --release=safe
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/sail-riscv-zig-tests"
    VERBATIM
)

foreach (test_name IN ITEMS test_hello_world test_max_pmp)
    add_test(
        NAME "zig_rv32d_${test_name}"
        COMMAND $<TARGET_FILE:riscv_sim_rv32d> --pmp-count 16 "${CMAKE_CURRENT_SOURCE_DIR}/sail-riscv-zig-tests/zig-out/bin/${test_name}.elf"
    )
endforeach()
