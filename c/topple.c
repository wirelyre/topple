#include <inttypes.h>
#include <stdlib.h>
#include <stdio.h>
#include "topple.h"


void run_ast(const ASTNode *n, Stack *s)
{
    switch (n->kind) {

    case CONDITIONAL:
        if (truthy(stack_pop(s)))
            run_ast(n->conditional.if_true, s);
        else
            run_ast(n->conditional.if_false, s);
        break;

    case LITERAL:
        stack_push(s, val_of_num(n->number));
        break;

    case LOOP:
        while (true) {
            run_ast(n->loop.test, s);
            if (!truthy(stack_pop(s)))
                break;
            run_ast(n->loop.body, s);
        }
        break;

    case PRIMITIVE:
        n->primitive->action(s);
        break;

    case SEQUENCE:
        for (size_t i = 0; i < n->sequence.len; i++)
            run_ast(n->sequence.contents[i], s);
        break;

    case STRING:
        printf("%s", n->string);
        break;

    case TYPE_CLOSE:
        stack_push(s, type_close(n->type, stack_pop(s)));
        break;

    case TYPE_OPEN:
        stack_push(s, type_open(n->type, stack_pop(s)));
        break;

    case WORD:
        run_ast(n->word.body, s);
        break;

    }
}



int main(void)
{
    ASTNode *main = parse_program();
    Stack *s = stack_new();
    run_ast(main, s);

    return 0;
}
