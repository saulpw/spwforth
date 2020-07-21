# spwforth

This is a simple Forth-lite implementation written in 32-bit x86 assembly for Linux.
It's meant as a demonstration of the core functionality of a Forth interpreter, as a reference besides the usual JonesForth etc.

## Requires Linux



## Usage

    make test

###

Things that work:

- `:` colon definitions and `IMMEDIATE` words


## Requirements

- nasm for assembly
- gcc for linking
- Linux for stdin/stdout/exit (`int 0x80`)
- libc for `strtol` and `snprintf`


# References

- [JonesForth](https://github.com/nornagon/jonesforth/blob/master/jonesforth.S)
- [Moving Forth by Brad Rodriguez](https://www.bradrodriguez.com/papers/moving1.htm)
[Part 2](https://www.bradrodriguez.com/papers/moving2.htm)
[3](https://www.bradrodriguez.com/papers/moving3.htm)
[4](https://www.bradrodriguez.com/papers/moving4.htm)
[5](https://www.bradrodriguez.com/papers/moving5.htm)
[6](https://www.bradrodriguez.com/papers/moving6.htm)
[7](https://www.bradrodriguez.com/papers/moving7.htm)
[8](https://www.bradrodriguez.com/papers/moving8.htm) (1993-1995)
- [A Beginner's Guide to Forth by J.V. Noble](http://galileo.phys.virginia.edu/classes/551.jvn.fall01/primer.htm) (2001)
