#ifndef TOPPLE_H
#define TOPPLE_H


#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdnoreturn.h>


typedef struct ASTNode   ASTNode;
typedef struct Block     Block;
typedef struct Bytes     Bytes;
typedef struct Primitive Primitive;
typedef struct Stack     Stack;
typedef struct Value     Value;


noreturn void fail(const char *s);

char *read_token(void);

void     dup           (Value);
void     discard       (Value);
bool     truthy        (Value);
uint64_t num_of_val    (Value);
Value    val_of_num    (uint64_t);
Value    val_of_bool   (bool);
Value    expect_bytes  (Value);
Value    expect_pointer(Value);

Stack *stack_new (void);
void   stack_push(Stack *, Value);
Value  stack_pop (Stack *);
Value  stack_pick(Stack *, size_t);

ASTNode   *parse_program (void);
Primitive *find_primitive(const char *);
void       dump_ast      (ASTNode *);


enum type {
    UNDEFINED,
    BYTES,
    NUMBER,
    POINTER,
};

struct Value {
    uint16_t type;
    union {
        Bytes   *bytes;
        uint64_t number;
        struct {
            Block   *block;
            uint16_t cell;
        } pointer;
    };
};

struct Stack {
    size_t len;
    Value values[10000];
};

struct Primitive {
    char const *name;
    void      (*action)(Stack *);
};

struct Block {
    size_t ref_count;
    Value  cells[400];
};

struct Bytes {
    size_t ref_count;
    size_t len;
    size_t cap;
    unsigned char *contents;
};

struct ASTNode {
    enum {
        CONDITIONAL,
        LOOP,
        LITERAL,
        PRIMITIVE,
        SEQUENCE,
        STRING,
        WORD,
    } kind;

    union {
        uint64_t    number;
        Primitive  *primitive;
        const char *string;


        struct {
            ASTNode *if_true;
            ASTNode *if_false;
        } conditional;

        struct {
            ASTNode *test;
            ASTNode *body;
        } loop;

        struct {
            size_t   len;
            size_t   cap;
            ASTNode *contents[];
        } sequence;

        struct {
            char    *name;
            ASTNode *body;
        } word;
    };
};


#endif
