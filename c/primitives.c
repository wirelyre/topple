#include <inttypes.h>
#include <stdio.h>
#include <string.h>
#include "topple.h"


static Primitive primitives[];

Primitive *find_primitive(const char *name)
{
    for (size_t i = 0; primitives[i].name != NULL; i++) {
        if (strcmp(name, primitives[i].name) == 0)
            return &primitives[i];
    }
    return NULL;
}


#define ARITH(NAME, EXPR)                      \
    static void NAME(Stack *s) {               \
        uint64_t r = num_of_val(stack_pop(s)); \
        uint64_t l = num_of_val(stack_pop(s)); \
        stack_push(s, val_of_num(EXPR));       \
    }
ARITH(add_, l + r)
ARITH(sub_, l - r)
ARITH(mul_, l * r)
// ARITH(div_, l / r)   -- need to check that (r != 0)
ARITH(shl_, l << (r % 64))
ARITH(shr_, l >> (r % 64))
#undef ARITH

static void div_(Stack *s)
{
    uint64_t r = num_of_val(stack_pop(s));
    uint64_t l = num_of_val(stack_pop(s));
    if (r == 0)
        fail("division by zero");
    stack_push(s, val_of_num(l / r));
}


static void dup_(Stack *s)
{
    Value v = stack_pop(s);
    dup(v);
    stack_push(s, v);
    stack_push(s, v);
}


static void drop_(Stack *s)
{
    discard(stack_pop(s));
}


static void swap_(Stack *s)
{
    Value v1 = stack_pop(s);
    Value v0 = stack_pop(s);
    stack_push(s, v1);
    stack_push(s, v0);
}


static void nip_(Stack *s)
{
    Value v = stack_pop(s);
    drop_(s);
    stack_push(s, v);
}


static void tuck_(Stack *s)
{
    Value v1 = stack_pop(s); dup(v1);
    Value v0 = stack_pop(s);
    stack_push(s, v1);
    stack_push(s, v0);
    stack_push(s, v1);
}


static void rot_(Stack *s)
{
    Value v2 = stack_pop(s);
    Value v1 = stack_pop(s);
    Value v0 = stack_pop(s);
    stack_push(s, v1);
    stack_push(s, v2);
    stack_push(s, v0);
}


static void unrot_(Stack *s)
{
    Value v2 = stack_pop(s);
    Value v1 = stack_pop(s);
    Value v0 = stack_pop(s);
    stack_push(s, v2);
    stack_push(s, v0);
    stack_push(s, v1);
}


static void pick_(Stack *s)
{
    uint64_t n = num_of_val(stack_pop(s));
    Value v = stack_pick(s, n);
    stack_push(s, v);
}


static void dot_(Stack *s)
{
    printf("%"PRIu64" ", num_of_val(stack_pop(s)));
}


static Primitive primitives[] = {
    { .name = "+",    .action = add_   },
    { .name = "-",    .action = sub_   },
    { .name = "*",    .action = mul_   },
    { .name = "/",    .action = div_   },
    { .name = "<<",   .action = shl_   },
    { .name = ">>",   .action = shr_   },
    { .name = "dup",  .action = dup_   },
    { .name = "drop", .action = drop_  },
    { .name = "swap", .action = swap_  },
    { .name = "nip",  .action = nip_   },
    { .name = "tuck", .action = tuck_  },
    { .name = "rot",  .action = rot_   },
    { .name = "-rot", .action = unrot_ },
    { .name = "pick", .action = pick_  },
    { .name = ".",    .action = dot_   },
    { .name = NULL },
};
