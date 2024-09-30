%.elf: %.c crt0.S encoding.h
	riscv64-unknown-elf-gcc  -march=rv64g -mabi=lp64d -nostartfiles -static -mcmodel=medany -fvisibility=hidden -Wall -Werror -Wl,--no-warn-rwx-segments -O2 -T link.ld $^ -o $@
