#include <inttypes.h>
#include <stdlib.h>
#include <stdio.h>
#include "topple.h"


enum early_exit {
    EXITING,
    NORMAL_CONTROL,
};

#define DO(NODE) { if (run_ast(NODE, s) == EXITING) return EXITING; }


enum early_exit run_ast(const ASTNode *n, Stack *s)
{
    switch (n->kind) {

    case CONDITIONAL:
        if (truthy(stack_pop(s)))
            DO(n->conditional.if_true)
        else
            DO(n->conditional.if_false)
        break;

    case EXIT:
        return EXITING;

    case LITERAL:
        stack_push(s, val_of_num(n->number));
        break;

    case LOOP:
        while (true) {
            DO(n->loop.test)
            if (!truthy(stack_pop(s)))
                break;
            DO(n->loop.body)
        }
        break;

    case PRIMITIVE:
        n->primitive->action(s);
        break;

    case SEQUENCE:
        for (size_t i = 0; i < n->sequence.len; i++)
            DO(n->sequence.contents[i])
        break;

    case STRING:
        printf("%s", n->string);
        break;

    case VAR_GET:
        stack_push(s, var_get(n->variable));
        break;

    case VAR_SET:
        var_set(n->variable, stack_pop(s));
        break;

    case TYPE_CLOSE:
        stack_push(s, type_close(n->type, stack_pop(s)));
        break;

    case TYPE_OPEN:
        stack_push(s, type_open(n->type, stack_pop(s)));
        break;

    case WORD:
        run_ast(n->word.body, s); // catch EXITING
        break;

    }

    return NORMAL_CONTROL;
}



int main(void)
{
    ASTNode *main = parse_program();
    Stack *s = stack_new();
    run_ast(main, s);

    return 0;
}
