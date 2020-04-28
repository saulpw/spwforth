
all: spwforth

test: spwforth core.4th
	cat core.4th | ./spwforth

spwforth: forth.o
	gcc -g -m32 $^ -o $@ -lc -lm

forth.o: forth.asm interpret.asm
	nasm -g -f elf -o $@ forth.asm

clean:
	rm -f *.o spwforth
