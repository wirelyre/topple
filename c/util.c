#include <inttypes.h>
#include <stdio.h>
#include "topple.h"


noreturn void fail(const char *s)
{
    fprintf(stderr, "%s\n", s);
    exit(127);
}


static int read_char()
{
    int c = getchar();
    if (c == EOF)  return c;
    if (c == '\n') return c;
    if (c < ' ' || c > '~') fail("illegal character");
    return c;
}

static char *read_string()
{
    char  *w = malloc(16);
    size_t len = 0;
    size_t cap = 16;
    int    c = read_char();
    w[len++] = '"';

    while (true) {
        if (len + 1 == cap) {
            cap += 16;
            w = realloc(w, cap);
        }
        switch (c) {
        case EOF: fail("unterminated string");
        case '"':
            w[len] = 0;
            return w;
        case '\\':
            switch (read_char()) {
            case '\\': w[len++] = '\\'; break;
            case 'n':  w[len++] = '\n'; break;
            default: fail("unknown escape");
            }
            break;
        default:
            w[len++] = c;
        }
        c = read_char();
    }
}

static char *read_word(char first)
{
    char  *w = malloc(16);
    size_t len = 0;
    size_t cap = 16;
    int    c = read_char();
    w[len++] = first;

    while (true) {
        if (len + 1 == cap) {
            cap += 16;
            w = realloc(w, cap);
        }
        switch (c) {
        case EOF:
        case ' ':
        case '\n':
            w[len] = 0;
            return w;
        case '"':  fail("quote character within word");
        case '\\': fail("backslash within word");
        default:
            w[len++] = c;
        }
        c = read_char();
    }
}

char *read_token()
{
    int c = read_char();
    while (c != EOF) {
        if (c == '\\') {
            while (c = read_char(), c != '\n' && c != EOF);
            continue;
        }
        if (c == ' ' || c == '\n') {
            c = read_char();
            continue;
        }

        if (c == '"')
            return read_string();
        else
            return read_word(c);
    }
    return NULL;
}


void dup(Value v)
{
    switch (v.type) {
    case UNDEFINED:
    case NUMBER:
        break;

    case BYTES:
        v.bytes->ref_count++;
        break;

    case POINTER:
        v.pointer.block->ref_count++;
        break;
    }
}


void discard(Value v)
{
    switch (v.type) {
    case UNDEFINED:
    case NUMBER:
        break;

    case BYTES:
        v.bytes->ref_count--;

        if (v.bytes->ref_count == 0) {
            free(v.bytes->contents);
            free(v.bytes);
        }

        break;

    case POINTER:
        v.pointer.block->ref_count--;

        if (v.pointer.block->ref_count == 0) {
            for (uint16_t i = 0; i < 400; i++)
                discard(v.pointer.block->cells[i]);
            free(v.pointer.block);
        }

        break;
    }
}


bool truthy(Value v)
{
    bool result = (v.type != NUMBER) || (v.number != 0);
    discard(v);
    return result;
}


uint64_t num_of_val(Value v)
{
    if (v.type != NUMBER)
        fail("type error: expected number");
    return v.number;
}

Value val_of_num(uint64_t n)
{
    Value v = { .type = NUMBER, .number = n };
    return v;
}

Value val_of_bool(bool b)
{
    return val_of_num(b ? UINT64_MAX : 0);
}

Value expect_bytes(Value v)
{
    if (v.type != BYTES)
        fail("type error: expected bytes");
    return v;
}

Value expect_pointer(Value v)
{
    if (v.type != POINTER)
        fail("type error: expected pointer");
    return v;
}


Stack *stack_new()
{
    Stack *s = malloc(sizeof(Stack));
    s->len = 0;
    return s;
}


void stack_push(Stack *s, Value v)
{
    if (s->len == 10000)
        fail("stack overflow");
    s->values[(s->len)++] = v;
}


Value stack_pop(Stack *s)
{
    if (s->len == 0)
        fail("stack underflow");
    return s->values[--(s->len)];
}


Value stack_pick(Stack *s, size_t p)
{
    if (s->len < p + 1)
        fail("stack underflow");
    Value v = s->values[s->len - p - 1];
    dup(v);
    return v;
}


static void print_spaces(size_t count)
{
    for (size_t i = 0; i < count; i++)
        printf("    ");
}
static void dump_ast_(ASTNode *n, size_t depth)
{
    switch (n->kind) {

    case CONDITIONAL:
        print_spaces(depth); printf("CONDITIONAL:\n");
        print_spaces(depth); printf("  if_true:\n");
        dump_ast_(n->conditional.if_true, depth + 1);
        print_spaces(depth); printf("  if_false:\n");
        dump_ast_(n->conditional.if_false, depth + 1);
        break;

    case LOOP:
        print_spaces(depth); printf("LOOP:\n");
        print_spaces(depth); printf("  test:\n");
        dump_ast_(n->loop.test, depth + 1);
        print_spaces(depth); printf("  body:\n");
        dump_ast_(n->loop.body, depth + 1);
        break;

    case LITERAL:
        print_spaces(depth); printf("LITERAL: %"PRIu64"\n", n->number);
        break;

    case PRIMITIVE:
        print_spaces(depth); printf("PRIMITIVE: %s\n", n->primitive->name);
        break;

    case SEQUENCE:
        print_spaces(depth); printf("SEQUENCE:\n");
        for (size_t i = 0; i < n->sequence.len; i++)
            dump_ast_(n->sequence.contents[i], depth + 1);
        break;

    case STRING:
        print_spaces(depth); printf("STRING: %s\n", n->string);
        break;

    case WORD:
        print_spaces(depth); printf("WORD: %s\n", n->word.name);
        break;

    }
}
void dump_ast(ASTNode *n) { dump_ast_(n, 0); }
