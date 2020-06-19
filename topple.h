#ifndef TOPPLE_H
#define TOPPLE_H

#include <inttypes.h>
#include <stdbool.h>
#include <stdnoreturn.h>



enum type {
    EMPTY,
    NUMBER,
    POINTER,
    BYTES,
};

typedef   struct block           block;
typedef   struct bytes           bytes;
typedef   struct control         control;
typedef   struct control_state   control_state;
typedef   struct instruction     instruction;
typedef   struct primitive       primitive;
typedef   struct program         program;
typedef   struct stack           stack;
typedef   enum   type            type;
typedef   struct value           value;

struct value {
    type type;

    unsigned block_offset;

    union {
        uint64_t num;
        block   *ptr;
        bytes   *bytes;
    };
};

struct block {
    uint64_t ref_count;
    value    values[400];
};

struct bytes {
    uint64_t       ref_count;
    uint64_t       length;
    uint64_t       capacity;
    unsigned char *contents;
};

struct primitive {
    char *name;
    void (*action)(stack *);
};

struct control {
    char *name;
    void (*action)(void);
};

struct control_state {
    enum {
        DEFINITION,
        IF,
        ELSE,
        BEGIN,
        WHILE,
    } kind;
    size_t pos;
};

struct instruction {
    enum {
        BRANCH,
        CALL,
        JUMP,
        LITERAL,
        PRIMITIVE,
        RETURN,
        STRING,
    } type;

    union {
        uint64_t data;
        char    *string;
    };
};


noreturn void fail(const char *);

value duplicate  (value);
void  discard    (value);
void  block_clear(block *);
bool  falsy      (value);

stack *stack_alloc(void);
void   stack_push (stack *, value);
value  stack_pop  (stack *);

void     program_primitive(uint64_t);
void     program_string   (char *);

char *read_word(void);

extern instruction CODE[];

extern const control   CONTROLS[];
extern const primitive PRIMITIVES[];



#endif
