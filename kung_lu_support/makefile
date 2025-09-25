CC = gcc
CFLAGS = -Wall -O2

# API library
EXE_DIR = exe
OBJ_DIR = obj
LIB_TARGET = $(EXE_DIR)/liblu_io.a
LIB_SRCS = lu_io.c

# Test executable
TEST_TARGET = $(EXE_DIR)/lu_io_test
TEST_SRCS = test_lu_io.c

# Simulation test executable
SIM_TEST_TARGET = $(EXE_DIR)/test_lu_simulation
SIM_TEST_SRCS = test_lu_simulation.c

# Simple test executable
SIMPLE_TEST_TARGET = $(EXE_DIR)/simple_test
SIMPLE_TEST_SRCS = simple_test.c

# Example executable
EXAMPLE_TARGET = $(EXE_DIR)/lu_io_example
EXAMPLE_SRCS = example.c

all: $(LIB_TARGET) $(TEST_TARGET) $(SIM_TEST_TARGET) $(EXAMPLE_TARGET) $(SIMPLE_TEST_TARGET)

# Build static library
$(LIB_TARGET): $(LIB_SRCS)
	mkdir -p $(OBJ_DIR)
	mkdir -p $(EXE_DIR)
	$(CC) $(CFLAGS) -c $(LIB_SRCS) -o $(OBJ_DIR)/lu_io.o
	ar rcs $(LIB_TARGET) $(OBJ_DIR)/lu_io.o

# Build test executable
$(TEST_TARGET): $(TEST_SRCS) $(LIB_TARGET)
	mkdir -p $(EXE_DIR)
	$(CC) $(CFLAGS) -o $(TEST_TARGET) $(TEST_SRCS) -L$(EXE_DIR) -llu_io

# Build simulation test executable
$(SIM_TEST_TARGET): $(SIM_TEST_SRCS) $(LIB_TARGET)
	mkdir -p $(EXE_DIR)
	$(CC) $(CFLAGS) -o $(SIM_TEST_TARGET) $(SIM_TEST_SRCS) -L$(EXE_DIR) -llu_io

# Build example executable
$(EXAMPLE_TARGET): $(EXAMPLE_SRCS) $(LIB_TARGET)
	mkdir -p $(EXE_DIR)
	$(CC) $(CFLAGS) -o $(EXAMPLE_TARGET) $(EXAMPLE_SRCS) -L$(EXE_DIR) -llu_io

# Build simple test executable
$(SIMPLE_TEST_TARGET): $(SIMPLE_TEST_SRCS) $(LIB_TARGET)
	mkdir -p $(EXE_DIR)
	$(CC) $(CFLAGS) -o $(SIMPLE_TEST_TARGET) $(SIMPLE_TEST_SRCS) -L$(EXE_DIR) -llu_io

# Run test
run: $(TEST_TARGET)
	./$(TEST_TARGET)

# Run simulation test
run-sim: $(SIM_TEST_TARGET)
	./$(SIM_TEST_TARGET)

# Run example
example: $(EXAMPLE_TARGET)
	./$(EXAMPLE_TARGET)

# Run simple test
simple-test: $(SIMPLE_TEST_TARGET)
	./$(SIMPLE_TEST_TARGET)

# Get help
help:
	@echo "Usage: make <target>"
	@echo "Targets:"
	@echo "  all         - Build all executables"
	@echo "  lib         - Build library only"
	@echo "  test        - Build test executable"
	@echo "  sim-test    - Build simulation test executable"
	@echo "  example     - Build example executable"
	@echo "  simple-test - Build simple test executable"
	@echo "  run         - Run test executable"
	@echo "  run-sim     - Run simulation test executable"
	@echo "  example     - Run example executable"
	@echo "  simple-test - Run simple test executable"
	@echo "  help        - Show this help message"
	@echo "  clean       - Clean all generated files"
	@echo "  install     - Install library system-wide (optional)"

# Clean all generated files
clean:
	rm -rf $(EXE_DIR)
	rm -rf $(OBJ_DIR)

# Install library (optional)
install: $(LIB_TARGET)
	cp $(LIB_TARGET) /usr/local/lib/
	cp lu_io.h /usr/local/include/

.PHONY: all run run-sim clean install
