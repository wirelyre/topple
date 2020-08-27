#include <inttypes.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include "topple.h"


noreturn void fail(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);

    fprintf(stderr, "\n");
    exit(127);
}


char *str_concat(char *a, char *b)
{
    size_t len_a = strlen(a);
    size_t len_b = strlen(b);
    char *c = malloc(len_a + len_b + 1);

    memcpy(c, a, len_a);
    memcpy(c + len_a, b, len_b);

    c[len_a + len_b] = '\0';
    return c;
}


void bytes_append(Bytes *b, uint64_t c)
{
    if (b->len == b->cap) {
        b->cap *= 2;
        b->contents = realloc(b->contents, b->cap);
    }

    b->contents[b->len] = c % 256;
    b->len++;
}


Value *prepare_argv(int argc, const char **argv)
{
    Bytes *b = malloc(sizeof(Bytes));
    b->ref_count = 1;
    b->len = 0;
    b->cap = 16;
    b->contents = malloc(16);

    for (int i = 1; i < argc; i++) {
        for (int j = 0; argv[i][j] != '\0'; j++) {
            bytes_append(b, argv[i][j]);
        }

        bytes_append(b, 0);
    }

    Value *v = malloc(sizeof(Value));
    v->type = BYTES;
    v->bytes = b;
    return v;
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
            case '"':  w[len++] = '"';  break;
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
    default:
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
    default:
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


Value var_get(Value *var)
{
    if (var->type == UNDEFINED)
        fail("read of undefined value");
    dup(*var);
    return *var;
}

void var_set(Value *var, Value v)
{
    discard(*var);
    *var = v;
}


Value type_close(Type t, Value v)
{
    if (v.type != POINTER)
        fail("type error: expected pointer");
    v.type = t.id;
    return v;
}

Value type_open(Type t, Value v)
{
    if (v.type != t.id)
        fail("type error: expected '%s'", t.name);
    v.type = POINTER;
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

    case EXIT:
        print_spaces(depth); printf("EXIT\n");
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

    case VAR_GET:
        print_spaces(depth); printf("VAR_GET: %p\n", n->variable);
        break;

    case VAR_SET:
        print_spaces(depth); printf("VAR_SET: %p\n", n->variable);
        break;

    case TYPE_OPEN:
        print_spaces(depth); printf("TYPE_OPEN: %s\n", n->type.name);
        break;

    case TYPE_CLOSE:
        print_spaces(depth); printf("TYPE_CLOSE: %s\n", n->type.name);
        break;

    case WORD:
        print_spaces(depth); printf("WORD: %s\n", n->word.name);
        break;

    }
}
void dump_ast(ASTNode *n) { dump_ast_(n, 0); }
