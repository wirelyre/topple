#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "topple.h"


void dump_code(void);


instruction   CODE[10000];
control_state CONTROL_STACK[100];
size_t        CODE_TOP = 0;
size_t        CONTROL_STACK_TOP = 0;

struct word {
    char        *name;
    size_t       code_pos;
    struct word *next;
} *WORDS = NULL;


ssize_t      find_control  (char *);
ssize_t      find_primitive(char *);
struct word *find_word     (char *);
bool         is_number     (char *);

void handle_number   (stack *, uint64_t);
void handle_primitive(stack *, size_t);
void handle_string   (char *);
void handle_word     (stack *, size_t);


int main(void)
{
    char *word;
    stack *s = stack_alloc();

    while ((word = read_word())) {
        dump_code();

        ssize_t i;

        if (is_number(word)) {
            uint64_t n = 0;
            for (size_t i = 0; word[i] != '\0'; i++) {
                uint64_t next = 10*n + (word[i] - '0');
                if (next < n)
                    fail("number literal too large");
                n = next;
            }
            handle_number(s, n);
            continue;
        }

        if (word[0] == '"') {
            handle_string(word);
            continue;
        }

        i = find_control(word);
        if (i != -1) {
            CONTROLS[i].action();
            continue;
        }

        i = find_primitive(word);
        if (i != -1) {
            handle_primitive(s, i);
            continue;
        }

        struct word *w = find_word(word);
        if (w != NULL) {
            handle_word(s, w->code_pos);
            continue;
        }

        fail("undefined word");
    }

    return 0;
}


void dump_code()
{
    for (size_t i = 0; i < CODE_TOP; i++) {
        switch (CODE[i].type) {
            case BRANCH:    printf("%3lu  BRANCH %lu", i, CODE[i].data); break;
            case CALL:      printf("%3lu  CALL   %lu", i, CODE[i].data); break;
            case JUMP:      printf("%3lu  JUMP   %lu", i, CODE[i].data); break;
            case LITERAL:   printf("%3lu  LITERAL %lu", i, CODE[i].data); break;
            case PRIMITIVE: printf("%3lu  PRIMITIVE", i); break;
            case RETURN:    printf("%3lu  RETURN", i); break;
            case STRING:    printf("%3lu  STRING \"%s\"", i, CODE[i].string); break;
        }
        printf("\n");
    }
    printf("\n");
}


ssize_t find_control(char *name)
{
    for (ssize_t i = 0; CONTROLS[i].name != NULL; i++)
        if (strcmp(CONTROLS[i].name, name) == 0)
            return i;
    return -1;
}
ssize_t find_primitive(char *name)
{
    for (ssize_t i = 0; PRIMITIVES[i].name != NULL; i++)
        if (strcmp(PRIMITIVES[i].name, name) == 0)
            return i;
    return -1;
}
struct word *find_word(char *name)
{
    for (struct word *w = WORDS; w != NULL; w = w->next)
        if (strcmp(w->name, name) == 0)
            return w;
    return NULL;
}
bool is_number(char *word)
{
    while (*word) {
        if (*word < '0' || *word > '9')
            return false;
        word++;
    }
    return true;
}


static void code_append(instruction i)
{
    if (CODE_TOP == 10000)
        fail("IMPLEMENTATION: too much code");
    CODE[CODE_TOP] = i;
    CODE_TOP++;
}
static void control_append(int kind)
{
    if (CONTROL_STACK_TOP == 100)
        fail("IMPLEMENTATION: too much nesting");
    CONTROL_STACK[CONTROL_STACK_TOP].kind = kind;
    CONTROL_STACK[CONTROL_STACK_TOP].pos = CODE_TOP;
    CONTROL_STACK_TOP++;
}


void handle_number(stack *s, uint64_t num)
{
    if (CONTROL_STACK_TOP != 0) {
        instruction i = { .type = LITERAL, .data = num };
        code_append(i);
    } else {
        value v = { .type = NUMBER, .num = num };
        stack_push(s, v);
    }
}


void handle_primitive(stack *s, size_t idx)
{
    if (CONTROL_STACK_TOP != 0) {
        instruction i = { .type = PRIMITIVE, .data = idx };
        code_append(i);
    } else {
        PRIMITIVES[idx].action(s);
    }
}


void handle_string(char *s)
{
    if (CONTROL_STACK_TOP != 0) {
        instruction i = { .type = STRING, .string = s + 1 };
        code_append(i);
    } else {
        printf("%s", s + 1);
        free(s);
    }
}


void handle_word(stack *s, size_t idx)
{
    if (CONTROL_STACK_TOP != 0) {
        instruction i = { .type = CALL, .data = idx };
        code_append(i);
    } else {

        size_t returns[100] = { idx };
        size_t return_top = 1;
        value v = { .type = NUMBER };

        while (return_top > 0) {
            instruction i = CODE[returns[return_top]];

            switch (i.type) {
                case BRANCH:
                    if (falsy(stack_pop(s))) {
                        returns[return_top] = i.data;
                        continue;
                    }
                    break;

                case CALL:
                    returns[return_top]++;
                    return_top++;
                    returns[return_top] = i.data;
                    continue;

                case JUMP:
                    returns[return_top] = i.data;
                    continue;

                case LITERAL:
                    v.num = i.data;
                    stack_push(s, v);
                    break;

                case PRIMITIVE:
                    PRIMITIVES[i.data].action(s);
                    break;

                case RETURN:
                    return_top--;
                    continue;

                case STRING:
                    printf("%s", i.string);
                    break;
            }

            returns[return_top]++;
        }

    }
}


static void colon_(void)
{
    if (CONTROL_STACK_TOP != 0)
        fail("colon within definition");

    struct word *new = malloc(sizeof(struct word));
    new->name = read_word();
    new->code_pos = CODE_TOP;
    new->next = WORDS;

    if (new->name == NULL)
        fail("expected name");
    if (find_control(new->name)          != -1
            || find_primitive(new->name) != -1
            || find_word(new->name)      != NULL)
        fail("duplicate name");

    WORDS = new;
    control_append(DEFINITION);
}


static void semicolon_(void)
{
    if (CONTROL_STACK_TOP == 0)
        fail("semicolon outside definition");
    if (CONTROL_STACK_TOP != 1)
        fail("unterminated control structure");
    instruction i = { .type = RETURN };
    code_append(i);
    CONTROL_STACK_TOP = 0;
}


static void if_(void)
{
    if (CONTROL_STACK_TOP == 0)
        fail("if outside definition");
    control_append(IF);
    instruction i = { .type = BRANCH };
    code_append(i);
}


static void else_(void)
{
    if (CONTROL_STACK_TOP == 0)
        fail("else outside definition");
    struct control_state *c = &CONTROL_STACK[CONTROL_STACK_TOP - 1];
    if (c->kind != IF)
        fail("else without matching if");
    CODE[c->pos].data = CODE_TOP + 1;
    instruction i = { .type = JUMP };
    code_append(i);
    c->kind = ELSE;
    c->pos = CODE_TOP - 1;
}


static void then_(void)
{
    if (CONTROL_STACK_TOP == 0)
        fail("then outside definition");
    struct control_state *c = &CONTROL_STACK[CONTROL_STACK_TOP - 1];
    if (c->kind != IF && c->kind != ELSE)
        fail("then without matching if or else");
    CODE[c->pos].data = CODE_TOP;
    CONTROL_STACK_TOP--;
}


static void begin_(void)
{
    if (CONTROL_STACK_TOP == 0)
        fail("begin outside definition");
    control_append(BEGIN);
}


static void while_(void)
{
    if (CONTROL_STACK_TOP == 0)
        fail("while outside definition");
    struct control_state *c = &CONTROL_STACK[CONTROL_STACK_TOP - 1];
    if (c->kind != BEGIN)
        fail("while without matching begin");
    control_append(WHILE);
    instruction i = { .type = BRANCH };
    code_append(i);
}


static void repeat_(void)
{
    if (CONTROL_STACK_TOP == 0)
        fail("repeat outside definition");
    struct control_state *c = &CONTROL_STACK[CONTROL_STACK_TOP - 1];
    if (c->kind != WHILE)
        fail("repeat without matching while");
    instruction i = { .type = JUMP, .data = c[-1].pos };
    code_append(i);
    CODE[c[0].pos].data = CODE_TOP;
    CONTROL_STACK_TOP -= 2;
}


const control CONTROLS[] = {
    { .name = ":",      .action = colon_     },
    { .name = ";",      .action = semicolon_ },
    { .name = "if",     .action = if_        },
    { .name = "else",   .action = else_      },
    { .name = "then",   .action = then_      },
    { .name = "begin",  .action = begin_     },
    { .name = "while",  .action = while_     },
    { .name = "repeat", .action = repeat_    },
    { .name = NULL },
};
