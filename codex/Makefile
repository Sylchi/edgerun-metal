CC ?= cc
CFLAGS ?= -std=c11 -Wall -Wextra -Werror -O2
LDFLAGS ?=

BUILD_DIR ?= ../.build
BIN := $(BUILD_DIR)/codex
SRC := src/edgerun_c_agent.c

.PHONY: all clean test FORCE

all: $(BIN)

$(BIN): $(SRC) src/edgerun_c.c src/edgerun_c_game.c FORCE
	mkdir -p $(BUILD_DIR)
	rm -rf $(BIN)
	$(CC) $(CFLAGS) -o $@ $(SRC) $(LDFLAGS)

test: $(BIN)
	./$(BIN) --self-test

clean:
	rm -rf $(BIN)

FORCE:
