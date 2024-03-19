\ TODO: check ALL errors: want \n probably
\ TODO: check all words (even those not tested)





\ emit-wasm-wasi.tpl
\
\ Implementation of 'emit' interface that produces WebAssembly modules.
\
\ This is pretty similar to the RISC-V emitter but better documented and easier
\ to disassemble and debug.
\
\
\
\ # ABI
\
\ Values are stored in memory as:  [8 bytes data] [2 bytes type]
\ And on the Wasm stack as:        i64 i32
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
\ 100032 - 100159 - unused byte buffers
\ 100160 - ?????? - compile-time allocations (strings, constants, variables)
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




\ The binary has several sections open at once.
\ Once each section is complete, it is copied into its parent.
\ This is necessary because you need to know their byte lengths to encode them.

bytes.new constant object.output
  bytes.new constant object.sec.func
  bytes.new constant object.sec.code
    bytes.new constant object.sec.tmp   \ buffer for active function
    bytes.new constant object.sec.main
  bytes.new constant object.sec.data

variable object.func-count   0 object.func-count!

: object.func        object.func-count@ dup 1 + object.func-count! ;
: object.data-addr   object.sec.data bytes.length 100160 + ;
: object.append
  2dup bytes.length b%u drop
  2dup bytes.append drop
  bytes.clear
;



\ WebAssembly instructions

\ control instructions
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

\ memory instructions (alignment 0)
: s._mem   rot swap b%1 0 b%u swap b%u ;
: s.i32.load       40 s._mem ;   : s.i64.load       41 s._mem ;
: s.f32.load       42 s._mem ;   : s.f64.load       43 s._mem ;
: s.i32.load8_s    44 s._mem ;   : s.i64.load8_s    48 s._mem ;
: s.i32.load8_u    45 s._mem ;   : s.i64.load8_u    49 s._mem ;
: s.i32.load16_s   46 s._mem ;   : s.i64.load16_s   50 s._mem ;
: s.i32.load16_u   47 s._mem ;   : s.i64.load16_u   51 s._mem ;
                                 : s.i64.load32_s   52 s._mem ;
                                 : s.i64.load32_u   53 s._mem ;
: s.i32.store      54 s._mem ;   : s.i64.store      55 s._mem ;
: s.f32.store      56 s._mem ;   : s.f64.store      57 s._mem ;
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



\ random WebAssembly encodings

\ types
: s.i32 127 b%1 ;
: s.i64 126 b%1 ;

\ local signatures
: l[]        0 b%u ;
: l[i32]     1 b%u 1 b%u s.i32 ;
: l[i64]     1 b%u 1 b%u s.i64 ;
: l[i64,i64] 1 b%u 2 b%u s.i64 ;
: l[i32,i64] 2 b%u 1 b%u s.i32 1 b%u s.i64 ;



\ little utils

\ chars = lambda s: ' '.join(['0'] + list(map(str, reversed(s.encode()))))

\ ( 0 (chars)* -- 0 (chars)* len )
: strlen   1 begin dup pick while 1 + repeat 1 - ;

\ ( bytes 0 (chars)* -- bytes )
: object.string
  strlen dup 2 + pick swap b%u
  begin over while swap b%1 repeat
  drop drop
;

\ []->[] object.func-start
\ constant __name__
\   l[]
\   body...
\ object.func-end

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
    14 b%u
    96 b%1 0 b%u                   0 b%u              0 constant []->[]
    96 b%1 1 b%u s.i64             2 b%u s.i64 s.i32  1 constant [i64]->[i64,i32]
    96 b%1 3 b%u s.i64 s.i32 s.i64 0 b%u              2 constant [i64,i32,i64]->[]
    96 b%1 2 b%u s.i64 s.i32       0 b%u              3 constant [i64,i32]->[]
    96 b%1 0 b%u                   2 b%u s.i64 s.i32  4 constant []->[i64,i32]
    96 b%1 4 b%u s.i32 s.i32 s.i32 s.i32 1 b%u s.i32  5 constant [i32,i32,i32,i32]->[i32]
    96 b%1 1 b%u s.i32             0 b%u              6 constant [i32]->[]
    96 b%1 1 b%u s.i64             0 b%u              7 constant [i64]->[]
    96 b%1 0 b%u                   1 b%u s.i32        8 constant []->[i32]
    96 b%1 0 b%u                   1 b%u s.i64        9 constant []->[i64]
    96 b%1 3 b%u s.i64 s.i32 s.i32 0 b%u             10 constant [i64,i32,i32]->[]
    96 b%1 1 b%u s.i32             2 b%u s.i64 s.i32 11 constant [i32]->[i64,i32]
    96 b%1 1 b%u s.i32             1 b%u s.i32       12 constant [i32]->[i32]
    96 b%1 3 b%u s.i32 s.i64 s.i32 0 b%u             13 constant [i32,i64,i32]->[]
  object.append

  \ imports
  2 b%1
  object.sec.tmp

    \ imports get function indices, but no entries in func/code sections
    2 constant object.import-count

    object.import-count b%u

    object.func constant wasi.fd_write
    0 49 119 101 105 118 101 114 112 95 116 111 104 115 112 97 110 115 95 105
    115 97 119 object.string 0 101 116 105 114 119 95 100 102 object.string
    0 b%1 [i32,i32,i32,i32]->[i32] b%u

    object.func constant wasi.proc_exit
    0 49 119 101 105 118 101 114 112 95 116 111 104 115 112 97 110 115 95 105
    115 97 119 object.string 0 116 105 120 101 95 99 111 114 112 object.string
    0 b%1 [i32]->[] b%u

  object.append

drop

0 constant rt.sp
1 constant rt.alloc.block-next



\ Runtime

[i32]->[] object.func-start
constant rt.write
  l[]
  2 s.i32.const   \ stream=stderr
  0 s.local.get   \ const iovec *
  1 s.i32.const   \ iovec_size=1
  0 s.i32.const   \ size_t *bytes_written
  wasi.fd_write s.call
  s.drop
object.func-end

[i32]->[] object.func-start
constant rt.error
  l[]
  0 s.local.get
  rt.write s.call
  15 s.i32.const
  wasi.proc_exit s.call
  s.unreachable
object.func-end

: object.error
  object.sec.tmp
    object.data-addr s.i32.const
    rt.error         s.call
                     s.unreachable
  drop
  strlen
  object.sec.data
    object.data-addr 8 + b%4   \ ptr
    swap b%4                   \ len
    begin over while swap b%1 repeat
  drop drop
;

[i64]->[i64,i32] object.func-start
constant rt.load.stack
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

[i64,i32,i32]->[] object.func-start
constant rt.store.stack
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

[i64,i32]->[] object.func-start
constant rt.push
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

[i64]->[] object.func-start
constant rt.push.num
  l[]
  0 s.local.get
  2 s.i32.const
  rt.push s.call
object.func-end

[i32]->[] object.func-start
constant rt.push.bool
  l[]
  0 s.i32.const
  0 s.local.get
  s.i32.sub
  s.i64.extend_i32_s
  rt.push.num s.call
object.func-end

[]->[i64,i32] object.func-start
constant rt.pop
  l[]
  0             s.i64.const
  rt.load.stack s.call
  rt.sp         s.global.get
  10            s.i32.const
                s.i32.add
  rt.sp         s.global.set
object.func-end

[]->[i32] object.func-start
constant rt.pop.ptr
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

[]->[i64] object.func-start
constant rt.pop.num
  l[]
  rt.pop s.call
  2 s.i32.const
  s.i32.ne
  s.if
    \ expected number
    0 10 114 101 98 109 117 110 32 100 101 116 99 101 112 120 101 object.error
  s.end
object.func-end

[]->[i32] object.func-start
constant rt.pop.bool
  l[]
  rt.pop s.call
         s.drop
  0      s.i64.const
         s.i64.ne
object.func-end

[i32]->[i64,i32] object.func-start
constant rt.load.mem
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

[i32,i64,i32]->[] object.func-start
constant rt.store.mem
  l[]
  0 s.local.get   1 s.local.get   0 s.i64.store
  0 s.local.get   2 s.local.get   8 s.i32.store16
object.func-end

[i32]->[i32] object.func-start
constant rt.alloc.pages
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

[]->[i32] object.func-start
constant rt.alloc.block
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



\ 'emit' interface

: object.init
  object.sec.main
    l[]
  drop
;

: object.finalize

  \ finish main
  object.func drop
  object.sec.func []->[] b%u drop
  object.sec.code object.sec.main object.func-end

  object.output

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
      6 b%1
      object.sec.tmp
        2 b%u
        s.i32 1 b%1 100032 s.i32.const s.end
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

    \ (data (i32.const 100160) ...)
      11 b%1
      object.sec.tmp
        1 b%u
        0 b%1 100160 s.i32.const s.end
        object.sec.data bytes.length b%u
        object.sec.data bytes.append
      object.append

;

: emit.word.:
  object.sec.func []->[] b%u drop
  object.sec.tmp l[] drop
  object.func
;
: emit.word.;
  object.sec.code object.sec.tmp object.func-end
;

: emit.main.word   object.sec.main swap s.call drop ;
: emit.word.word   object.sec.tmp  swap s.call drop ;
: emit.main.number object.sec.main swap s.i64.const rt.push.num s.call drop ;
: emit.word.number object.sec.tmp  swap s.i64.const rt.push.num s.call drop ;

: emit.type     "type: " . "\n" 0 0 ;

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

: emit.word.string
  object.sec.tmp
    object.data-addr s.i32.const
    rt.write s.call
  drop
  object.sec.data
    object.data-addr 8 +    b%4   \ addr
    dup bytes.length -rot 0 b%4   \ len (placeholder)
    dup rot span.unescape         \ data
    -rot                    b!4   \ len (fixed up)
;

: emit.word.if   object.sec.tmp rt.pop.bool s.call s.if drop 0 ;
: emit.word.if-else        drop      object.sec.tmp s.else drop 0 ;
: emit.word.if-else-then   drop drop object.sec.tmp s.end  drop   ;
: emit.word.if-then        drop      object.sec.tmp s.end  drop   ;

: emit.word.begin              object.sec.tmp s.loop                  drop 0 ;
: emit.word.while              object.sec.tmp rt.pop.bool s.call s.if drop 0 ;
: emit.word.repeat   drop drop object.sec.tmp 1 s.br s.end s.end      drop ;

: emit.word.exit   object.sec.tmp s.return drop ;



\ Built-in words

: object.word []->[] object.func-start ;

object.word words.builtin.+ cell.set
  l[]
  rt.pop.num  s.call
  rt.pop.num  s.call
              s.i64.add
  rt.push.num s.call
object.func-end

object.word words.builtin.- cell.set
  l[i64]
  rt.pop.num s.call
  0          s.local.set
  rt.pop.num s.call
  0          s.local.get
             s.i64.sub
  rt.push.num s.call
object.func-end

object.word words.builtin.* cell.set
  l[]
  rt.pop.num  s.call
  rt.pop.num  s.call
              s.i64.mul
  rt.push.num s.call
object.func-end

object.word words.builtin./ cell.set
  l[i64]
  rt.pop.num s.call
  0          s.local.tee
  s.i64.eqz
  s.if
    \ division by zero
    0 10 111 114 101 122 32 121 98 32 110 111 105 115 105 118 105 100
    object.error
  s.end
  rt.pop.num  s.call
  0           s.local.get
              s.i64.div_u
  rt.push.num s.call
object.func-end

object.word words.builtin.<< cell.set
  l[i64]
  rt.pop.num  s.call
  0           s.local.set
  rt.pop.num  s.call
  0           s.local.get
              s.i64.shl
  rt.push.num s.call
object.func-end

object.word words.builtin.>> cell.set
  l[i64]
  rt.pop.num  s.call
  0           s.local.set
  rt.pop.num  s.call
  0           s.local.get
              s.i64.shr_u
  rt.push.num s.call
object.func-end

object.word words.builtin.not cell.set
  l[]
  rt.pop.num  s.call
  -1          s.i64.const
              s.i64.xor
  rt.push.num s.call
object.func-end

object.word words.builtin.and cell.set
  l[]
  rt.pop.num  s.call
  rt.pop.num  s.call
              s.i64.and
  rt.push.num s.call
object.func-end

object.word words.builtin.or cell.set
  l[]
  rt.pop.num  s.call
  rt.pop.num  s.call
              s.i64.or
  rt.push.num s.call
object.func-end

object.word words.builtin.xor cell.set
  l[]
  rt.pop.num  s.call
  rt.pop.num  s.call
              s.i64.xor
  rt.push.num s.call
object.func-end

object.word words.builtin.= cell.set
  l[]
  rt.pop.num   s.call
  rt.pop.num   s.call
               s.i64.eq
  rt.push.bool s.call
object.func-end

object.word words.builtin.<> cell.set
  l[]
  rt.pop.num   s.call
  rt.pop.num   s.call
               s.i64.ne
  rt.push.bool s.call
object.func-end

object.word words.builtin.< cell.set
  l[]
  rt.pop.num   s.call
  rt.pop.num   s.call
               s.i64.gt_u   \ reversed because the Wasm stack is backwards
  rt.push.bool s.call
object.func-end

object.word words.builtin.> cell.set
  l[]
  rt.pop.num   s.call
  rt.pop.num   s.call
               s.i64.lt_u   \ reversed because the Wasm stack is backwards
  rt.push.bool s.call
object.func-end

object.word words.builtin.<= cell.set
  l[]
  rt.pop.num   s.call
  rt.pop.num   s.call
               s.i64.ge_u   \ reversed because the Wasm stack is backwards
  rt.push.bool s.call
object.func-end

object.word words.builtin.>= cell.set
  l[]
  rt.pop.num   s.call
  rt.pop.num   s.call
               s.i64.le_u   \ reversed because the Wasm stack is backwards
  rt.push.bool s.call
object.func-end

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
  \ TODO:   : tuck swap over ;
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

object.word words.builtin.fail cell.set
  l[]
  rt.pop.num  s.call
              s.i32.wrap_i64
  wasi.proc_exit s.call
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
  0 s.i32.const   8 s.i32.const   0 s.i32.store
  4 s.i32.const   1 s.i32.const   0 s.i32.store
  8 s.i32.const   0 s.local.get   0 s.i64.store8
  0 s.i32.const   rt.write s.call
object.func-end

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
  0  s.i32.const
  0  s.local.get
  0  s.i32.store     \ *(0) = addr
  4  s.i32.const
  32 s.i32.const
  0  s.local.get
     s.i32.sub
  0  s.i32.store     \ *(4) = len()
  0  s.i32.const
  rt.write s.call
object.func-end



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



object.word words.builtin.bytes.new cell.set
  l[]
object.func-end

object.word words.builtin.bytes.clear cell.set
  l[]
object.func-end

object.word words.builtin.bytes.length cell.set
  l[]
object.func-end

object.word words.builtin.b% cell.set
  l[]
object.func-end

object.word words.builtin.b@ cell.set
  l[]
object.func-end

object.word words.builtin.b! cell.set
  l[]
object.func-end
