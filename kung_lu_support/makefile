CC = gcc
CFLAGS = -Wall -O2

EXE_DIR = exe
OBJ_DIR = obj

LIB_TARGET = $(EXE_DIR)/liblu_io.a
LIB_SRCS = lu_io.c

# Each executable: TARGET name, its single source file, and the `make`
# alias used to run it. Add a new line here (and to EXECUTABLES/help below)
# to wire up a new test/example program -- the build rule is shared.
TEST_TARGET         = $(EXE_DIR)/lu_io_test
TEST_SRCS           = test_lu_io.c
SIM_TEST_TARGET      = $(EXE_DIR)/test_lu_simulation
SIM_TEST_SRCS        = test_lu_simulation.c
SIMPLE_TEST_TARGET   = $(EXE_DIR)/simple_test
SIMPLE_TEST_SRCS     = simple_test.c
PADDING_TEST_TARGET  = $(EXE_DIR)/test_padding
PADDING_TEST_SRCS    = test_padding.c
EXAMPLE_TARGET       = $(EXE_DIR)/lu_io_example
EXAMPLE_SRCS         = example.c

EXECUTABLES = $(TEST_TARGET) $(SIM_TEST_TARGET) $(SIMPLE_TEST_TARGET) $(PADDING_TEST_TARGET) $(EXAMPLE_TARGET)

all: $(LIB_TARGET) $(EXECUTABLES)

# Build static library
$(LIB_TARGET): $(LIB_SRCS)
	mkdir -p $(OBJ_DIR) $(EXE_DIR)
	$(CC) $(CFLAGS) -c $(LIB_SRCS) -o $(OBJ_DIR)/lu_io.o
	ar rcs $(LIB_TARGET) $(OBJ_DIR)/lu_io.o

# Shared build recipe for every test/example executable: each depends on its
# own source plus the library, and links the same way.
define BUILD_EXE
$(1): $(2) $(LIB_TARGET)
	mkdir -p $(EXE_DIR)
	$(CC) $(CFLAGS) -o $(1) $(2) -L$(EXE_DIR) -llu_io
endef

$(eval $(call BUILD_EXE,$(TEST_TARGET),$(TEST_SRCS)))
$(eval $(call BUILD_EXE,$(SIM_TEST_TARGET),$(SIM_TEST_SRCS)))
$(eval $(call BUILD_EXE,$(SIMPLE_TEST_TARGET),$(SIMPLE_TEST_SRCS)))
$(eval $(call BUILD_EXE,$(PADDING_TEST_TARGET),$(PADDING_TEST_SRCS)))
$(eval $(call BUILD_EXE,$(EXAMPLE_TARGET),$(EXAMPLE_SRCS)))

# Run targets (one per executable)
run: $(TEST_TARGET)
	./$(TEST_TARGET)

run-sim: $(SIM_TEST_TARGET)
	./$(SIM_TEST_TARGET)

simple-test: $(SIMPLE_TEST_TARGET)
	./$(SIMPLE_TEST_TARGET)

run-padding: $(PADDING_TEST_TARGET)
	./$(PADDING_TEST_TARGET)

example: $(EXAMPLE_TARGET)
	./$(EXAMPLE_TARGET)

help:
	@echo "Usage: make <target>"
	@echo "Targets:"
	@echo "  all         - Build library + all executables"
	@echo "  run         - lu_io_test (band matrix / API demo)"
	@echo "  run-sim     - test_lu_simulation (recommended)"
	@echo "  run-padding - test_padding (padding correctness)"
	@echo "  simple-test - simple_test"
	@echo "  example     - lu_io_example"
	@echo "  clean       - Remove exe/ and obj/"
	@echo "  install     - Install lib + header (sudo)"

clean:
	rm -rf $(EXE_DIR) $(OBJ_DIR)

install: $(LIB_TARGET)
	cp $(LIB_TARGET) /usr/local/lib/
	cp lu_io.h /usr/local/include/

.PHONY: all run run-sim run-padding simple-test example help clean install
