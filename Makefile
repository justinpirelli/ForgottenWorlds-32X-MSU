# ============================================================================
# Forgotten Worlds: CPS1 EDITION (32X + Sega CD Mode 1) Makefile
# ============================================================================

# Toolchains (Standard marsdev / GCC cross-compiler prefixes)
M68K_CC      = m68k-elf-gcc
M68K_AS      = m68k-elf-as --register-prefix-optional
M68K_LD      = m68k-elf-ld
M68K_OBJCOPY = m68k-elf-objcopy

SH2_CC       = sh-elf-gcc
SH2_AS       = sh-elf-as
SH2_LD       = sh-elf-ld
SH2_OBJCOPY  = sh-elf-objcopy

# Compiler Flags
M68K_CFLAGS  = -m68000 -O2 -Wall -Wextra -fno-leading-underscore -ffreestanding -nostdlib
SH2_CFLAGS   = -m3 -mb -O2 -Wall -Wextra -fno-leading-underscore -ffreestanding -nostdlib

# Directories
BUILD_DIR    = build
OUT_DIR      = out
TARGET_ROM   = $(OUT_DIR)/fw32x.32x

# Source Files
SCD_SRC      = src_scd/sub_cpu.s
SH2_ASM_SRC  = src_sh2/sh2_boot.s
SH2_C_SRC    = src_sh2/sh2_main.c src_sh2/cps1_blitter.c
M68K_ASM_SRC = src_68k/boot_32x.s src_68k/msu_mode1.s
M68K_C_SRC   = src_68k/main_68k.c

.PHONY: all clean dirs

all: dirs $(TARGET_ROM)

dirs:
	mkdir -p $(BUILD_DIR) $(OUT_DIR)

# ----------------------------------------------------------------------------
# Stage 1: Assemble Sega CD Sub-CPU Mode 1 Payload -> build/sub_cpu.bin
# ----------------------------------------------------------------------------
$(BUILD_DIR)/sub_cpu.o: $(SCD_SRC)
	$(M68K_AS) -m68000 $< -o $@

$(BUILD_DIR)/sub_cpu.bin: $(BUILD_DIR)/sub_cpu.o
	$(M68K_OBJCOPY) -O binary $< $@

# ----------------------------------------------------------------------------
# Stage 2: Compile & Link Dual SH-2 Graphics Engine -> build/sh2_code.bin
# ----------------------------------------------------------------------------
$(BUILD_DIR)/sh2_boot.o: $(SH2_ASM_SRC)
	$(SH2_AS) --isa=sh2 --big $< -o $@

$(BUILD_DIR)/sh2_main.o: src_sh2/sh2_main.c src_sh2/cps1_blitter.h
	$(SH2_CC) $(SH2_CFLAGS) -c $< -o $@

$(BUILD_DIR)/cps1_blitter.o: src_sh2/cps1_blitter.c src_sh2/cps1_blitter.h
	$(SH2_CC) $(SH2_CFLAGS) -c $< -o $@

$(BUILD_DIR)/sh2_code.elf: $(BUILD_DIR)/sh2_boot.o $(BUILD_DIR)/sh2_main.o $(BUILD_DIR)/cps1_blitter.o
	$(SH2_LD) -EB -Ttext 0x06000000 $^ -o $@

$(BUILD_DIR)/sh2_code.bin: $(BUILD_DIR)/sh2_code.elf
	$(SH2_OBJCOPY) -O binary $< $@

# Wrap SH-2 binary into a 68000 linkable object (.sh2_binary section)
$(BUILD_DIR)/sh2_blob.o: $(BUILD_DIR)/sh2_code.bin
	$(M68K_OBJCOPY) -I binary -O elf32-m68k -B m68k \
		--rename-section .data=.sh2_binary,alloc,load,readonly,data,contents \
		$< $@

# ----------------------------------------------------------------------------
# Stage 3: Compile Genesis 68000 Code & Link Final .32x Cartridge ROM
# ----------------------------------------------------------------------------
$(BUILD_DIR)/boot_32x.o: src_68k/boot_32x.s
	$(M68K_AS) -m68000 $< -o $@

$(BUILD_DIR)/msu_mode1.o: src_68k/msu_mode1.s $(BUILD_DIR)/sub_cpu.bin
	$(M68K_AS) -m68000 $< -o $@

$(BUILD_DIR)/main_68k.o: src_68k/main_68k.c
	$(M68K_CC) $(M68K_CFLAGS) -c $< -o $@

$(BUILD_DIR)/fw32x.elf: $(BUILD_DIR)/boot_32x.o $(BUILD_DIR)/msu_mode1.o $(BUILD_DIR)/main_68k.o $(BUILD_DIR)/sh2_blob.o
	$(M68K_LD) -T 32x.ld $^ -o $@

$(TARGET_ROM): $(BUILD_DIR)/fw32x.elf
	$(M68K_OBJCOPY) -O binary $< $@

clean:
	rm -rf $(BUILD_DIR) $(OUT_DIR)
