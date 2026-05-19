CC ?= cc
CFLAGS ?= -std=c11 -Wall -Wextra -Werror -O2
LDFLAGS ?=

BUILD_DIR ?= ../.build/codex
BIN := $(BUILD_DIR)/edgerun-c
SRC := src/edgerun_c.c

.PHONY: all clean test

all: $(BIN)

$(BIN): $(SRC)
	mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $@ $(SRC) $(LDFLAGS)

test: $(BIN)
	./$(BIN) --self-test

clean:
	rm -rf $(BUILD_DIR)
