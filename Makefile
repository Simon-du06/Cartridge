# Simple makefile for assembling and linking a GB program.
ASM             := rgbasm
LINKER          := rgblink
FIX             := rgbfix

PROJECT_NAME    := hello-world
BUILD_DIR       := build
OBJ_DIR         := $(BUILD_DIR)/obj
OUTPUT          := $(BUILD_DIR)/$(PROJECT_NAME)
ROOT_ROM        := $(PROJECT_NAME).gb
INC_DIR         := inc/

# Explicit source list (add files here manually).
SRC_FILES       := \
	hello-world.asm

OBJ_FILES       := $(patsubst %.asm,$(OBJ_DIR)/%.o,$(SRC_FILES))
OBJ_DIRS        := $(sort $(dir $(OBJ_FILES)))

ASMFLAGS        := -p0 -v -i $(INC_DIR)
FIXFLAGS        := -v -p0

.PHONY: all clean

all: $(OUTPUT).gb

$(OUTPUT).gb: $(OBJ_FILES) | $(BUILD_DIR)
	$(LINKER) -o $@ $(OBJ_FILES)
	$(FIX) $(FIXFLAGS) $@
	cp $@ $(ROOT_ROM)

$(OBJ_DIR)/%.o: %.asm | $(OBJ_DIRS)
	$(ASM) -o $@ $(ASMFLAGS) $<

$(BUILD_DIR) $(OBJ_DIRS):
	mkdir -p $@

clean:
	rm -rf $(BUILD_DIR)
	
fclean: clean
	rm -f $(ROOT_ROM)

re: clean all

print-%: ; @echo $* = $($*)