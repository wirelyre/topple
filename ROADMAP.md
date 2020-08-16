Roadmap
=======

* Python
    - error handling --- creating stack traces
        - big

* tests
    - test runner (Python module? separate files?)
    - tests for primitives
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
