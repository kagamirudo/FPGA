# Host smoke test (no Vitis). Board app is built inside Vitis from main.c.
CC      ?= gcc
CFLAGS  ?= -O2 -Wall -Wextra -std=c11 -DSVD_HOST_ONLY
LDFLAGS ?= -lm

HOST_SRCS = svd_ref.c svd_check.c svd_hw_dma.c test_host.c
HOST_BIN  = test_host

.PHONY: all host-test clean

all: host-test

$(HOST_BIN): $(HOST_SRCS) svd_ref.h svd_check.h svd_hw_dma.h svd_test_vectors.h
	$(CC) $(CFLAGS) -o $@ $(HOST_SRCS) $(LDFLAGS)

host-test: $(HOST_BIN)
	./$(HOST_BIN)

clean:
	rm -f $(HOST_BIN)
