# Topple

Topple is a simple, teeny-tiny programming language that is easy to implement.

- **simple:** Topple is a stack language with structured control flow.  There
  is almost no syntax at all.

- **teeny tiny:** There are only 40 built-in words (functions) and around 5
  other features.  The **full specification** is at the bottom of this
  document.

- **easy to implement:** There are three complete implementations of the
  language in this repository.  The shortest is under 300 lines of code.

```
: main
    "Hello world!\n"
    "1 + 2 = "   1 2 + .   "\n"
;

main
```

The language Topple is complete and has several features like memory allocation
and type checking.  However, the tools are not yet complete.  Future tools and
features are marked with a unicorn: 🦄.

- Features
  - 64-bit integers
  - byte arrays
  - pointers
  - memory allocation
  - safe memory access (no OOB, no uninitialized reads)
  - user-defined types
  - type checking

- Implementations
  - A simple, full implementation in Python (`src/simple.py`).
  - Another full implementation in Python (`src/python`).
  - A full implementation in C (`src/c`).
  - 🦄 A simple implementation in RISC-V assembly / raw machine code.
  - 🦄 A compiler for the full language written in Topple itself (`compiler`).



## Why?

Inspired by "Reflections on Trusting Trust", I want to bootstrap a large
computer system.  Specifically, I want to bootstrap a C compiler, linker,
*etc.* from hand-written machine code running in a minimal Linux environment.

Obviously it is completely impractical to write a C compiler in assembly, let
alone in machine code.  There needs to be a very simple language written in
machine code, which implements a more complex language, which itself can
finally host a C compiler.

Topple is that first step.  My early tests suggest that a (slow!) Topple
interpreter can be implemented in under 1KiB of x86_64 (not including a small
runtime written in Topple).  The RISC-V implementation should be roughly
similar, perhaps twice as large.

Then, with a compiler written in Topple, the first step is complete.

### Design considerations

This whole project is a delicate balance between features, complexity, and
practicality.

You could write a reverse hex dumper, then write another program to add labels,
and another to add assembly mnemonics, and so forth, until you have an
assembler.  But would that really be any easier than implementing all of those
features in the first place?

My goal with Topple is to make a single cohesive language.  I want to take a
*single* step and get as many features as possible.

One interesting question: How many features can you *ignore* in a simple
implementation?  In Topple, type checking and bounds checking can actually be
entirely ignored!  They are just safety features that SHOULD terminate the
program — valid programs MUST not violate them.

That's why user-defined types are in Topple, but local variables aren't.  Types
are easy to implement in assembly (ignore them); local variables require actual
program logic.

I expect that one more language will be necessary in the end: machine code →
Topple → ??? → C.  I think there's room for more features (*e.g.* variables,
functions, algebraic data types, static type checking) that would be useful and
pretty easy to implement before jumping into a full C compiler.

### Prior work

Over the years I've read about other projects with similar goals.

Some of them are stuck on the first step, using machine code to make impossibly
small languages with easy-to-implement features.  I think those projects are
doomed.  There's significant up-front cost to implement many useful features.

Some of them start on the final step, producing a fully-working C compiler!
But the bottom of their READMEs say "now you could write a Scheme interpreter
in assembly" — and you're not much further than where you started from.

I think Topple is a significant step.  A fully-designed language, with some
"high-level" features, which is able to compile itself.  I intend to use Topple
to continue this bootstrapping project.



---



## Full specification

Topple files are called "___.tpl".  They contain ASCII text.

```
: 2dup   over over  ;   \ ( a b -- a b a b )
: %      2dup / * - ;   \ ( a b -- a%b     )

: multiple?   % 0 = ;   \ ( a b -- b|a?    )



\ comments extend until the end of the line

: fizzbuzz1
  dup 15 multiple? if "FizzBuzz " drop exit then
  dup  5 multiple? if "Buzz "     drop exit then
  dup  3 multiple? if "Fizz "     drop exit then
  .
;

: main
    1

    begin   dup 30 <=   while
      dup fizzbuzz1
      1 +
    repeat

    drop
    "\n"
;

main
```

The legal characters are printable ASCII, spaces, and newlines.

Whitespace is used to separate words and terminate comments.  Otherwise,
whitespace is ignored (except within strings).

### Stack

All values are passed on a single stack.  Writing a number pushes that number
onto the top of the stack.  Words (operations) manipulate the top value(s) of
the stack.

The values on the stack can be numbers (64-bit integers), byte arrays,
pointers, and user-defined types.

By convention, when written left to write, the top of the stack is on the
right.

```
\ stack: (empty)

1
\ stack: 1

2 3
\ stack: 1 2 3

+
\ stack: 1 5

drop
\ stack: 1
```

The "signatures" of words are written in parentheses.

```
\ ( stack before word is executed -- stack afterwards )

\ +   ( a b -- a+b )
```

The stack can hold 10&thinsp;000 values.  Implementations should terminate the
program if the stack exceeds 10&thinsp;000 values.

### Words

Words are like functions.  Most words consume one or more values on the top of
the stack, then place other values on top of the stack.  Some words only
produce values; others only consume values.

Custom words can be defined:

```
: add1   \ ( a -- a+1 )
    1 +
;

\ now 'add1' can be used like any other word

3    \ stack: 3
add1 \ stack: 4
drop \ stack: (empty)



: +1   add1 ;
\ now '+1' has exactly the same meaning as 'add1'

3    \ stack: 3
+1   \ stack: 4
drop \ stack: (empty)
```

A definition consists of a colon **`:`**, then a name, then the body of the
word, and finally a semicolon **`;`**.

After a word is defined, it can be used like any other word.  Whenever its name
is reached, the body is executed.

Words can have any name consisting of printable characters without whitespace,
except they may not contain backslashes `\` or double quotes `"`.

It is illegal to redefine a word or number, or to define a word with the same
name as a built-in word or control word.  For example:

```
: abc ;   \ legal
: a&@ ;   \ legal

: abc ;   \ illegal: redefining 'abc'
: 123 ;   \ illegal: redefining '123'
: +   ;   \ illegal: redefining '+'
: if  ;   \ illegal: redefining 'if'
: :   ;   \ illegal: redefining ':'
```

It is illegal to define a word within the definition of another word.

Words must be defined *before* they are used.  However, a word may refer to
itself within its own body:

```
: recursive-print
    dup .
    1 +
    recursive-print
;

1 recursive-print   \ overflows the call stack eventually
```

### Constants and variables

The words **`constant`** and **`variable`** create new constants and variables,
and define new words.

```
5 constant x   \ defines 'x'
variable y     \ defines 'y@' and 'y!'
```

When `constant (name)` is reached, the value on top of the stack is removed and
stored.  The newly defined word `(name)` produces a copy of that value whenever
run.

When `variable (name)` is reached, the stack does not change right away.
Instead, *two* new words are defined.  The word `(name)!` removes and stores
the value on top of the stack ("sets" the variable).  The word `(name)@`
produces a copy of the value so stored ("gets" the variable).

The value stored in a variable can be overwritten with `(name)!` at any point.

It is illegal to access a variable before its value has been set.
Implementations should terminate the program.

`constant` and `variable` must only appear at the top level of a program.  They
must not appear within a colon `:` definition.

### Control flow

Words within a word body are executed in order, except when execution reaches
**conditions**, **loops**, and **exits**.

Conditions are denoted by the control words **`if`**, **`else`**, and
**`then`**.

```
: print-if-nonzero
    dup if
      .   \ the word '.' prints the number on top of the stack
    else
      drop
    then
;

1 print-if-nonzero   \ prints "1"
0 print-if-nonzero   \ does nothing



: print-'hi'-if-nonzero
    if
      "hi"
    then
;

1 print-'hi'-if-nonzero   \ prints "hi"
0 print-'hi'-if-nonzero   \ does nothing
```

Conditions are written `if (if-true) then` or `if (if-true) else (if-false)
then`.  When `if` is encountered, the top of the stack is consumed.  If the top
was anything except for the number 0, the body "if-true" is executed;
otherwise, the body "if-false" is executed, if present.

Only the number 0 is considered "falsy".  Every other value, including byte
arrays and pointers, is "truthy".

`then` is a little confusing here.  It is not used to mean "if this, then
that".  It means "if this, do some thing; else, do some other thing; *then*, in
any case, continue…".

Loops are denoted by the control words **`begin`**, **`while`**, and
**`repeat`**.

```
: count-down
    begin
      dup 0 >
    while
      dup .
      1 +
    repeat
    drop
;

10 count-down   \ prints "10 9 8 7 6 5 4 3 2 1 "
```

When executing a loop, the code between `begin` and `while` is *always* run.
When `while` is encountered, the top of the stack is consumed.  If the top was
anything except for the number 0 ("truthy"), the body of the loop is run, and
then at `repeat`, control loops back to `begin`; otherwise, the loop ends and
control resumes after `repeat`.

In loops, like in conditions, only the number 0 is falsy.  Any other value is
truthy.  However, in loops, all three of `begin`, `while`, and `repeat` must
appear, unlike in conditions where `else` is optional.

Exits are denoted by the control word **`exit`**. 

```
: a
    "Hello, "
    exit
    "world!\n"
;

a   \ prints "Hello, "

: b
    a
    "world!\n"
;

b   \ prints "Hello, world!"
```

When `exit` is encountered, the word stops running as though control reached
the semicolon `;`.  Even if `exit` occurs within a condition or a loop,
execution of the word stops completely.  Words calling the exiting word do not
exit, however.

Conditions, loops, and exits may be nested: for example, loop tests and bodies
can contain conditions and exits.

The control words `if`, `else`, `then`, `begin`, `repeat`, `while`, and `exit`
may *only* occur while defining a word — not at the top level of execution!

```
: a   if then else ;   \ legal

if then else   \ illegal
```

### Numbers

Arithmetic is 64-bit — that is, all operations are reduced modulo
2<sup>64</sup>.

To push a number onto the stack, the number is written in base 10.

```
2    \ stack: 2
15   \ stack: 2 15
*    \ stack: 30
drop \ stack: (empty)

0    \ stack: 0
1    \ stack: 0 1
-    \ stack: 2^64-1, or 18446744073709551615
```

The four arithmetic operations are **`+`**, **`-`**, **`*`**, and **`/`**,
representing addition, subtraction, multiplication, and (unsigned) division.
If the result is too large or small, it is reduced modulo 2<sup>64</sup>.

It is illegal to divide by 0, and implementations should terminate the program.

The bit operations **`<<`**, **`>>`**, **`not`**, **`and`**, **`or`**, and
**`xor`** perform bitwise operations.  `<<` and `>>` are left and right bit
shifts, and `and`, `or`, and `xor` are the respective binary boolean
operations.  `not` inverts the bits of a single number.

```
3 4   <<  .   \ 48
100 2 >>  .   \ 25
7 17  and .   \ 1
0 1 - not .   \ 0

3  4 << .   \ 48
3 68 << .   \ 48
```

The second argument of bit shifts is first reduced modulo 64 (not
2<sup>64</sup>) before shifting.  The right shift is a logical (unsigned)
shift.

The comparisons **`=`**, **`<>`**, **`<`**, **`>`**, **`<=`**, and **`>=`** are
unsigned comparisons.  `<>` means "not equal".

The two arguments must both be numbers.

If the comparison is true, the resulting value is a number with *all bits set*
— that is, 2<sup>64</sup> &minus; 1.  If the comparison is false, the resulting
value is the number 0.

```
0 1 = . \ 0
2 2 = . \ 18446744073709551615

0 1 < . \ 18446744073709551615
1 1 < . \ 0
```

### Stack manipulation

Values can be moved around on top of the stack.

The built-in words **`dup`** and **`drop`** are the most fundamental.  `dup`
duplicates the top value on the stack.  `drop` removes the top value from the
stack.

How are values duplicated?
- **Numbers:** a copy of the number is created. 
- **Byte arrays:** another reference to the *same byte array* is created.
- **Pointers:** a copy of the pointer is created.  The copy is distinct from
  the original, but they both point to the same underlying data (the same cell
  in the same block).

**`swap`** swaps the two values on top of the stack.  **`nip`** removes the
second-to-top value from the stack but leaves the top value.

**`tuck`**, **`over`**, **`rot`**, and **`-rot`** manipulate the stack as
indicated below.  Note that `tuck` and `over` duplicate values, while `rot` and
`-rot` merely rearrange them.

```
\ tuck   ( a b -- b a b )
\ over   ( a b -- a b a )

\ rot    ( a b c -- b c a )
\ -rot   ( a b c -- c a b )
```

**`pick`** consumes the top of the stack (which must be a number).  That number
is then used to index into the stack, from the top.  The value at that index is
duplicated on top of the stack.

```
3 4 5 6
0 pick .   \ 6
2 pick .   \ 4
```

The stack must contain enough values that the index refers to a value in the
stack (the index must be less than the number of values in the stack).
Implementations should terminate the program otherwise.

Use of `pick` is discouraged, because it makes the stack very difficult to
manage.  It is better to keep all active values on top of the stack, when
possible.

### Strings

A string is a sequence of characters between two double quotes `"`.  The
contents must be printable characters and spaces.

When executed, a string prints its contents to the output stream (probably
standard error).

Strings may occur anywhere: within definitions or at the top level.

```
"Hello, world!\n"

: backslash   "\\" ;

: a
    "Hello again! "
    backslash
    "\n"
;

a
```

The backslash `\` is used in escape sequences.  To print a backslash, newline,
or double quote character, the appropriate escape sequence is used:

```
"newline:      \n"
"double quote: \" \n"
"backslash:    \\ \n"
```

### Input and output

The primitives **`.`** and **`putc`** print to the output stream (probably
standard error).

`.` consumes a number and prints it in base 10, followed by a space.

`putc` consumes a number and prints its decoded ASCII value.  The number must
represent a printable ASCII character, or a space, or a newline.

```
5 .       \ prints "5 "
97 putc   \ prints "a"
```

The primitive **`fail`** consumes a number, then terminates the entire program
immediately.  The number is used as an error code.

```
2 fail   \ terminates the program with error code 2
```

### Byte arrays

A byte array is created with **`bytes.new`**.

```
bytes.new   \ stack: a-byte-array
bytes.new   \ stack: a-byte-array another-byte-array
```

Byte arrays hold a sequence of octets, or 8-bit bytes.  Byte arrays start empty
but can grow arbitrarily large.

When a byte array value is duplicated, the two values refer to the same byte
array.

```
bytes.new   \ stack: array-a
dup         \ stack: array-a array-a
bytes.new   \ stack: array-a array-a array-b
```

The primitive **`b%`** appends a byte to a byte array, growing the array by one
byte.  The appended byte is first reduced modulo 256 (2<sup>8</sup>).

```
bytes.new
5   over b%
257 over b%

\ byte array is now length 2
\ and contains [5, 1]
```

The primitives **`b@`** and **`b!`** get and set bytes at given indexes in a
byte array.  The indexes are supplied as stack arguments.  The byte given to
**`b!`** is first reduced modulo 256 (2<sup>8</sup>).

```
bytes.new constant arr

5 arr b%
6 arr b%   \ array: [5, 6]

0   arr b@ .   \ 5
7 1 arr b!     \ array: [5, 7]
```

It is illegal to use an index past the end of a byte array.  The only way to
grow a byte array is through `b%`.

The current length of a byte array can be determined with **`bytes.length`**.
A byte array can be cleared (setting its length to 0) with **`bytes.clear`**.

```
bytes.new
5 over b%
6 over b%

dup bytes.length . \ 2
dup bytes.clear
dup bytes.length . \ 0
```

The primitive **`file.read`** opens a file and copies its contents into a *new*
byte array.  It consumes a single byte array argument, which is the path of the
file.  The exact way the path is interpreted is implementation dependent.

If the file exists, the result is a new byte array with the file's contents.
If the file does not exist, the result is the number 0.

This means that successful reads are truthy, and unsuccessful reads are falsy.

### Blocks and pointers

Besides byte arrays, chunks of memory may be allocated dynamically.  A
**block** is a region of memory that contains space for **400** values.  Each
place for a value is called a **cell**.

A block is allocated with **`block.new`**.  This creates a new block and
produces a **pointer** to the first cell in the block.

Pointers must always be valid.  They must always point at a cell within their
block.

The value in a cell can be stored with **`!`**, and can be retrieved with `@`.

```
block.new constant b

1 b !
b @ . \ 1
2 b !
b @ . \ 2
```

Any value may be stored in a cell: a number, a byte array, a pointer, or a
user-defined type.

It is illegal to read a cell before any value has been stored inside of it.
Implementations should terminate the program in this case.

A pointer can be offset with **`+p`**.  This moves the pointer the specified
number of cells forward *or backward*.  `+p` is the only built-in word that
treats a number as signed (two's complement).

```
block.new constant a

a 1 +p constant b

1 a !
a @ . \ 1
2 b !
b @ . \ 2

: -1   0 1 - ;
b -1 +p constant c
c @ . \ 1
```

When a pointer is duplicated, it produces an identical pointer: it points to
the same cell in the same block.  When a pointer is offset, it produces a new
pointer to a different cell in the same block.

In other words, pointers are transient values, like numbers.  But the memory
they point to is persistent, like byte arrays.

### User-defined types

New types (other than numbers, byte arrays, and pointers) are defined with
**`type`**.

```
type a
type b
```

`type (name)` defines two new words: `>(name)` and `<(name)`.  These
respectively convert pointers *into* and *from* the new type.

User-defined types are very useful when developing new data structures — for
example, a linked list.  Fundamental operations, like pushing to the front of
the list, can use `<list` to ensure that the provided argument is indeed a
list.  Then other code can treat lists as black boxes, using only the interface
provided by those operations.

```
block.new constant mem

type a
type b

mem >a   \ stack: a
<a       \ stack: ptr
drop

mem >b   \ stack: b
<b       \ stack: ptr
drop

mem >a <b   \ illegal
```

User-defined types are like wrappers for pointers.  A pointer can be converted
into a user-defined type; and a value of the user-defined type can be converted
back into a pointer.

The only legal operation on a value of user-defined type is to convert it back
into a pointer using the matching conversion.

It is illegal to convert from a user-defined type using the wrong conversion.

It is illegal to convert from a user-defined type directly into another
user-defined type.

User-defined types do not provide any extra memory safety.  They merely help
prevent type-related logic errors, like using a group of cells that is supposed
to be a list as a hash table.

User-defined types are designed this way so that simple implementations can
completely ignore them.  A simple implementation may assume that all type
conversions are correct, and thus meaningless.  Then `type (name)` can simply
define `>(name)` and `<(name)` to do nothing at all.

### Summary of errors

It is illegal to:

- Source code
  - Execute source code that is not valid ASCII.
  - Execute source code that contains non-printable ASCII characters other than
    spaces and newlines.
  - Execute source code that contains an unterminated string.

- Syntax
  - Execute source code with unterminated colon `:` definitions.
  - Execute source code with nested colon `:` definitions.
  - Execute source code with mismatched control structures (*e.g.* `if begin
    then repeat`).
  - Execute source code with control structures outside of definitions.
  - Define a number as a word.
  - Define a word more than once.
  - Redefine a control word.

- Semantics
  - Run a word before it is defined.
  - Run a word with too few values on the stack (see words below).
  - Run a word with the wrong types of values on the stack (see words below).
  - Run `if` or `while` with an empty stack (see control flow above).
  - Define a constant with an empty stack.
  - Exceed 10&thinsp;000 values on the stack.
  - Divide by zero.
  - Run `pick` with too few values on the stack.
  - Print an unprintable character (not including space or newline).
  - Access a byte array with an invalid index.
  - Offset a pointer outside of its 400-cell block.
  - Access a variable or cell before it has been set.
  - Convert from anything other than a pointer into a user-defined type.
  - Convert from a user-defined type using the wrong conversion word.

### Summary of words

#### Control
```
: (name)   (body...)   ;    =>   (name)

(value)   constant (name)   =>   (name)
          variable (name)   =>   (name)@ (name)!
          type     (name)   =>   >(name) <(name)

if ... then
if ... else ... then
begin ... while ... repeat
exit
```

#### Arithmetic
```
(numbers)
+   ( a b -- a+b )
-   ( a b -- a-b )
*   ( a b -- a*b )
/   ( a b -- a/b )
```

#### Bitwise operations
```
(numbers)
<<   ( a b -- a<<(b%64) )
>>   ( a b -- a>>(b%64) )
not  ( a   -- ~a        )
and  ( a b -- a&b       )
or   ( a b -- a|b       )
xor  ( a b -- a^b       )
```

#### Comparison
```
(numbers)
=    ( a b -- a=b  )
<>   ( a b -- a!=b )
<    ( a b -- a<b  )
>    ( a b -- a>b  )
<=   ( a b -- a<=b )
>=   ( a b -- a>=b )
```

#### Stack
```
(any values)
dup    ( a     -- a a   )
drop   ( a     --       )
swap   ( a b   -- b a   )
nip    ( a b   -- b     )
tuck   ( a b   -- b a b )
over   ( a b   -- a b a )
rot    ( a b c -- b c a )
-rot   ( a b c -- c a b )

('n' a number)
pick   ( ... x2 x1 x0 n -- ... x2 x1 x0 xn )
```

#### Input and output
```
(numbers)
.      ( n -- )
putc   ( n -- )
fail   ( n -- )
```

#### Byte arrays
```
bytes.new      ( -- bytes )
bytes.clear    ( bytes -- )
bytes.length   ( bytes -- n )

b%   ( b bytes     --   )
b@   ( idx bytes   -- b )
b!   ( b idx bytes --   )

file.read   ( bytes -- bytes-or-0 )
```

#### Blocks
```
block.new   ( -- ptr )

@   ( ptr   -- v )
!   ( v ptr --   )

+p   ( ptr n -- ptr )
```
