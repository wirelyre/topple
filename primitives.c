#include <stdio.h>
#include "topple.h"


#define EXPECT_NUM(V) if (V.type != NUMBER) fail("type error: expected number");
#define POP_NUM(V, S) value V = stack_pop(S); EXPECT_NUM(V)


#define ARITH(NAME, EXPR)                            \
    static void NAME(stack *s) {                     \
        POP_NUM(v1, s)                               \
        POP_NUM(v0, s)                               \
        uint64_t l = v0.num;                         \
        uint64_t r = v1.num;                         \
        value v = { .type = NUMBER, .num = (EXPR) }; \
        stack_push(s, v);                            \
    }
ARITH(add, l + r)
ARITH(sub, l - r)
ARITH(mul, l * r)
// ARITH(div, l / r): need to check for 0 divisor
ARITH(shl, l << (r % 64))
ARITH(shr, l >> (r % 64))
#undef ARITH

static void div(stack *s)
{
    POP_NUM(r, s);
    POP_NUM(l, s);
    if (r.num == 0) fail("division by 0");
    value v = { .type = NUMBER, .num = l.num / r.num };
    stack_push(s, v);
}


static void print(stack *s)
{
    POP_NUM(v, s);
    printf("%"PRIu64" ", v.num);
}


static void dup(stack *s)
{
    value v = stack_pop(s);
    stack_push(s, duplicate(v));
    stack_push(s, v);
}


const struct primitive PRIMITIVES[] = {
    { .name = "+",   .action = add   },
    { .name = "-",   .action = sub   },
    { .name = "*",   .action = mul   },
    { .name = "/",   .action = div   },
    { .name = "<<",  .action = shl   },
    { .name = ">>",  .action = shr   },
    { .name = ".",   .action = print },
    { .name = "dup", .action = dup   },
    { .name = NULL },
};
