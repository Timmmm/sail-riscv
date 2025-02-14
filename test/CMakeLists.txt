add_subdirectory("riscv-tests")

find_executable(zig)

add_custom_command(COMMAND zig build --release=safe)

for ...
