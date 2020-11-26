Roadmap
=======

* compiler
    - hash map
    - stubs for code generation
    - command-line argument parser
    - tokenizer
    - put control words in hash map
    - plan out parse stack
    - parser
    - file.write

* RISC-V (RV64MC) compiler

    - compile simple program by hand
        - (using C toolchain assembler / linker)
        - type checking
        - primitives

    - assembler in Python
        - DB for ELF header
        - ORG
        - arithmetic expression parsing
        - ADD, ADDI, LUI
        - JAL, JALR
        - labels
        - fixups
        - other instructions

    - self-compiler:
        - ELF header
        - code sections
        - ELF header finalization
        - instruction encoders
        - code generation

* tests
    - tests for control structures

* Python: compile to C
    - depend on topple.h, primitives.c, util.c
    - primitives.c becomes non-static
    - C word->identifier generator
    - C source/brackets alignment
    - AST->C

* x86_64 ASM interpreter
    - C to test ASM piece by piece
    - strcmp
    - read_word
    - find_word?
    - ???
    - primitives:
        - + - * /
        - NOR
        - : ;
        - S @ !
        - ' or [ ] or TOGGLE-COMPILING
        - FORGET ?
            - no need, new definitions overwrite old ones
        - type
            - define two words, maybe need primitive?
        - C@ C!
        - SYSCALL
