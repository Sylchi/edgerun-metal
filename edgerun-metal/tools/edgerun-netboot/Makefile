CC := cc
CFLAGS := -std=c11 -Wall -Wextra -Werror -O2

TARGET := ../../build/edgerun-netboot
SRC := main.c

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(SRC)
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f $(TARGET)
