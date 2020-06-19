#include <stdlib.h>
#include <stdio.h>
#include "topple.h"


static char *read_string();


noreturn void fail(const char *c)
{
    fprintf(stderr, "%s\n", c);
    exit(127);
}


value duplicate(value v)
{
    switch (v.type) {
        case EMPTY:  return v;
        case NUMBER: return v;

        case POINTER:
            v.ptr->ref_count++;
            return v;

        case BYTES:
            v.bytes->ref_count++;
            return v;
    }
}


void discard(value v)
{
    switch (v.type) {
        case EMPTY:  return;
        case NUMBER: return;

        case POINTER: ;
            block *block = v.ptr;
            block->ref_count--;

            if (block->ref_count == 0) {
                block_clear(block);
                free(block);
            }

            return;

        case BYTES: ;
            bytes *bytes = v.bytes;
            bytes->ref_count--;

            if (bytes->ref_count == 0) {
                free(bytes->contents);
                free(bytes);
            }

            return;
    }
}


void block_clear(block *b)
{
    for (int i = 0; i < 400; i++) {
        discard(b->values[i]);
        b->values[i].type = EMPTY;
    }
}


bool falsy(value v)
{
    return (v.type == NUMBER) && (v.num == 0);
}


struct stack {
    uint64_t length;
    value    values[1000];
};


stack *stack_alloc(void)
{
    return malloc(sizeof(stack));
}


void stack_push(stack *s, value v)
{
    if (s->length >= 1000) {
        fail("stack overflow");
    }

    s->values[s->length] = v;
    s->length++;
}


value stack_pop(stack *s)
{
    if (s->length == 0) {
        fail("stack underflow");
    }

    s->length--;
    return s->values[s->length];
}


static int readchar()
{
    int c = getchar();
    if (c == EOF)             return c;
    if (c == '\n')            return c;
    if (' ' <= c && c <= '~') return c;
    fail("unprintable character");
}

char *read_word()
{
    int c = getchar();

    while (true) {
        switch (c) {
            case EOF:
                return NULL;

            case ' ':
            case '\n':
                c = getchar();
                continue;

            case '\\':
                while (c != '\n' && c != EOF)
                    c = getchar();
                continue;

            case '"':
                return read_string();
        }

        break;
    }

    char *word = malloc(16);
    unsigned len = 0;
    unsigned cap = 16;

    while (true) {
        switch (c) {
            case EOF:
            case ' ':
            case '\n':
                word[len] = 0;
                return word;

            case '\\':
            case '"':
                fail("illegal character within word");
        }

        if (len + 1 == cap) {
            cap += 16;
            word = realloc(word, cap);
        }

        word[len] = c;
        len++;

        c = getchar();
    }
}


static char *read_string()
{
    char *word = malloc(16);
    unsigned len = 1;
    unsigned cap = 16;
    word[0] = '"';

    int c = getchar();

    while (true) {
        if (len + 1 == cap) {
            cap += 16;
            word = realloc(word, 16);
        }

        switch (c) {
            case EOF:
                fail("unterminated string");

            case '\n':
                fail("illegal newline in string");

            case '"':
                word[len] = 0;
                return word;

            case '\\':
                switch (getchar()) {
                    case '\\': c = '\\'; break;
                    case 'n':  c = '\n'; break;
                    default: fail("unknown escape in string");
                }
        }

        word[len] = c;
        len++;

        c = getchar();
    }
}
