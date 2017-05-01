
all: spwforth

spwforth: forth.o
	ld -m elf_i386 -o $@ $^

%.o: %.asm
	nasm -g -f elf -o $@ $<
