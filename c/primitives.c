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


#define BINARY(NAME, EXPR)                     \
    static void NAME(Stack *s) {               \
        uint64_t r = num_of_val(stack_pop(s)); \
        uint64_t l = num_of_val(stack_pop(s)); \
        stack_push(s, (EXPR));                 \
    }
#define ARITH(NAME, EXPR) BINARY(NAME, val_of_num(EXPR))
#define COMP(NAME, EXPR) BINARY(NAME, val_of_bool(EXPR))

ARITH(add_, l + r)
ARITH(sub_, l - r)
ARITH(mul_, l * r)
// ARITH(div_, l / r)   -- need to check that (r != 0)
ARITH(shl_, l << (r % 64))
ARITH(shr_, l >> (r % 64))

COMP(eq_, l == r)
COMP(ne_, l != r)
COMP(lt_, l <  r)
COMP(gt_, l >  r)
COMP(le_, l <= r)
COMP(ge_, l >= r)

static void div_(Stack *s)
{
    uint64_t r = num_of_val(stack_pop(s));
    uint64_t l = num_of_val(stack_pop(s));
    if (r == 0)
        fail("division by zero");
    stack_push(s, val_of_num(l / r));
}

#undef COMP
#undef ARITH
#undef BINARY


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


static void over_(Stack *s)
{
    Value v1 = stack_pop(s);
    Value v0 = stack_pop(s); dup(v0);
    stack_push(s, v0);
    stack_push(s, v1);
    stack_push(s, v0);
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


static void putc_(Stack *s)
{
    uint64_t c = num_of_val(stack_pop(s));

    if (c < ' ' || c > '~')
        if (c != '\n')
            fail("illegal character");

    printf("%c", (int) c);
}


static void bytes_new_(Stack *s)
{
    Bytes *b = malloc(sizeof(Bytes));
    b->ref_count = 1;
    b->len = 0;
    b->cap = 16;
    b->contents = malloc(16);

    Value v = { .type = BYTES, .bytes = b };
    stack_push(s, v);
}


static void bytes_clear_(Stack *s)
{
    Value b = expect_bytes(stack_pop(s));
    b.bytes->len = 0;
    discard(b);
}


static void bytes_length_(Stack *s)
{
    Value b = expect_bytes(stack_pop(s));
    stack_push(s, val_of_num(b.bytes->len));
    discard(b);
}


static void bytes_push_(Stack *s)
{
    Value b = expect_bytes(stack_pop(s));
    uint64_t c = num_of_val(stack_pop(s));

    if (b.bytes->len == b.bytes->cap) {
        b.bytes->cap *= 2;
        b.bytes = realloc(b.bytes, b.bytes->cap);
    }

    b.bytes->contents[b.bytes->len++] = c % 256;
    discard(b);
}


static void bytes_get_(Stack *s)
{
    Value b = expect_bytes(stack_pop(s));
    uint64_t idx = num_of_val(stack_pop(s));

    if (idx >= b.bytes->len)
        fail("bytes index out of bounds");
    stack_push(s, val_of_num(b.bytes->contents[idx]));
    discard(b);
}


static void bytes_set_(Stack *s)
{
    Value b = expect_bytes(stack_pop(s));
    uint64_t idx = num_of_val(stack_pop(s));
    uint64_t c = num_of_val(stack_pop(s));

    if (idx >= b.bytes->len)
        fail("bytes index out of bounds");
    b.bytes->contents[idx] = c % 256;
    discard(b);
}


static void file_read_(Stack *s)
{
    Value b = expect_bytes(stack_pop(s));
    char *filename = malloc(b.bytes->len + 1);
    memcpy(filename, b.bytes->contents, b.bytes->len);
    filename[b.bytes->len] = '\0';

    FILE *f = fopen(filename, "rb");
    free(filename);
    discard(b);

    if (f == NULL) {
        stack_push(s, val_of_num(0));
        return;
    }

    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);

    if (size < 0)
        fail("io error");

    b.type = BYTES;
    b.bytes = malloc(sizeof(Bytes));
    b.bytes->ref_count = 1;
    b.bytes->len = 0;
    b.bytes->cap = size;
    b.bytes->contents = malloc(size);

    unsigned char *buf = b.bytes->contents;
    size_t remaining = size;
    size_t just_read;
    while ((just_read = fread(buf, 1, remaining, f)) > 0) {
        buf += just_read;
        remaining -= just_read;
    }
    b.bytes->len = size - remaining;

    stack_push(s, b);
}


static void block_new_(Stack *s)
{
    Block *b = malloc(sizeof(Block));
    b->ref_count = 1;

    for (uint16_t i = 0; i < 400; i++)
        b->cells[i].type = UNDEFINED;

    Value v;
    v.type = POINTER;
    v.pointer.block = b;
    v.pointer.cell = 0;

    stack_push(s, v);
}


static void pointer_get_(Stack *s)
{
    Value p = expect_pointer(stack_pop(s));
    stack_push(s, var_get(&p.pointer.block->cells[p.pointer.cell]));
    discard(p);
}


static void pointer_set_(Stack *s)
{
    Value p = expect_pointer(stack_pop(s));
    Value v = stack_pop(s);
    var_set(&p.pointer.block->cells[p.pointer.cell], v);
    discard(p);
}


static void pointer_offset_(Stack *s)
{
    uint64_t offset = num_of_val(stack_pop(s));
    Value p = expect_pointer(stack_pop(s));

    offset += (uint64_t) p.pointer.cell;

    if (offset >= 400)
        fail("pointer offset out of bounds");

    p.pointer.cell = offset;
    stack_push(s, p);
}


static Primitive primitives[] = {
    { .name = "+",    .action = add_   },
    { .name = "-",    .action = sub_   },
    { .name = "*",    .action = mul_   },
    { .name = "/",    .action = div_   },
    { .name = "<<",   .action = shl_   },
    { .name = ">>",   .action = shr_   },

    { .name = "=",    .action = eq_    },
    { .name = "<>",   .action = ne_    },
    { .name = "<",    .action = lt_    },
    { .name = ">",    .action = gt_    },
    { .name = "<=",   .action = le_    },
    { .name = ">=",   .action = ge_    },

    { .name = "dup",  .action = dup_   },
    { .name = "drop", .action = drop_  },
    { .name = "swap", .action = swap_  },
    { .name = "nip",  .action = nip_   },
    { .name = "tuck", .action = tuck_  },
    { .name = "over", .action = over_  },
    { .name = "rot",  .action = rot_   },
    { .name = "-rot", .action = unrot_ },
    { .name = "pick", .action = pick_  },

    { .name = ".",    .action = dot_   },
    { .name = "putc", .action = putc_  },

    { .name = "bytes.new",    .action = bytes_new_      },
    { .name = "bytes.clear",  .action = bytes_clear_    },
    { .name = "bytes.length", .action = bytes_length_   },
    { .name = "b%",           .action = bytes_push_     },
    { .name = "b@",           .action = bytes_get_      },
    { .name = "b!",           .action = bytes_set_      },

    { .name = "file.read",    .action = file_read_      },

    { .name = "block.new",    .action = block_new_      },
    { .name = "@",            .action = pointer_get_    },
    { .name = "!",            .action = pointer_set_    },
    { .name = "+p",           .action = pointer_offset_ },

    { .name = NULL },
};
