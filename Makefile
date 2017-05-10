
all: spwforth

test: spwforth
	cat core.4th | ./spwforth

spwforth: forth.o
	gcc -g -m32 $^ -o $@ -lc -lm

%.o: %.asm
	nasm -g -f elf -o $@ $<

clean:
	rm -f *.o spwforth
