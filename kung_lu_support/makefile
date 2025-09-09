CC = gcc
CFLAGS = -Wall -O2

# API library
LIB_TARGET = liblu_io.a
LIB_SRCS = lu_io.c

# Test executable
TEST_TARGET = lu_io_test
TEST_SRCS = test_lu_io.c

# Example executable
EXAMPLE_TARGET = lu_io_example
EXAMPLE_SRCS = example.c

all: $(LIB_TARGET) $(TEST_TARGET) $(EXAMPLE_TARGET)

# Build static library
$(LIB_TARGET): $(LIB_SRCS)
	$(CC) $(CFLAGS) -c $(LIB_SRCS) -o lu_io.o
	ar rcs $(LIB_TARGET) lu_io.o

# Build test executable
$(TEST_TARGET): $(TEST_SRCS) $(LIB_TARGET)
	$(CC) $(CFLAGS) -o $(TEST_TARGET) $(TEST_SRCS) -L. -llu_io

# Build example executable
$(EXAMPLE_TARGET): $(EXAMPLE_SRCS) $(LIB_TARGET)
	$(CC) $(CFLAGS) -o $(EXAMPLE_TARGET) $(EXAMPLE_SRCS) -L. -llu_io

# Run test
run: $(TEST_TARGET)
	./$(TEST_TARGET)

# Run example
example: $(EXAMPLE_TARGET)
	./$(EXAMPLE_TARGET)

# Clean all generated files
clean:
	rm -f $(LIB_TARGET) $(TEST_TARGET) $(EXAMPLE_TARGET) lu_io.o

# Install library (optional)
install: $(LIB_TARGET)
	cp $(LIB_TARGET) /usr/local/lib/
	cp lu_io.h /usr/local/include/

.PHONY: all run clean install
