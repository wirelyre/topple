#include <string.h>
#include "topple.h"


typedef struct dictionary {
    ASTNode           *node;
    struct dictionary *next;
} Dict;


enum keyword {
    NOT_KEYWORD,
    KW_COLON,
    KW_SEMICOLON,
    KW_IF,
    KW_ELSE,
    KW_THEN,
    KW_BEGIN,
    KW_WHILE,
    KW_REPEAT,
};
static enum keyword classify_token(char *);


static Dict    *dict_append(      Dict *,       char *);
static ASTNode *dict_find  (const Dict *, const char *);
static void     dict_free  (      Dict *);

static ASTNode *sequence_new   (void);
static ASTNode *sequence_append(ASTNode *, ASTNode *);

static ASTNode *parse_def (const Dict *);
static ASTNode *parse_cond(const Dict *);
static ASTNode *parse_loop(const Dict *);
static ASTNode *parse_non_keyword(const Dict *, char *);


ASTNode *parse_program()
{
    ASTNode *main = sequence_new();
    ASTNode *n;
    Dict *d = NULL;

    char *token;
    while (token = read_token(), token != NULL) {
        switch (classify_token(token)) {

        case NOT_KEYWORD:
            n = parse_non_keyword(d, token);
            main = sequence_append(main, n);
            break;

        case KW_COLON:
            d = dict_append(d, read_token());
            d->node->word.body = parse_def(d);
            break;

        case KW_SEMICOLON:
        case KW_IF:
        case KW_ELSE:
        case KW_THEN:
        case KW_BEGIN:
        case KW_WHILE:
        case KW_REPEAT:
            fail("unexpected keyword");

        }

    }

    dict_free(d);
    return main;
}


static ASTNode *parse_def(const Dict *d)
{
    ASTNode *seq = sequence_new();
    ASTNode *n;

    while(true) {
        char *token = read_token();
        if (!token) fail("unexpected EOF");

        switch (classify_token(token)) {
        case NOT_KEYWORD:
            n = parse_non_keyword(d, token);
            break;

        case KW_IF:    n = parse_cond(d); break;
        case KW_BEGIN: n = parse_loop(d); break;

        case KW_SEMICOLON:
            return seq;

        default:
            fail("unexpected keyword");
        }

        seq = sequence_append(seq, n);
    }
}


static ASTNode *parse_cond(const Dict *d)
{
    ASTNode *if_true  = sequence_new();
    ASTNode *if_false = sequence_new();
    ASTNode *n;
    bool in_true = true;

    while (true) {
        char *token = read_token();
        if (!token) fail("unexpected EOF");

        switch (classify_token(token)) {
        case NOT_KEYWORD:
            n = parse_non_keyword(d, token);
            break;

        case KW_IF:    n = parse_cond(d); break;
        case KW_BEGIN: n = parse_loop(d); break;

        case KW_ELSE:
            if (!in_true)
                fail("unexpected keyword");
            in_true = false;
            continue;

        case KW_THEN:
            n = malloc(sizeof(ASTNode));
            n->kind = CONDITIONAL;
            n->conditional.if_true = if_true;
            n->conditional.if_false = if_false;
            return n;

        default:
            fail("unexpected keyword");
        }

        if (in_true)
            if_true = sequence_append(if_true, n);
        else
            if_false = sequence_append(if_false, n);
    }
}


static ASTNode *parse_loop(const Dict *d)
{
    ASTNode *test = sequence_new();
    ASTNode *body = sequence_new();
    ASTNode *n;
    bool in_test = true;

    while (true) {
        char *token = read_token();
        if (!token) fail("unexpected EOF");

        switch (classify_token(token)) {
        case NOT_KEYWORD:
            n = parse_non_keyword(d, token);
            break;

        case KW_IF:    n = parse_cond(d); break;
        case KW_BEGIN: n = parse_loop(d); break;

        case KW_WHILE:
            if (!in_test)
                fail("unexpected keyword");
            in_test = false;
            continue;

        case KW_REPEAT:
            if (in_test)
                fail("unexpected keyword");
            n = malloc(sizeof(ASTNode));
            n->kind = LOOP;
            n->loop.test = test;
            n->loop.body = body;
            return n;

        default:
            fail("unexpected keyword");
        }

        if (in_test)
            test = sequence_append(test, n);
        else
            body = sequence_append(body, n);
    }
}


static ASTNode *parse_non_keyword(const Dict *d, char *token)
{
    ASTNode *a = malloc(sizeof(ASTNode));

    if (token[0] == '"') {
        a->kind = STRING;
        a->string = token + 1;
        return a;
    }

    Primitive *p = find_primitive(token);
    if (p) {
        free(token);
        a->kind = PRIMITIVE;
        a->primitive = p;
        return a;
    }

    ASTNode *w = dict_find(d, token);
    if (w) {
        free(token);
        free(a);
        return w;
    }

    size_t i;
    uint64_t n = 0;
    uint64_t m;

    for (i = 0; token[i] != '\0'; i++) {
        if (token[i] < '0' || '9' < token[i])
            fail("unknown word");
    }

    for (i = 0; token[i] != '\0'; i++) {
        m = 10*n + (token[i] - '0');
        if (m < n)
            fail("number literal too large");
        n = m;
    }
    free(token);
    a->kind = LITERAL;
    a->number = n;
    return a;
}


static enum keyword classify_token(char *token)
{
    enum keyword k = NOT_KEYWORD;
    if (strcmp(token, ":"     ) == 0) k = KW_COLON;
    if (strcmp(token, ";"     ) == 0) k = KW_SEMICOLON;
    if (strcmp(token, "if"    ) == 0) k = KW_IF;
    if (strcmp(token, "else"  ) == 0) k = KW_ELSE;
    if (strcmp(token, "then"  ) == 0) k = KW_THEN;
    if (strcmp(token, "begin" ) == 0) k = KW_BEGIN;
    if (strcmp(token, "while" ) == 0) k = KW_WHILE;
    if (strcmp(token, "repeat") == 0) k = KW_REPEAT;

    if (k != NOT_KEYWORD)
        free(token);

    return k;
}


static Dict *dict_append(Dict *d, char *name)
{
    if (find_primitive(name) || dict_find(d, name))
        fail("duplicate word");
    Dict *new = malloc(sizeof(Dict));
    new->next = d;

    new->node = malloc(sizeof(ASTNode));
    new->node->kind = WORD;
    new->node->word.name = name;

    return new;
}


static void dict_free(Dict *d)
{
    while (d) {
        Dict *next = d->next;
        free(d);
        d = next;
    }
}


static ASTNode *dict_find(const Dict *d, const char *name)
{
    while (d) {
        if (strcmp(d->node->word.name, name) == 0)
            return d->node;
        d = d->next;
    }
    return NULL;
}


static ASTNode *sequence_new()
{
    ASTNode *seq = malloc(sizeof(ASTNode) + 16*sizeof(ASTNode *));
    seq->kind = SEQUENCE;
    seq->sequence.len = 0;
    seq->sequence.cap = 16;
    return seq;
}


static ASTNode *sequence_append(ASTNode *seq, ASTNode *n)
{
    if (seq->sequence.len == seq->sequence.cap) {
        seq->sequence.cap *= 2;
        seq = realloc(seq, sizeof(ASTNode) + (seq->sequence.cap)*sizeof(ASTNode *));
    }
    seq->sequence.contents[(seq->sequence.len)++] = n;
    return seq;
}
