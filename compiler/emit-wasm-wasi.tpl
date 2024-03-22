\ TODO: factor out iovec initialization
\ TODO: write more exhaustive tests for blocks and bytes
\ TODO: exercise all errors, check text
\ TODO: proofread/format code one more time




\ emit-wasm-wasi.tpl
\
\ Implementation of 'emit' interface that produces WebAssembly modules.
\
\ This is pretty similar to the RISC-V emitter but better documented and easier
\ to disassemble and debug.
\
\ There are no padding bytes.  The notation
\    [field1]:1 [field2]:4
\ represents a structure that is exactly 5 bytes.
\
\
\
\ # ABI
\
\ Values are stored in memory as:  [data]:8 [type]:2
\ And on the Wasm stack as:        [i64 i32]
\
\ Types are represented as:
\    0 - uninitialized memory  (never occurs on stack)
\    1 - pointer
\    2 - number
\    3 - byte array
\    4-65535 - user types
\
\ The stack pointer is a global i32.
\ The type of user-defined words is [] -> [] (no params, no results).
\
\
\
\ # Memory map
\
\      0 -     31 - scratch
\     32 - 100031 - stack
\ 100032 - 100099 - free byte buffers
\ 100100 - ?????? - compile-time allocations (strings, constants, variables)
\ ?????? -        - run-time allocations
\
\ The stack grows downward.
\ The stack pointer points directly to the top of the stack.
\ This loads the top of the stack, if it exists:
\    global.get $sp
\    i64.load offset=0
\
\
\
\ # Module format
\
\ -  header
\ -  types (of functions)
\ -  imports (WASI)
\ - *functions (list of functions)
\ -  memories
\ -  globals
\ -  exports
\ -  data count
\ - *code (function bodies)
\ - *data (strings, constants, variables)
\
\ Only the *starred sections vary based on the input program.
\
\
\
\ # Blocks
\
\ Blocks are 4096-byte aligned.
\ They are never deallocated.
\ They have space for 400 values (10 bytes each).
\ We don't need to mark new allocations as uninitialized, because they're
\    already full of zeroes (type 0 => uninitialized).
\
\
\
\ # Byte arrays
\
\    value:     [&pointer]:8 [3]:2
\    pointer:   [&buffer]:4
\    buffer:    [size_class]:1 [length]:4 [data]:capacity
\
\ Byte arrays allocate new buffers as needed.
\ They have a stable address which points to the current buffer.
\
\ The 'size_class' field represents the size of the buffer:
\    capacity + 5 == 2 << (size_class + 16)
\
\ The minimum buffer allocation is one WebAssembly page, or 64 KiB, where:
\    size_class == 0
\
\ Free buffers are stored in linked lists at address 100032.
\ In the free lists, the 'length' field is repurposed as the 'next' pointer.
\ There are 16 lists, one for each possible buffer size.
\
\ (There's actually space for 17 lists to ensure a trap at 4 GiB.
\  I'm pretty sure it can't even get to 2 GiB but I don't want to figure it out.
\  Plus, it puts the data segment at address 100100, which I like.)
\
\
\
\ # Imports and runtime functions
\
\ ## Imports
\
\    wasi.args_get            [i32,i32]->[i32]
\    wasi.args_sizes_get      [i32,i32]->[i32]
\    wasi.fd_close            [i32]->[i32]
\    wasi.fd_prestat_dir_name [i32,i32,i32]->[i32]
\    wasi.fd_read             [i32,i32,i32,i32]->[i32]
\    wasi.fd_seek             [i32,i64,i32,i32]->[i32]
\    wasi.fd_write            [i32,i32,i32,i32]->[i32]
\    wasi.path_open           [i32,i32,i32,i32,i32,i64,i64,i32,i32]->[i32]
\    wasi.proc_exit           [i32]->[]
\
\    These are imports from wasi_snapshot_preview1.
\    See: https://github.com/WebAssembly/WASI/blob/main/legacy/preview1/docs.md
\    See: https://wasix.org/docs/api-reference
\
\    Except for 'proc_exit', they return 0 on success or else some error number.
\    Most take pointer parameters where they store results on success.
\
\ ## Runtime
\
\    rt.write         [addr:i32, len:i32] -> []
\    rt.error         [addr:i32, len:i32] -> []
\    object.error <- compiler utility to fail with an error inline
\
\    rt.load.stack    [offset:i64] -> [value:i64, type:i32]   (bounds check)
\    rt.store.stack   [value:i64, type:i32, offset:i32] -> []
\    rt.load.mem      [ptr:i32] -> [value:i64, type:i32]      (initialized check)
\    rt.store.mem     [ptr:i32, value:i64, type:i32] -> []
\
\    rt.push          [value:i64, type:i32] -> []   (overflow check)
\    rt.push.num      [num:i64] -> []
\    rt.push.bool     [bool:i32] -> []              (pushes 0/nonzero:i32 as 0/-1:i64)
\    rt.pop           [] -> [value:i64, type:i32]   (underflow check)
\    rt.pop.ptr       [] -> [ptr:i32]
\    rt.pop.num       [] -> [num:i64]
\    rt.pop.bool      [] -> [bool:i32]
\    rt.pop.bytes     [] -> [bytes:i32]
\    rt.pop.user      [type:i32] -> [value:i64]     (checks for correct type)
\
\    rt.alloc.pages   [count:i32] -> [addr:i32]
\    rt.alloc.block   [] -> [ptr:i32]
\    rt.alloc.buffer  [size_class:i32] -> [buf:i32]
\    rt.alloc.bytes   [size_class:i32] -> [bytes:i32]
\    rt.free.buffer   [buf:i32] -> []
\    rt.bytes.size-class-for-capacity [capacity:i32] -> [size_class:i32]
\    rt.buffer-offset [buf:i32, off:i64] -> [byte_ptr:i32]   (bounds check)
\    rt.bytes-push    [bytes:i32, byte:i64] -> []            (might reallocate)
\
\    rt.file.cwd      [] -> [fd:i32]
\    rt.file.open     [parent_fd:i32, o_flags:i32, fd_rights:i64] -> [fd:i32]
\    rt.file.len      [fd:i32] -> [len:i32]



\ The object file has several sections open at once.
\ Once each section is complete, it is copied into its parent.
\ This is necessary because you need to know its byte length to encode it.

bytes.new constant object.output
  bytes.new constant object.sec.func
  bytes.new constant object.sec.code
    bytes.new constant object.sec.tmp    \ buffer for active function
    bytes.new constant object.sec.main   \ top-level code, emitted as final function
  bytes.new constant object.sec.data

variable object.func-count   0 object.func-count!

: object.func        object.func-count@ dup 1 + object.func-count! ;
: object.data-addr   object.sec.data bytes.length 100100 + ;
: object.append
  2dup bytes.length b%u drop   \ length-prefixed data
  2dup bytes.append drop
  bytes.clear
;



\ WebAssembly instructions
\
\ This is the entire assembler!

\ control instructions (block types fixed as []->[])
: s.unreachable          0 b%1          ;
: s.nop                  1 b%1          ;
: s.block                2 b%1 64   b%1 ;
: s.loop                 3 b%1 64   b%1 ;
: s.if                   4 b%1 64   b%1 ;
: s.else                 5 b%1          ;
: s.end                 11 b%1          ;
: s.br             swap 12 b%1 swap b%u ;
: s.br_if          swap 13 b%1 swap b%u ;
: s.br_table            14 b%1          ;
: s.return              15 b%1          ;
: s.call           swap 16 b%1 swap b%u ;
: s.call_indirect   rot 17 b%1 rot  b%u swap b%u ;

\ reference instructions
: s.ref.null   swap 208 b%1 swap b%u ;
: s.ref.is_null     209 b%1          ;
: s.ref.func   swap 210 b%1 swap b%u ;

\ parametric instructions
: s.drop      26 b%1 ;
: s.select    27 b%1 ;
: s.select'   28 b%1 ;

\ variable instructions
: s.local.get    swap 32 b%1 swap b%u ;
: s.local.set    swap 33 b%1 swap b%u ;
: s.local.tee    swap 34 b%1 swap b%u ;
: s.global.get   swap 35 b%1 swap b%u ;
: s.global.set   swap 36 b%1 swap b%u ;

\ table instructions
: s.table.get     swap 37 b%1 swap b%u ;
: s.table.set     swap 38 b%1 swap b%u ;
: s.table.init    rot 252 b%1 12   b%u swap b%u swap b%u ;
: s.elem.drop    swap 252 b%1 13   b%u swap b%u          ;
: s.table.copy    rot 252 b%1 14   b%u rot  b%u swap b%u ;
: s.table.grow   swap 252 b%1 15   b%u swap b%u          ;
: s.table.size   swap 252 b%1 16   b%u swap b%u          ;
: s.table.fill   swap 252 b%1 17   b%u swap b%u          ;

\ memory instructions (load/store require offset; alignment fixed as 0)
: s._mem   rot swap b%1 0 b%u swap b%u ;
: s.i32.load       40 s._mem ;   : s.i64.load       41 s._mem ;
: s.i32.load8_s    44 s._mem ;   : s.i64.load8_s    48 s._mem ;
: s.i32.load8_u    45 s._mem ;   : s.i64.load8_u    49 s._mem ;
: s.i32.load16_s   46 s._mem ;   : s.i64.load16_s   50 s._mem ;
: s.i32.load16_u   47 s._mem ;   : s.i64.load16_u   51 s._mem ;
                                 : s.i64.load32_s   52 s._mem ;
                                 : s.i64.load32_u   53 s._mem ;
: s.i32.store      54 s._mem ;   : s.i64.store      55 s._mem ;
: s.i32.store8     58 s._mem ;   : s.i64.store8     60 s._mem ;
: s.i32.store16    59 s._mem ;   : s.i64.store16    61 s._mem ;
                                 : s.i64.store32    62 s._mem ;
: s.memory.size    63 b%1 0 b%1 ;
: s.memory.grow    64 b%1 0 b%1 ;
: s.memory.init   swap 252 b%1  8 b%u swap b%u 0 b%1 ;
: s.data.drop     swap 252 b%1  9 b%u swap b%u       ;
: s.memory.copy        252 b%1 10 b%u 0    b%1 0 b%1 ;
: s.memory.fill        252 b%1 11 b%u 0    b%1       ;

\ numeric instructions
: s.i32.const   swap 65 b%1 swap b%s ;
: s.i64.const   swap 66 b%1 swap b%s ;
: s.i32.eqz       69 b%1 ;   : s.i64.eqz       80 b%1 ;
: s.i32.eq        70 b%1 ;   : s.i64.eq        81 b%1 ;
: s.i32.ne        71 b%1 ;   : s.i64.ne        82 b%1 ;
: s.i32.lt_s      72 b%1 ;   : s.i64.lt_s      83 b%1 ;
: s.i32.lt_u      73 b%1 ;   : s.i64.lt_u      84 b%1 ;
: s.i32.gt_s      74 b%1 ;   : s.i64.gt_s      85 b%1 ;
: s.i32.gt_u      75 b%1 ;   : s.i64.gt_u      86 b%1 ;
: s.i32.le_s      76 b%1 ;   : s.i64.le_s      87 b%1 ;
: s.i32.le_u      77 b%1 ;   : s.i64.le_u      88 b%1 ;
: s.i32.ge_s      78 b%1 ;   : s.i64.ge_s      89 b%1 ;
: s.i32.ge_u      79 b%1 ;   : s.i64.ge_u      90 b%1 ;
: s.i32.clz      103 b%1 ;   : s.i64.clz      121 b%1 ;
: s.i32.ctz      104 b%1 ;   : s.i64.ctz      122 b%1 ;
: s.i32.popcnt   105 b%1 ;   : s.i64.popcnt   123 b%1 ;
: s.i32.add      106 b%1 ;   : s.i64.add      124 b%1 ;
: s.i32.sub      107 b%1 ;   : s.i64.sub      125 b%1 ;
: s.i32.mul      108 b%1 ;   : s.i64.mul      126 b%1 ;
: s.i32.div_s    109 b%1 ;   : s.i64.div_s    127 b%1 ;
: s.i32.div_u    110 b%1 ;   : s.i64.div_u    128 b%1 ;
: s.i32.rem_s    111 b%1 ;   : s.i64.rem_s    129 b%1 ;
: s.i32.rem_u    112 b%1 ;   : s.i64.rem_u    130 b%1 ;
: s.i32.and      113 b%1 ;   : s.i64.and      131 b%1 ;
: s.i32.or       114 b%1 ;   : s.i64.or       132 b%1 ;
: s.i32.xor      115 b%1 ;   : s.i64.xor      133 b%1 ;
: s.i32.shl      116 b%1 ;   : s.i64.shl      134 b%1 ;
: s.i32.shr_s    117 b%1 ;   : s.i64.shr_s    135 b%1 ;
: s.i32.shr_u    118 b%1 ;   : s.i64.shr_u    136 b%1 ;
: s.i32.rotl     119 b%1 ;   : s.i64.rotl     137 b%1 ;
: s.i32.rotr     120 b%1 ;   : s.i64.rotr     138 b%1 ;
: s.i32.wrap_i64       167 b%1 ;
: s.i64.extend_i32_s   172 b%1 ;
: s.i64.extend_i32_u   173 b%1 ;
: s.i32.extend8_s      192 b%1 ;
: s.i32.extend16_s     193 b%1 ;
: s.i64.extend8_s      194 b%1 ;
: s.i64.extend16_s     195 b%1 ;
: s.i64.extend32_s     196 b%1 ;



\ Little utilities

  \ types
  : s.i32 127 b%1 ;
  : s.i64 126 b%1 ;

  \ local signatures
  : l[]                0 b%u ;
  : l[i32]             1 b%u 1 b%u s.i32 ;
  : l[i64]             1 b%u 1 b%u s.i64 ;
  : l[i32,i32]         1 b%u 2 b%u s.i32 ;
  : l[i32,i64]         2 b%u 1 b%u s.i32 1 b%u s.i64 ;
  : l[i64,i64]         1 b%u 2 b%u s.i64 ;
  : l[i32,i32,i32]     1 b%u 3 b%u s.i32 ;
  : l[i32,i32,i32,i32] 1 b%u 4 b%u s.i32 ;

  \ chars = lambda s: ' '.join(['0'] + list(map(str, reversed(s.encode()))))

  \ ( 0 (chars)* -- 0 (chars)* len )
  : strlen   1 begin dup pick while 1 + repeat 1 - ;

  \ ( bytes 0 (chars)* -- bytes )
  : object.string
    strlen dup 2 + pick swap b%u   \ length prefix
    begin over while swap b%1 repeat
    drop drop
  ;

  \ ( sig -- code tmp func-id )
  \ usage:
  \    []->[]   object.func-start
  \    constant name-of-func
  \      l[]
  \      body...
  \    object.func-end
  : object.func-start
    object.sec.func swap b%u drop
    object.sec.code
      object.sec.tmp
        object.func
  ;
  : object.func-end   s.end object.append drop ;



\ Module start!

object.output
  \ header
  1836278016 b%4 \ magic
  1          b%4 \ version

  \ types
  1 b%1
  object.sec.tmp
    23 b%u
    96 b%1 0 b%u                   0 b%u              0 constant []->[]
    96 b%1 0 b%u                   1 b%u s.i32        1 constant []->[i32]
    96 b%1 0 b%u                   2 b%u s.i64 s.i32  2 constant []->[i64,i32]
    96 b%1 0 b%u                   1 b%u s.i64        3 constant []->[i64]
    96 b%1 1 b%u s.i32             0 b%u              4 constant [i32]->[]
    96 b%1 1 b%u s.i32             1 b%u s.i32        5 constant [i32]->[i32]
    96 b%1 1 b%u s.i32             1 b%u s.i64        6 constant [i32]->[i64]
    96 b%1 1 b%u s.i32             2 b%u s.i64 s.i32  7 constant [i32]->[i64,i32]
    96 b%1 1 b%u s.i64             0 b%u              8 constant [i64]->[]
    96 b%1 1 b%u s.i64             2 b%u s.i64 s.i32  9 constant [i64]->[i64,i32]
    96 b%1 2 b%u s.i32 s.i32       0 b%u             10 constant [i32,i32]->[]
    96 b%1 2 b%u s.i32 s.i32       1 b%u s.i32       11 constant [i32,i32]->[i32]
    96 b%1 2 b%u s.i32 s.i64       0 b%u             12 constant [i32,i64]->[]
    96 b%1 2 b%u s.i32 s.i64       1 b%u s.i32       13 constant [i32,i64]->[i32]
    96 b%1 2 b%u s.i64 s.i32       0 b%u             14 constant [i64,i32]->[]
    96 b%1 3 b%u s.i32 s.i32 s.i32 1 b%u s.i32       15 constant [i32,i32,i32]->[i32]
    96 b%1 3 b%u s.i32 s.i32 s.i64 1 b%u s.i32       16 constant [i32,i32,i64]->[i32]
    96 b%1 3 b%u s.i32 s.i64 s.i32 0 b%u             17 constant [i32,i64,i32]->[]
    96 b%1 3 b%u s.i64 s.i32 s.i32 0 b%u             18 constant [i64,i32,i32]->[]
    96 b%1 3 b%u s.i64 s.i32 s.i64 0 b%u             19 constant [i64,i32,i64]->[]
    96 b%1 4 b%u s.i32 s.i32 s.i32 s.i32 1 b%u s.i32 20 constant [i32,i32,i32,i32]->[i32]
    96 b%1 4 b%u s.i32 s.i64 s.i32 s.i32 1 b%u s.i32 21 constant [i32,i64,i32,i32]->[i32]
    96 b%1 9 b%u s.i32 s.i32 s.i32 s.i32 s.i32 s.i64 s.i64 s.i32 s.i32 1 b%u s.i32
           22 constant [i32,i32,i32,i32,i32,i64,i64,i32,i32]->[i32]
  object.append

  \ imports
  2 b%1
  object.sec.tmp

    \ imports get function indices, but no entries in func/code sections
    9 constant object.import-count

    object.import-count b%u

    : object._wasip1 0 49 119 101 105 118 101 114 112 95 116 111 104 115 112 97
                     110 115 95 105 115 97 119 object.string ;

    object.func constant wasi.args_get
    object._wasip1 0 116 101 103 95 115 103 114 97 object.string
    0 b%1 [i32,i32]->[i32] b%u

    object.func constant wasi.args_sizes_get
    object._wasip1 0 116 101 103 95 115 101 122 105 115 95 115 103 114
    97 object.string
    0 b%1 [i32,i32]->[i32] b%u

    object.func constant wasi.fd_close
    object._wasip1 0 101 115 111 108 99 95 100 102 object.string
    0 b%1 [i32]->[i32] b%u

    object.func constant wasi.fd_prestat_dir_name
    object._wasip1 0 101 109 97 110 95 114 105 100 95 116 97 116 115 101 114 112
    95 100 102 object.string
    0 b%1 [i32,i32,i32]->[i32] b%u

    object.func constant wasi.fd_read
    object._wasip1 0 100 97 101 114 95 100 102 object.string
    0 b%1 [i32,i32,i32,i32]->[i32] b%u

    object.func constant wasi.fd_seek
    object._wasip1 0 107 101 101 115 95 100 102 object.string
    0 b%1 [i32,i64,i32,i32]->[i32] b%u

    object.func constant wasi.fd_write
    object._wasip1 0 101 116 105 114 119 95 100 102 object.string
    0 b%1 [i32,i32,i32,i32]->[i32] b%u

    object.func constant wasi.path_open
    object._wasip1 0 110 101 112 111 95 104 116 97 112 object.string
    0 b%1 [i32,i32,i32,i32,i32,i64,i64,i32,i32]->[i32] b%u
    \ yes, that really is the signature

    object.func constant wasi.proc_exit
    object._wasip1 0 116 105 120 101 95 99 111 114 112 object.string
    0 b%1 [i32]->[] b%u

  object.append

drop

0 constant rt.sp
1 constant rt.alloc.block-next
2 constant rt.alloc.bytes-next



\ Runtime

[i32,i32]->[]   object.func-start constant
rt.write
  l[]
  0 s.i32.const
  0 s.local.get
  0 s.i32.store   \ iovec.buf
  4 s.i32.const
  1 s.local.get
  0 s.i32.store   \ iovec.buf_len
  2 s.i32.const   \ stream=stderr
  0 s.i32.const   \ const iovec *
  1 s.i32.const   \ iovec_size=1
  0 s.i32.const   \ (out) *bytes_written
  wasi.fd_write s.call
  s.drop
object.func-end

[i32,i32]->[]   object.func-start constant
rt.error
  l[]
  0 s.local.get
  1 s.local.get
  rt.write s.call
  15 s.i32.const
  wasi.proc_exit s.call
  s.unreachable
object.func-end

: object.error
  strlen
  object.sec.tmp
    object.data-addr s.i32.const \ addr
    swap             s.i32.const \ len
    rt.error         s.call
                     s.unreachable
  drop
  object.sec.data
    begin over while swap b%1 repeat
  drop drop
;



[i64]->[i64,i32]   object.func-start constant
rt.load.stack
  l[i32]
  s.block
    0      s.local.get
    10000  s.i64.const
           s.i64.gt_u
    0      s.br_if
    0      s.local.get
           s.i32.wrap_i64
    10     s.i32.const
           s.i32.mul
    rt.sp  s.global.get
           s.i32.add
    1      s.local.tee
    100032 s.i32.const
           s.i32.ge_u
    0      s.br_if
    1      s.local.get
    0      s.i64.load
    1      s.local.get
    8      s.i32.load16_u
           s.return
  s.end
  \ stack underflow
  0 10 119 111 108 102 114 101 100 110 117 32 107 99 97 116 115 object.error
object.func-end

[i64,i32,i32]->[]   object.func-start constant
rt.store.stack
  l[i32]
  rt.sp s.global.get
  2     s.local.get
  10    s.i32.const
        s.i32.mul
        s.i32.add
  3     s.local.tee
  0     s.local.get
  0     s.i64.store
  3     s.local.get
  1     s.local.get
  8     s.i32.store8
object.func-end

[i32]->[i64,i32]   object.func-start constant
rt.load.mem
  l[]
  0 s.local.get   0 s.i64.load
  0 s.local.get   8 s.i32.load16_u
  0 s.local.tee
  s.i32.eqz
  s.if
    \ uninitialized data
    0 10 97 116 97 100 32 100 101 122 105 108 97 105 116 105 110 105 110 117
    object.error
  s.end
  0 s.local.get
object.func-end

[i32,i64,i32]->[]   object.func-start constant
rt.store.mem
  l[]
  0 s.local.get   1 s.local.get   0 s.i64.store
  0 s.local.get   2 s.local.get   8 s.i32.store16
object.func-end



[i64,i32]->[]   object.func-start constant
rt.push
  l[]
  rt.sp s.global.get
  32    s.i32.const
        s.i32.le_u
  s.if
    \ stack overflow
    0 10 119 111 108 102 114 101 118 111 32 107 99 97 116 115 object.error
  s.end
  rt.sp s.global.get
  10    s.i32.const
        s.i32.sub
  rt.sp s.global.set
  rt.sp s.global.get
  0     s.local.get
  0     s.i64.store
  rt.sp s.global.get
  1     s.local.get
  8     s.i32.store16
object.func-end

[i64]->[]   object.func-start constant
rt.push.num
  l[]
  0 s.local.get
  2 s.i32.const
  rt.push s.call
object.func-end

[i32]->[]   object.func-start constant
rt.push.bool
  l[]
  -1 s.i64.const
   0 s.i64.const
   0 s.local.get
     s.select
  rt.push.num s.call
object.func-end

[]->[i64,i32]   object.func-start constant
rt.pop
  l[]
  0             s.i64.const
  rt.load.stack s.call
  rt.sp         s.global.get
  10            s.i32.const
                s.i32.add
  rt.sp         s.global.set
object.func-end

[]->[i32]   object.func-start constant
rt.pop.ptr
  l[]
  rt.pop s.call
  1 s.i32.const
  s.i32.ne
  s.if
    \ expected pointer
    0 10 114 101 116 110 105 111 112 32 100 101 116 99 101 112 120 101
    object.error
  s.end
  s.i32.wrap_i64
object.func-end

[]->[i64]   object.func-start constant
rt.pop.num
  l[]
  rt.pop s.call
  2 s.i32.const
  s.i32.ne
  s.if
    \ expected number
    0 10 114 101 98 109 117 110 32 100 101 116 99 101 112 120 101 object.error
  s.end
object.func-end

[]->[i32]   object.func-start constant
rt.pop.bool
  l[]
  rt.pop s.call
         s.drop
  0      s.i64.const
         s.i64.ne
object.func-end

[]->[i32]   object.func-start constant
rt.pop.bytes
  l[]
  rt.pop s.call
  3 s.i32.const
  s.i32.ne
  s.if
    \ expected bytes
    0 10 115 101 116 121 98 32 100 101 116 99 101 112 120 101 object.error
  s.end
  s.i32.wrap_i64
object.func-end

[i32]->[i64]   object.func-start constant
rt.pop.user
  l[]
  rt.pop s.call
  0 s.local.get
  s.i32.ne
  s.if
    \ wrong user type
    0 10 101 112 121 116 32 114 101 115 117 32 103 110 111 114 119 object.error
  s.end
object.func-end



[i32]->[i32]   object.func-start constant
rt.alloc.pages
  l[]
  0  s.local.get
     s.memory.grow
  0  s.local.tee
  -1 s.i32.const
     s.i32.eq
  s.if
    \ out of memory
    0 10 121 114 111 109 101 109 32 102 111 32 116 117 111 object.error
  s.end
  0  s.local.get
  16 s.i32.const
     s.i32.shl
object.func-end

[]->[i32]   object.func-start constant
rt.alloc.block
  l[]
  rt.alloc.block-next s.global.get
  65535 s.i32.const
        s.i32.and
        s.i32.eqz
  s.if
    \ need to allocate
    1 s.i32.const
    rt.alloc.pages s.call
    rt.alloc.block-next s.global.set
  s.end
  rt.alloc.block-next s.global.get
  rt.alloc.block-next s.global.get
  4096 s.i32.const
       s.i32.add
  rt.alloc.block-next s.global.set
object.func-end

[i32]->[i32]   object.func-start constant
rt.alloc.buffer
  l[i32,i32]
  0      s.local.get
  2      s.i32.const
         s.i32.shl
  100032 s.i32.const
         s.i32.add
  1      s.local.tee \ linked list of correct-size buffers
  0      s.i32.load
  2      s.local.tee \ buffer to return
  s.i32.eqz
  s.if
    1 s.i32.const
    0 s.local.get
      s.i32.shl      \ number of pages to allocate
    rt.alloc.pages s.call
    2 s.local.tee    \ buffer to return
    0 s.local.get
    0 s.i32.store8   \ initialize size class
  s.end
  1 s.local.get
  2 s.local.get
  1 s.i32.load
  0 s.i32.store      \ unlink from free list
  2 s.local.get
object.func-end

[i32]->[i32]   object.func-start constant
rt.alloc.bytes
  l[i32]
  rt.alloc.bytes-next s.global.get
  1 s.local.tee                      \ space for pointer
  65535 s.i32.const
        s.i32.and
        s.i32.eqz
  s.if
    1 s.i32.const
    rt.alloc.pages s.call
    1 s.local.set
  s.end
  1 s.local.get
  4 s.i32.const
    s.i32.add
  rt.alloc.bytes-next s.global.set   \ next += 4
  1 s.local.get
  0 s.local.get
  rt.alloc.buffer s.call             \ alloc
  0 s.i32.store
  1 s.local.get
object.func-end

[i32]->[]   object.func-start constant
rt.free.buffer
  l[i32]
  0      s.local.get   \ @1
  0      s.local.get
  0      s.i32.load8_u
  2      s.i32.const
         s.i32.shl
  100032 s.i32.const
         s.i32.add
  1      s.local.tee   \ linked list
  0      s.i32.load
  1      s.i32.store   \ save old head at @1
  1      s.local.get
  0      s.local.get
  0      s.i32.store
object.func-end

[i32]->[i32]   object.func-start constant
rt.bytes.size-class-for-capacity
  l[]
  0 s.local.get
  65532 s.i32.const
  s.i32.lt_u
  s.if
    0 s.i32.const
      s.return
  s.end
  16 s.i32.const
  0  s.local.get
  4  s.i32.const
     s.i32.add
     s.i32.clz
     s.i32.sub
object.func-end

[i32,i64]->[i32]   object.func-start constant
rt.buffer-offset
  l[]
  0 s.local.get
  1 s.i32.load
  s.i64.extend_i32_u \ len
  1 s.local.get
  s.i64.le_u
  s.if
    \ bytes index out of bounds
    0 10 115 100 110 117 111 98 32 102 111 32 116 117 111 32 120 101 100 110 105
    32 115 101 116 121 98 object.error
  s.end
  0 s.local.get
  1 s.local.get
  s.i32.wrap_i64
  s.i32.add
  5 s.i32.const
  s.i32.add
object.func-end

[i32,i64]->[]   object.func-start constant
rt.bytes-push
  l[i32,i32,i32]   \ params/locals: 0=bytes, 1=n, 2=buffer, 3=len, 4=new-buffer
  65536 s.i32.const
  0 s.local.get
  0 s.i32.load
  2 s.local.tee \ old buffer
  0 s.i32.load8_u
    s.i32.shl
  5 s.i32.const
    s.i32.sub   \ old capacity
  2 s.local.get
  1 s.i32.load
  3 s.local.tee \ old len
  s.i32.eq
  s.if          \ need to reallocate first
    2 s.local.get
    0 s.i32.load8_u
    1 s.i32.const
      s.i32.add
    rt.alloc.buffer s.call
    4 s.local.tee   5 s.i32.const   s.i32.add \ dest
    2 s.local.get   5 s.i32.const   s.i32.add \ src
    3 s.local.get                             \ len
    s.memory.copy
    2 s.local.get
    rt.free.buffer s.call
    0 s.local.get
    4 s.local.get
    2 s.local.tee \ update buffer local
    0 s.i32.store \ update bytes
  s.end
  2 s.local.get
  3 s.local.get
    s.i32.add
  1 s.local.get
  5 s.i64.store8 \ store byte
  2 s.local.get
  3 s.local.get
  1 s.i32.const
    s.i32.add
  1 s.i32.store  \ increment len
object.func-end



[]->[i32]   object.func-start constant
rt.file.cwd
  l[i32]
  3 s.i32.const
  0 s.local.set
  s.loop
    0  s.local.get   \ fd
    0  s.i32.const   \ *path
    32 s.i32.const   \ path_len
    wasi.fd_prestat_dir_name s.call
    s.if             \ probably a bad file descriptor
      \ no file access
      0 10 115 115 101 99 99 97 32 101 108 105 102 32 111 110 object.error
    s.end
    0 s.i32.const
    0 s.i32.load8_u
    46 s.i32.const   \ starts with '.'?
    s.i32.eq
    s.if
      0 s.local.get
      s.return       \ we'll just assume it's a relative directory
    s.end
    0 s.local.get
    1 s.i32.const
    s.i32.add
    0 s.local.set
    0 s.br
  s.end
  s.unreachable
object.func-end

[i32,i32,i64]->[i32]   object.func-start constant
rt.file.open
  \ params: bytes(filename), o_flags, fd_rights
  \ returns: -1(failure) or fd
  l[]
  0 s.local.get
  0 s.i32.load
  1 s.i32.load
  s.i32.eqz
  s.if \ empty path
    -1 s.i32.const
    s.return
  s.end
  0 s.local.get
  0 s.i64.const
  rt.bytes-push s.call \ push null byte
  rt.file.cwd s.call   \ fd
  0 s.i32.const        \ dirflags (e.g. SYMLINK_FOLLOW)
  0 s.local.get
  0 s.i32.load
  5 s.i32.const
    s.i32.add          \ path
  0 s.local.get
  0 s.i32.load
  1 s.i32.load         \ path_len
  1 s.local.get        \ o_flags (e.g. CREAT, EXCL)
  2 s.local.get        \ fd_rights_base (e.g. READ, WRITE, SEEK)
  0 s.i64.const        \ fd_rights_inheriting
  0 s.i32.const        \ fd_flags (e.g. NONBLOCK)
  0 s.i32.const        \ (out) *fd
  wasi.path_open s.call
  0 s.local.get
  0 s.i32.load
  0 s.local.get
  0 s.i32.load
  1 s.i32.load
  1 s.i32.const
    s.i32.sub
  1 s.i32.store        \ pop null byte
  s.if
    -1 s.i32.const
    s.return           \ error
  s.end
  0 s.i32.const
  0 s.i32.load         \ success
object.func-end

[i32]->[i32]   object.func-start constant
rt.file.len
  l[]
  0 s.local.get \ fd
  0 s.i64.const \ offset
  2 s.i32.const \ whence = END
  0 s.i32.const \ (out) *pos
  wasi.fd_seek s.call
  s.if
    \ could not seek file
    0 10 101 108 105 102 32 107 101 101 115 32 116 111 110 32 100 108 117 111 99
    object.error
  s.end
  0 s.i32.const
  4 s.i32.load
  s.if
    \ file too large
    0 10 101 103 114 97 108 32 111 111 116 32 101 108 105 102 object.error
  s.end
  0 s.i32.const
  0 s.i32.load
  0 s.local.get \ fd
  0 s.i64.const \ offset
  0 s.i32.const \ whence = SET (start of file)
  0 s.i32.const \ (out) *pos (ignored)
  wasi.fd_seek s.call   s.drop
object.func-end



\ \ DUMP-MEM : [addr, len] -> []
\
\ [i32]->[i32] object.func-start
\ constant HALF-BYTE
\   l[] 0 s.local.get 15 s.i32.const s.i32.and 0 s.local.tee 48 s.i32.const
\   55 s.i32.const 0 s.local.get 10 s.i32.const s.i32.lt_u s.select s.i32.add
\ object.func-end
\
\ [i32]->[i32] object.func-start
\ constant BYTE
\   l[]
\   0 s.local.get HALF-BYTE s.call 8 s.i32.const s.i32.shl
\   0 s.local.get 4 s.i32.const s.i32.shr_u HALF-BYTE s.call
\   s.i32.or
\ object.func-end
\
\ [i32,i32]->[] object.func-start
\ constant DUMP-MEM
\   l[i32,i32]
\   4 s.i32.const   12 s.i32.const   0 s.i32.store
\   8 s.i32.const    3 s.i32.const   0 s.i32.store
\   s.loop
\     12 s.i32.const
\     0 s.local.get
\     2 s.local.get
\     s.i32.add
\     0 s.i32.load8_u
\     BYTE s.call
\     0 s.i32.store16
\     14 s.i32.const
\       32 s.i32.const
\       10 s.i32.const
\         2 s.local.get
\         1 s.i32.const
\         s.i32.add
\         2 s.local.tee
\         15 s.i32.const
\         s.i32.and
\       s.select
\       0 s.i32.store8
\     4 s.i32.const
\     rt.write s.call
\     1 s.local.get
\     2 s.local.get
\     s.i32.gt_u
\     0 s.br_if
\   s.end
\ object.func-end



\ 'emit' interface

: emit.word.:
  object.sec.func []->[] b%u drop
  object.sec.tmp l[] drop
  object.func
;
: emit.word.;   object.sec.code object.sec.tmp object.func-end ;

: emit.main.word     object.sec.main swap s.call drop ;
: emit.main.number   object.sec.main swap s.i64.const rt.push.num s.call drop ;
: emit.word.word     object.sec.tmp  swap s.call drop ;
: emit.word.number   object.sec.tmp  swap s.i64.const rt.push.num s.call drop ;

: emit.word.if                       object.sec.tmp rt.pop.bool s.call s.if drop 0 ;
: emit.word.if-else        drop      object.sec.tmp s.else drop 0 ;
: emit.word.if-else-then   drop drop object.sec.tmp s.end  drop   ;
: emit.word.if-then        drop      object.sec.tmp s.end  drop   ;

: emit.word.begin                    object.sec.tmp s.loop                  drop 0 ;
: emit.word.while                    object.sec.tmp rt.pop.bool s.call s.if drop 0 ;
: emit.word.repeat         drop drop object.sec.tmp 1 s.br s.end s.end      drop ;

: emit.word.exit                     object.sec.tmp s.return drop ;

: emit.word.string
  object.sec.tmp
    object.data-addr s.i32.const
    object.sec.data rot span.unescape s.i32.const
    rt.write s.call
  drop
;

: emit.type
  4 +
  dup 65535 > if "too many types\n" 15 fail then

  []->[] object.func-start -rot   \ opener
    l[]
    3 pick      s.i32.const
    rt.pop.user s.call
    1           s.i32.const
    rt.push     s.call
  object.func-end swap

  []->[] object.func-start -rot   \ closer
    l[]
    rt.pop.ptr s.call
               s.i64.extend_i32_u
    3 pick     s.i32.const
    rt.push    s.call
  object.func-end nip
;

: emit.constant
  []->[] object.func-start -rot
    l[]
    object.data-addr s.i32.const
    rt.load.mem s.call
    rt.push s.call
  object.func-end

  object.sec.main
    object.data-addr s.i32.const
    rt.pop s.call
    rt.store.mem s.call
  drop

  object.sec.data 0b%10 drop
;

: emit.variable
  []->[] object.func-start -rot
    l[]
    object.data-addr s.i32.const
    rt.load.mem s.call
    rt.push s.call
  object.func-end

  []->[] object.func-start -rot
    l[]
    object.data-addr s.i32.const
    rt.pop s.call
    rt.store.mem s.call
  object.func-end

  object.sec.data 0b%10 drop
;

: object.init
  object.sec.main
    l[i32,i32,i32,i32]

    \ allocate argv
    0 s.i32.const
    rt.alloc.bytes s.call   \ assuming it fits into 64 KiB, otherwise traps
    0       s.local.tee
            s.i64.extend_i32_u
    3       s.i32.const
    rt.push s.call
    emit.constant words.builtin.argv cell.set

    \ initialize argv
    0 s.i32.const
    4 s.i32.const
    wasi.args_sizes_get s.call
      s.drop
    0 s.i32.const
    0 s.i32.load \ argc
    1 s.i32.const
    s.i32.gt_u
    s.if \ need to copy args
      \ [size]:1 [len]:4 [arg 1] [args 2-] [arg pointers]
      \ ^0               ^1      ^2        ^3
      0 s.local.get
      0 s.i32.load
      0 s.local.tee \ size
      5 s.i32.const
        s.i32.add
      1 s.local.tee \ arg 1
      4 s.i32.const
      0 s.i32.load
        s.i32.add
      3 s.local.tee \ arg pointers
      1 s.local.get
      wasi.args_get s.call
        s.drop
      3 s.local.get
      4 s.i32.load
      2 s.local.set \ args 2-
      3 s.local.get
      2 s.local.get
        s.i32.sub
      3 s.local.set \ len([args 2-])
      1 s.local.get \ dest
      2 s.local.get \ source
      3 s.local.get \ len
        s.memory.copy
      0 s.local.get
      3 s.local.get
      1 s.i32.store
    s.end

  drop
;

: object.finalize

  \ add main as function
  object.func drop
  object.sec.func []->[] b%u drop
  object.sec.code object.sec.main object.func-end

  object.output

    \ already initialized:
    \ (type ...)*
    \ (import ...)*

    \ (func ...)* declarations
      3 b%1
      object.sec.tmp
        object.func-count@ object.import-count - b%u
        object.sec.func bytes.append
      object.append

    \ (memory ...)
      5 b%1
      object.sec.tmp
        1 b%u
        0 b%1 object.data-addr 65535 + 16 >> b%u
      object.append

    \ (global $sp (mut i32) (i32.const 100032))
    \ (global $rt.alloc.block-next (mut i32) (i32.const 0))
    \ (global $rt.alloc.bytes-next (mut i32) (i32.const 0))
      6 b%1
      object.sec.tmp
        3 b%u
        s.i32 1 b%1 100032 s.i32.const s.end
        s.i32 1 b%1      0 s.i32.const s.end
        s.i32 1 b%1      0 s.i32.const s.end
      object.append

    \ (export "memory" (memory 0))
    \ (export "_start" (func ...))
      7 b%1
      object.sec.tmp
        2 b%u
        0 121 114 111 109 101 109 object.string 2 b%1 0 b%u
        0 116 114 97 116 115 95 object.string 0 b%1 object.func-count@ 1 - b%u
      object.append

    \ (data ...) count
      12 b%1
        object.sec.tmp
        1 b%u
      object.append

    \ (func ...)* code
      10 b%1
      object.sec.tmp
        object.func-count@ object.import-count - b%u
        object.sec.code bytes.append
      object.append

    \ (data (i32.const 100100) ...)
      11 b%1
      object.sec.tmp
        1 b%u
        0 b%1 100100 s.i32.const s.end
        object.sec.data bytes.length b%u
        object.sec.data bytes.append
      object.append

;



\ Built-in words

: object.word []->[] object.func-start ;
: object.num1
  object.word -rot
  l[]
  rt.pop.num s.call
  rot
;
: object.num2
  object.word -rot
  l[i64]
  rt.pop.num s.call   0 s.local.set
  rt.pop.num s.call   0 s.local.get
  rot
;
: object.num-end  rt.push.num  s.call object.func-end ;
: object.bool-end rt.push.bool s.call object.func-end ;

\ Arithmetic
object.num2 words.builtin.+   cell.set s.i64.add   object.num-end
object.num2 words.builtin.-   cell.set s.i64.sub   object.num-end
object.num2 words.builtin.*   cell.set s.i64.mul   object.num-end
\ object.num2 words.builtin./   cell.set s.i64.div_u object.num-end

\ Bitwise operations
object.num2 words.builtin.<<  cell.set s.i64.shl   object.num-end
object.num2 words.builtin.>>  cell.set s.i64.shr_u object.num-end
object.num1 words.builtin.not cell.set -1 s.i64.const s.i64.xor object.num-end
object.num2 words.builtin.and cell.set s.i64.and   object.num-end
object.num2 words.builtin.or  cell.set s.i64.or    object.num-end
object.num2 words.builtin.xor cell.set s.i64.xor   object.num-end

\ Comparison
object.num2 words.builtin.=   cell.set s.i64.eq    object.bool-end
object.num2 words.builtin.<>  cell.set s.i64.ne    object.bool-end
object.num2 words.builtin.<   cell.set s.i64.lt_u  object.bool-end
object.num2 words.builtin.>   cell.set s.i64.gt_u  object.bool-end
object.num2 words.builtin.<=  cell.set s.i64.le_u  object.bool-end
object.num2 words.builtin.>=  cell.set s.i64.ge_u  object.bool-end

object.num2 words.builtin./ cell.set
  s.i64.eqz
  s.if
    \ division by zero
    0 10 111 114 101 122 32 121 98 32 110 111 105 115 105 118 105 100 object.error
  s.end
  0 s.local.get
    s.i64.div_u
object.num-end



\ Stack

object.word words.builtin.dup cell.set
  l[]
  0             s.i64.const
  rt.load.stack s.call
  rt.push       s.call
object.func-end

object.word words.builtin.drop cell.set
  l[]
  rt.pop s.call   s.drop   s.drop
object.func-end

object.word words.builtin.swap cell.set
  l[]
  0 s.i64.const   rt.load.stack  s.call
  1 s.i64.const   rt.load.stack  s.call
  0 s.i32.const   rt.store.stack s.call
  1 s.i32.const   rt.store.stack s.call
object.func-end

object.word words.builtin.over cell.set
  l[]
  1             s.i64.const
  rt.load.stack s.call
  rt.push       s.call
object.func-end

object.word words.builtin.nip cell.set
  l[]
  rt.pop  s.call
  rt.pop  s.call   s.drop s.drop
  rt.push s.call
object.func-end

object.word words.builtin.tuck cell.set
  l[]
  0 s.i64.const   rt.load.stack  s.call
  1 s.i64.const   rt.load.stack  s.call
  0 s.i64.const   rt.load.stack  s.call
  1 s.i32.const   rt.store.stack s.call
  0 s.i32.const   rt.store.stack s.call
                  rt.push        s.call
object.func-end

object.word words.builtin.rot cell.set
  l[]
  0 s.i64.const   rt.load.stack  s.call
  1 s.i64.const   rt.load.stack  s.call
  2 s.i64.const   rt.load.stack  s.call
  0 s.i32.const   rt.store.stack s.call
  2 s.i32.const   rt.store.stack s.call
  1 s.i32.const   rt.store.stack s.call
object.func-end

object.word words.builtin.-rot cell.set
  l[]
  0 s.i64.const   rt.load.stack  s.call
  1 s.i64.const   rt.load.stack  s.call
  2 s.i64.const   rt.load.stack  s.call
  1 s.i32.const   rt.store.stack s.call
  0 s.i32.const   rt.store.stack s.call
  2 s.i32.const   rt.store.stack s.call
object.func-end

object.word words.builtin.pick cell.set
  l[]
  rt.pop.num    s.call
  rt.load.stack s.call
  rt.push       s.call
object.func-end



\ Input and output

object.word words.builtin.. cell.set
  l[i32,i64]
  \ maximum number is 20 digits, which fits nicely into the scratch space
  31 s.i32.const
  0  s.local.tee     \ addr = 31
  32 s.i32.const
  0  s.i32.store8    \ *addr = ' '
  rt.pop.num s.call
  1  s.local.set     \ n = pop_num()
  s.loop             \ do {...} while (n != 0)
    0  s.local.get
    1  s.i32.const
       s.i32.sub
    0  s.local.tee   \   addr -= 1
    1  s.local.get
    10 s.i64.const
       s.i64.rem_u
    48 s.i64.const
       s.i64.add
    0  s.i64.store8  \   *addr = '0' + (n % 10)
    1  s.local.get
    10 s.i64.const
       s.i64.div_u
    1  s.local.tee   \   n = n / 10
    0  s.i64.const
       s.i64.ne
    0  s.br_if
  s.end
  0  s.local.get   \ addr
  32 s.i32.const
  0  s.local.get
     s.i32.sub     \ len
  rt.write s.call
object.func-end

object.word words.builtin.putc cell.set
  l[i64]
  s.block
    rt.pop.num s.call
    0   s.local.tee
    10  s.i64.const
        s.i64.eq
    0   s.br_if   \ c == '\n'
    0   s.local.get
    32  s.i64.const
        s.i64.ge_u
    0   s.local.get
    126 s.i64.const
        s.i64.le_u
        s.i32.and
    0   s.br_if   \ (' ' <= c) && (c <= '~')
    \ unprintable character
    0 10 114 101 116 99 97 114 97 104 99 32 101 108 98 97 116 110 105 114 112 110 117
    object.error
  s.end
  8 s.i32.const 0 s.local.get 0 s.i64.store8
  8 s.i32.const   \ addr
  1 s.i32.const   \ len
  rt.write s.call
object.func-end

object.word words.builtin.fail cell.set
  l[]
  rt.pop.num  s.call
              s.i32.wrap_i64
  wasi.proc_exit s.call
object.func-end



\ Blocks

object.word words.builtin.block.new cell.set
  l[]
  rt.alloc.block s.call
  s.i64.extend_i32_u
  1 s.i32.const
  rt.push s.call
object.func-end

object.word words.builtin.@ cell.set
  l[]
  rt.pop.ptr  s.call
  rt.load.mem s.call
  rt.push     s.call
object.func-end

object.word words.builtin.! cell.set
  l[]
  rt.pop.ptr   s.call
  rt.pop       s.call
  rt.store.mem s.call
object.func-end

object.word words.builtin.+p cell.set
  l[i64,i64]
  rt.pop.num s.call
  0          s.local.tee
  rt.pop.ptr s.call
             s.i64.extend_i32_u
  1          s.local.tee
  4095 s.i64.const
       s.i64.and
  10   s.i64.const
       s.i64.div_u \ current offset
       s.i64.add   \ new offset
  400  s.i64.const
  s.i64.ge_u
  s.if
    \ pointer out of bounds
    0 10 115 100 110 117 111 98 32 102 111 32 116 117 111 32 114 101 116 110 105
    111 112 object.error
  s.end
  0  s.local.get
  10 s.i64.const
     s.i64.mul
  1  s.local.get
     s.i64.add
  1  s.i32.const
  rt.push s.call
object.func-end



\ Byte arrays

object.word words.builtin.bytes.new cell.set
  l[]
  0              s.i32.const
  rt.alloc.bytes s.call
                 s.i64.extend_i32_u
  3              s.i32.const
  rt.push        s.call
object.func-end

object.word words.builtin.bytes.clear cell.set
  l[i32]
  rt.pop.bytes s.call
  0 s.i32.load
  0 s.i32.const
  1 s.i32.store
object.func-end

object.word words.builtin.bytes.length cell.set
  l[]
  rt.pop.bytes s.call
  0            s.i32.load
  1            s.i64.load32_u
  rt.push.num  s.call
object.func-end

object.word words.builtin.b% cell.set
  l[]
  rt.pop.bytes  s.call
  rt.pop.num    s.call
  rt.bytes-push s.call
object.func-end

object.word words.builtin.b@ cell.set
  l[i32,i64]
  rt.pop.bytes     s.call
  0                s.i32.load
  rt.pop.num       s.call
  rt.buffer-offset s.call
  0                s.i64.load8_u
  rt.push.num      s.call
object.func-end

object.word words.builtin.b! cell.set
  l[]
  rt.pop.bytes     s.call
  0                s.i32.load
  rt.pop.num       s.call
  rt.buffer-offset s.call
  rt.pop.num       s.call
  0                s.i64.store8
object.func-end



\ 'file.read' and 'file.write'
\
\ These are a total mess and there's nothing to do about it.
\
\ WASI only lets you open files using other parent file descriptors.
\ (For example, you can open a file from its containing directory.)
\
\ The runtime gives you certain preopened file descriptors:
\    - 0 => stdin
\    - 1 => stdout
\    - 2 => stderr
\    - 3-? => directories, maybe? (e.g. '/' and '.')
\ It's not actually guaranteed that you get 0-2 but nothing's specified anyway.
\
\ We try to find a preopened descriptor starting with '.' and call it 'cwd'.
\ Then we try to use that to open the given filename.

object.word words.builtin.file.read cell.set
  l[i32,i32,i32]
  rt.pop.bytes s.call
   0 s.i32.const  \ o_flags = NONE
  38 s.i64.const \ fd_rights = READ | SEEK | TELL
  rt.file.open s.call
   0 s.local.tee
  -1 s.i32.const
  s.i32.eq
  s.if
    0 s.i64.const
    rt.push.num s.call
    s.return \ couldn't open file -- not a fatal error
  s.end
  0 s.local.get
  rt.file.len s.call
  1 s.local.tee \ length of file
  rt.bytes.size-class-for-capacity s.call
  rt.alloc.bytes s.call
  2 s.local.tee \ bytes
  s.i64.extend_i32_u
  3 s.i32.const
  rt.push s.call \ push the bytes
  2 s.local.get
  0 s.i32.load
  2 s.local.tee \ buffer
  1 s.local.get
  1 s.i32.store \ initialize length
  \ prepare iovec
  0 s.i32.const
  2 s.local.get
  5 s.i32.const
  s.i32.add
  0 s.i32.store \ buf
  4 s.i32.const
  1 s.local.get
  0 s.i32.store \ buf_len
  0 s.local.get \ fd
  0 s.i32.const \ iovs
  1 s.i32.const \ iovs_len
  0 s.i32.const \ (out) *nread
  wasi.fd_read s.call
  s.if
    \ opened but couldn't read -- this IS fatal
    \ could not read file
    0 10 101 108 105 102 32 100 97 101 114 32 116 111 110 32 100 108 117 111 99
    object.error
  s.end
  0 s.i32.const
  0 s.i32.load
  1 s.local.get
  s.i32.ne
  s.if
    \ could not read entire file
    0 10 101 108 105 102 32 101 114 105 116 110 101 32 100 97 101 114 32 116 111
    110 32 100 108 117 111 99 object.error
  s.end
  0 s.local.get
  wasi.fd_close s.call \ close fd
  s.drop
object.func-end

object.word words.builtin.file.write cell.set
  l[i32,i32]
  rt.pop.bytes s.call
  5 s.i32.const  \ o_flags = CREAT | EXCL
  64 s.i64.const \ fd_rights = WRITE
  rt.file.open s.call
  0 s.local.tee  \ fd
  -1 s.i32.const
  s.i32.eq
  s.if
    rt.pop.bytes s.call
    s.drop
    0 s.i64.const
    rt.push.num s.call
    s.return \ couldn't create file -- not a fatal error
  s.end
  \ prepare ciovec
  0 s.i32.const
  rt.pop.bytes s.call
  0 s.i32.load
  1 s.local.tee \ buffer
  5 s.i32.const
  s.i32.add
  0 s.i32.store \ buf
  4 s.i32.const
  1 s.local.get
  1 s.i32.load
  0 s.i32.store \ buf_len
  0 s.local.get \ fd
  0 s.i32.const \ iovs
  1 s.i32.const \ iovs_len
  0 s.i32.const \ (out) *len
  wasi.fd_write s.call
  s.if
    \ created but couldn't write -- this IS fatal
    \ could not write to file
    0 10 101 108 105 102 32 111 116 32 101 116 105 114 119 32 116 111 110 32 100
    108 117 111 99 object.error
  s.end
  0 s.i32.const
  0 s.i32.load
  1 s.local.get
  1 s.i32.load
  s.i32.ne             \ compare written with expected
  s.if
    \ could not write entire file
    0 10 101 108 105 102 32 101 114 105 116 110 101 32 101 116 105 114 119 32
    116 111 110 32 100 108 117 111 99 object.error
  s.end
  -1 s.i64.const
  rt.push.num s.call   \ success
  0 s.local.get
  wasi.fd_close s.call \ close fd
  s.drop
object.func-end
