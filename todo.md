+ nasm or linker to include core.4th as extra data to pre interpret
* Test each core.4th individually one at a time
* Number in asm
* Floating bug is currently being handled by increasing input size by 2
    Ideally, we have some buffering so we get a line at a time
* 'TYPE' currently takes a ( ptr n -- ), and it should probably take a forth-str
