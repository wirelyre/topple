
\ TODO: check ALL errors: stack overflow misused; want \n probably
\ TODO: memory needs to be big enough for data section?


\ LEB128 encoding (unsigned and signed)
\   b%u ( bytes n -- bytes )
\   b%s ( bytes n -- bytes )

: b%u
  begin   dup 127 and over 7 >> 0 <> 128 and or
          2 pick b%
          7 >> dup
  while repeat
  drop ;

: b%s
  dup 63 >> if
    begin   dup 6 >> 288230376151711743 <>   \ n more?
            over 127 and over 128 and or     \ n more? next-byte
            3 pick b%
    while   7 >> 18302628885633695744 or   repeat
  else
    begin   dup 6 >> 0 <>                  \ n more?
            over 127 and over 128 and or   \ n more? next-byte
            3 pick b%
    while   7 >>   repeat
  then
  drop ;



: 0b%10   0 b%8 0 b%2 ;



bytes.new constant object._output
bytes.new constant object._sec.func
bytes.new constant object._sec.code
bytes.new constant object._sec.data
bytes.new constant object._tmp
bytes.new constant object._main

variable object._funcidx   0 object._funcidx!
: object._func object._funcidx@ dup 1 + object._funcidx! ;

: object._data-addr object._sec.data bytes.length 100160 + ;

: object._append-section
  nip b%1
  object._tmp bytes.length b%u
  object._tmp bytes.append
  object._tmp bytes.clear
;

: object._finish-code
  object._sec.code
    object._tmp bytes.length b%u
    object._tmp bytes.append
    drop
  object._tmp bytes.clear
;



: s.i32 127 b%1 ;
: s.i64 126 b%1 ;

\ control instructions
: s.unreachable   0 b%1          ;
: s.nop           1 b%1          ;
: s.block         2 b%1 64 b%1   ;
: s.loop          3 b%1 64 b%1   ;
: s.if            4 b%1 64 b%1   ;
: s.else          5 b%1          ;
: s.end          11 b%1          ;
: s.br      swap 12 b%1 swap b%u ;
: s.br_if   swap 13 b%1 swap b%u ;
: s.br_table     14 b%1          ;
: s.return       15 b%1          ;
: s.call    swap 16 b%1 swap b%u ;
: s.call_indirect rot 17 b%1 rot b%u swap b%u ;

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
: s.table.init    rot 252 b%1 12 b%u swap b%u swap b%u ;
: s.elem.drop    swap 252 b%1 13 b%u swap b%u          ;
: s.table.copy    rot 252 b%1 14 b%u rot b%u swap b%u  ;
: s.table.grow   swap 252 b%1 15 b%u swap b%u          ;
: s.table.size   swap 252 b%1 16 b%u swap b%u          ;
: s.table.fill   swap 252 b%1 17 b%u swap b%u          ;

\ memory instructions (alignment 0)
: s._mem   rot swap b%1 0 b%u swap b%u ;
: s.i32.load       40 s._mem ;
: s.i64.load       41 s._mem ;
: s.f32.load       42 s._mem ;
: s.f64.load       43 s._mem ;
: s.i32.load8_s    44 s._mem ;
: s.i32.load8_u    45 s._mem ;
: s.i32.load16_s   46 s._mem ;
: s.i32.load16_u   47 s._mem ;
: s.i64.load8_s    48 s._mem ;
: s.i64.load8_u    49 s._mem ;
: s.i64.load16_s   50 s._mem ;
: s.i64.load16_u   51 s._mem ;
: s.i64.load32_s   52 s._mem ;
: s.i64.load32_u   53 s._mem ;
: s.i32.store      54 s._mem ;
: s.i64.store      55 s._mem ;
: s.f32.store      56 s._mem ;
: s.f64.store      57 s._mem ;
: s.i32.store8     58 s._mem ;
: s.i32.store16    59 s._mem ;
: s.i64.store8     60 s._mem ;
: s.i64.store16    61 s._mem ;
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

\ vector instructions
\ v128.load - f64x2.promote_low_f32x4



\ encode = lambda s: ' '.join(['0'] + list(map(str, reversed(s.encode()))))

: object._name   \ ( bytes 0 c h a r s -- bytes )
  1 begin dup pick while 1 + repeat \ find end
  dup 1 + pick swap 1 - b%u         \ write len
  begin over while swap b%1 repeat  \ write contents
  drop drop ;

variable object._string.tmp
: object._string   \ ( 0 c h a r s -- addr-in-data )
  object._data-addr object._string.tmp!
  1 begin dup pick while 1 + repeat 1 - \ find len
  object._sec.data
    object._data-addr 8 + b%4           \ write addr
    swap b%4                            \ write len
    begin over while swap b%1 repeat    \ write contents
  drop drop
  object._string.tmp@ ;



object._output
  \ header
  1836278016 b%4 \ magic
  1          b%4 \ version

\ type section
    object._tmp
    12 b%u
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
    1 object._append-section

: l[]        0 b%u ;
: l[i32]     1 b%u 1 b%u s.i32 ;
: l[i64]     1 b%u 1 b%u s.i64 ;
: l[i32,i64] 2 b%u 1 b%u s.i32 1 b%u s.i64 ;

\ import section
    2 constant object._import-count
    object._tmp
    object._import-count b%u

    0 49 119 101 105 118 101 114 112 95 116 111 104 115 112 97 110 115 95 105
    115 97 119 object._name 0 101 116 105 114 119 95 100 102 object._name
    0 b%1 [i32,i32,i32,i32]->[i32] b%u object._func constant
    builtin.fd_write

    0 49 119 101 105 118 101 114 112 95 116 111 104 115 112 97 110 115 95 105
    115 97 119 object._name 0 116 105 120 101 95 99 111 114 112 object._name
    0 b%1 [i32]->[] b%u object._func constant
    builtin.proc_exit

    2 object._append-section

0 constant rt.sp

drop








\ builtins


  object._func constant rt.write
  object._sec.func [i32]->[] b%u drop
  object._tmp
    0 b%u
    2 s.i32.const \ stream=stderr
    0 s.local.get \ const iovec *
    1 s.i32.const \ iovec_size=1
    0 s.i32.const \ size_t *bytes_written
    builtin.fd_write s.call
    s.drop
    s.end
  drop
  object._finish-code

  object._func constant rt.error
  object._sec.func [i32]->[] b%u drop
  object._tmp
    0 b%u
    0        s.local.get
    rt.write s.call
    15       s.i32.const
    builtin.proc_exit s.call
                      s.unreachable
                      s.end
  drop
  object._finish-code

: object._error
  object._string
  s.i32.const rt.error s.call
  s.unreachable ;



  object._func constant rt.stack.load
  object._sec.func [i64]->[i64,i32] b%u drop
  object._tmp
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
    0 119 111 108 102 114 101 118 111 32 107 99 97 116 115 object._error
    s.end
  drop
  object._finish-code

  object._func constant rt.stack.store
  object._sec.func [i64,i32,i32]->[] b%u drop
  object._tmp
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
    s.end
  drop
  object._finish-code

  object._func constant rt.stack.push
  object._sec.func [i64,i32]->[] b%u drop
  object._tmp
    l[]
    rt.sp s.global.get
    32    s.i32.const
          s.i32.le_u
    s.if
      \ stack overflow
      0 119 111 108 102 114 101 118 111 32 107 99 97 116 115 object._error
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
    s.end
  drop
  object._finish-code

  object._func constant rt.stack.push-num
  object._sec.func [i64]->[] b%u drop
  object._tmp
    l[]
    0 s.local.get
    2 s.i32.const
    rt.stack.push s.call
    s.end
  drop
  object._finish-code

  object._func constant rt.stack.push-bool
  object._sec.func [i32]->[] b%u drop
  object._tmp
    l[]
    0 s.i32.const
    0 s.local.get
    s.i32.sub
    s.i64.extend_i32_s
    rt.stack.push-num s.call
    s.end
  drop
  object._finish-code

  object._func constant rt.stack.pop
  object._sec.func []->[i64,i32] b%u drop
  object._tmp
    l[]
    0             s.i64.const
    rt.stack.load s.call
    rt.sp         s.global.get
    10            s.i32.const
                  s.i32.add
    rt.sp         s.global.set
    s.end
  drop
  object._finish-code

  object._func constant rt.stack.pop-num
  object._sec.func []->[i64] b%u drop
  object._tmp
    l[]
    rt.stack.pop s.call
    2 s.i32.const
    s.i32.ne
    s.if
      \ expected number
      0 114 101 98 109 117 110 32 100 101 116 99 101 112 120 101 object._error
    s.end
    s.end
  drop
  object._finish-code

  object._func constant rt.stack.pop-bool
  object._sec.func []->[i32] b%u drop
  object._tmp
    l[]
    rt.stack.pop s.call
                 s.drop
    0            s.i64.const
                 s.i64.ne
    s.end
  drop
  object._finish-code

  object._func constant rt.mem.load
  object._sec.func [i32]->[i64,i32] b%u drop
  object._tmp
    l[]
    0 s.local.get   0 s.i64.load
    0 s.local.get   8 s.i32.load16_u
    0 s.local.tee
    s.i32.eqz
    s.if
      \ uninitialized data
      0 97 116 97 100 32 100 101 122 105 108 97 105 116 105 110 105 110 117
      object._error
    s.end
    0 s.local.get
    s.end
  drop
  object._finish-code

  object._func constant rt.mem.store
  object._sec.func [i64,i32,i32]->[] b%u drop
  object._tmp
    l[]
    2 s.local.get   0 s.local.get   0 s.i64.store
    2 s.local.get   1 s.local.get   8 s.i32.store16
    s.end
  drop
  object._finish-code




: object.init
  object._main
    0 b%u \ locals
  drop
;

: object.finalize

  \ finish main
  object._main s.end drop
  object._sec.func []->[] b%u drop
  object._sec.code
    object._main bytes.length b%u
    object._main bytes.append
  drop
  object._func drop

  object._output

    \ (func ...)* declarations
      object._tmp
      object._funcidx@ object._import-count - b%u
      object._sec.func bytes.append
      3 object._append-section

    \ (memory 4)
      object._tmp
      1 b%u
      0 b%1 4 b%u
      5 object._append-section

    \ (global $sp (mut i32) (i32.const 100032))
      object._tmp
      1 b%u
      s.i32 1 b%1 100032 s.i32.const s.end
      6 object._append-section

    \ (export "memory" (memory 0))
    \ (export "_start" (func ???))
      object._tmp
      2 b%u
      0 121 114 111 109 101 109 object._name 2 b%1 0 b%u
      0 116 114 97 116 115 95 object._name 0 b%1 object._funcidx@ 1 - b%u
      7 object._append-section

    \ (data ...) count
      object._tmp
      1 b%u
      12 object._append-section

    \ (func ...)* code
      object._tmp
      object._funcidx@ object._import-count - b%u
      object._sec.code bytes.append
      10 object._append-section

    \ (data (i32.const 100160) ...)
      object._tmp
      1 b%u
      0 b%1 100160 s.i32.const s.end
      object._sec.data bytes.length b%u
      object._sec.data bytes.append
      11 object._append-section

;



: emit.word.start
  object._sec.func []->[] b%u drop
  object._tmp
  object._func
;

: emit.word.end
  s.end
  drop
  object._finish-code
;



: emit.main.word   object._main swap s.call drop ;
: emit.word.word   object._tmp  swap s.call drop ;
: emit.main.number object._main swap s.i64.const rt.stack.push-num s.call drop ;
: emit.word.number object._tmp  swap s.i64.const rt.stack.push-num s.call drop ;

: emit.type     "type: " . "\n" 0 0 ;

: emit.constant
  object._sec.func []->[] b%u drop
  object._tmp
    l[]
    object._data-addr s.i32.const
    rt.mem.load s.call
    rt.stack.push s.call
    s.end
  drop
  object._finish-code
  object._func

  object._main
    rt.stack.pop s.call
    object._data-addr s.i32.const
    rt.mem.store s.call
  drop

  object._sec.data 0b%10 drop
;

: emit.variable
  object._sec.func []->[] b%u drop
  object._tmp
    l[]
    object._data-addr s.i32.const
    rt.mem.load s.call
    rt.stack.push s.call
    s.end
  drop
  object._finish-code
  object._func

  object._sec.func []->[] b%u drop
  object._tmp
    l[]
    rt.stack.pop s.call
    object._data-addr s.i32.const
    rt.mem.store s.call
    s.end
  drop
  object._finish-code
  object._func

  object._sec.data 0b%10 drop
;

: emit.word.:
  object._sec.func []->[] b%u drop
  object._tmp
    l[]
  drop
  object._func ;

: emit.word.;
  object._tmp
    s.end
  drop
  object._finish-code ;

: emit.word.string
  object._tmp
    object._data-addr s.i32.const
    rt.write s.call
  drop
  object._sec.data
    object._data-addr 8 +   b%4   \ addr
    dup bytes.length -rot 0 b%4   \ len (placeholder)
    swap span.unescape            \ data
    swap object._sec.data   b!4   \ len (fixed up)
;

: emit.word.if   object._tmp rt.stack.pop-bool s.call s.if drop 0 ;
: emit.word.if-else        drop      object._tmp s.else drop 0 ;
: emit.word.if-else-then   drop drop object._tmp s.end  drop   ;
: emit.word.if-then        drop      object._tmp s.end  drop   ;

: emit.word.begin              object._tmp s.loop                        drop 0 ;
: emit.word.while              object._tmp rt.stack.pop-bool s.call s.if drop 0 ;
: emit.word.repeat   drop drop object._tmp 1 s.br s.end s.end            drop ;

: emit.word.exit   object._tmp s.return drop ;






  emit.word.start words.builtin.+ cell.set
    l[]
    rt.stack.pop-num  s.call
    rt.stack.pop-num  s.call
                      s.i64.add
    rt.stack.push-num s.call
  emit.word.end

  emit.word.start words.builtin.- cell.set
    l[i64]
    rt.stack.pop-num s.call
    0                s.local.set
    rt.stack.pop-num s.call
    0                s.local.get
                     s.i64.sub
    rt.stack.push-num s.call
  emit.word.end

  emit.word.start words.builtin.* cell.set
    l[]
    rt.stack.pop-num  s.call
    rt.stack.pop-num  s.call
                      s.i64.mul
    rt.stack.push-num s.call
  emit.word.end

  emit.word.start words.builtin./ cell.set
    l[i64]
    rt.stack.pop-num  s.call
    0                 s.local.tee
    s.i64.eqz
    s.if
      \ division by zero
      0 111 114 101 122 32 121 98 32 110 111 105 115 105 118 105 100 object._error
    s.end
    rt.stack.pop-num  s.call
    0                 s.local.get
                      s.i64.div_u
    rt.stack.push-num s.call
  emit.word.end

  emit.word.start words.builtin.<< cell.set
    l[i64]
    rt.stack.pop-num s.call
    0                s.local.set
    rt.stack.pop-num s.call
    0                s.local.get
                     s.i64.shl
    rt.stack.push-num s.call
  emit.word.end

  emit.word.start words.builtin.>> cell.set
    l[i64]
    rt.stack.pop-num s.call
    0                s.local.set
    rt.stack.pop-num s.call
    0                s.local.get
                     s.i64.shr_u
    rt.stack.push-num s.call
  emit.word.end

  emit.word.start words.builtin.not cell.set
    l[]
    rt.stack.pop-num  s.call
    -1                s.i64.const
                      s.i64.xor
    rt.stack.push-num s.call
  emit.word.end

  emit.word.start words.builtin.and cell.set
    l[]
    rt.stack.pop-num  s.call
    rt.stack.pop-num  s.call
                      s.i64.and
    rt.stack.push-num s.call
  emit.word.end

  emit.word.start words.builtin.or cell.set
    l[]
    rt.stack.pop-num  s.call
    rt.stack.pop-num  s.call
                      s.i64.or
    rt.stack.push-num s.call
  emit.word.end

  emit.word.start words.builtin.xor cell.set
    l[]
    rt.stack.pop-num  s.call
    rt.stack.pop-num  s.call
                      s.i64.xor
    rt.stack.push-num s.call
  emit.word.end

  emit.word.start words.builtin.= cell.set
    l[]
    rt.stack.pop-num   s.call
    rt.stack.pop-num   s.call
                       s.i64.eq
    rt.stack.push-bool s.call
  emit.word.end

  emit.word.start words.builtin.<> cell.set
    l[]
    rt.stack.pop-num   s.call
    rt.stack.pop-num   s.call
                       s.i64.ne
    rt.stack.push-bool s.call
  emit.word.end

  emit.word.start words.builtin.< cell.set
    l[]
    rt.stack.pop-num   s.call
    rt.stack.pop-num   s.call
                       s.i64.gt_u   \ reversed because the Wasm stack is backwards
    rt.stack.push-bool s.call
  emit.word.end

  emit.word.start words.builtin.> cell.set
    l[]
    rt.stack.pop-num   s.call
    rt.stack.pop-num   s.call
                       s.i64.lt_u   \ reversed
    rt.stack.push-bool s.call
  emit.word.end

  emit.word.start words.builtin.<= cell.set
    l[]
    rt.stack.pop-num   s.call
    rt.stack.pop-num   s.call
                       s.i64.ge_u   \ reversed
    rt.stack.push-bool s.call
  emit.word.end

  emit.word.start words.builtin.>= cell.set
    l[]
    rt.stack.pop-num   s.call
    rt.stack.pop-num   s.call
                       s.i64.le_u   \ reversed
    rt.stack.push-bool s.call
  emit.word.end

  emit.word.start words.builtin.dup cell.set
    l[]
    0 s.i64.const
    rt.stack.load s.call
    rt.stack.push s.call
  emit.word.end

  emit.word.start words.builtin.over cell.set
    l[]
    1 s.i64.const
    rt.stack.load s.call
    rt.stack.push s.call
  emit.word.end

  emit.word.start words.builtin.drop cell.set
    l[]
    rt.stack.pop s.call
                 s.drop
                 s.drop
  emit.word.end

  emit.word.start words.builtin.swap cell.set
    l[]
    0 s.i64.const   rt.stack.load  s.call
    1 s.i64.const   rt.stack.load  s.call
    0 s.i32.const   rt.stack.store s.call
    1 s.i32.const   rt.stack.store s.call
  emit.word.end

  emit.word.start words.builtin.nip cell.set
    l[]
    rt.stack.pop  s.call
    rt.stack.pop  s.call   s.drop s.drop
    rt.stack.push s.call
  emit.word.end

  emit.word.start words.builtin.tuck cell.set
    \ a b -- b a b
    l[]

    0 s.i64.const   rt.stack.load s.call
    1 s.i64.const   rt.stack.load s.call
    0 s.i64.const   rt.stack.load s.call
    1 s.i32.const   rt.stack.store s.call
    0 s.i32.const   rt.stack.store s.call
                    rt.stack.push s.call
  emit.word.end

  emit.word.start words.builtin.rot cell.set
    l[]
    0 s.i64.const   rt.stack.load s.call
    1 s.i64.const   rt.stack.load s.call
    2 s.i64.const   rt.stack.load s.call
    0 s.i32.const   rt.stack.store s.call
    2 s.i32.const   rt.stack.store s.call
    1 s.i32.const   rt.stack.store s.call
  emit.word.end

  emit.word.start words.builtin.-rot cell.set
    l[]
    0 s.i64.const   rt.stack.load s.call
    1 s.i64.const   rt.stack.load s.call
    2 s.i64.const   rt.stack.load s.call
    1 s.i32.const   rt.stack.store s.call
    0 s.i32.const   rt.stack.store s.call
    2 s.i32.const   rt.stack.store s.call
  emit.word.end

  emit.word.start words.builtin.pick cell.set
    l[]
    rt.stack.pop-num s.call
    rt.stack.load    s.call
    rt.stack.push    s.call
  emit.word.end

  emit.word.start words.builtin.putc cell.set
    l[i64]
    s.block
      rt.stack.pop-num s.call
      0 s.local.tee
      10 s.i64.const
      s.i64.eq
      0 s.br_if   \ c == '\n'
      0 s.local.get
      32 s.i64.const
      s.i64.ge_u
      0 s.local.get
      126 s.i64.const
      s.i64.le_u
      s.i32.and
      0 s.br_if   \ (' ' <= c) && (c <= '~')
      \ unprintable character
      0 114 101 116 99 97 114 97 104 99 32 101 108 98 97 116 110 105 114 112 110 117
      object._error
    s.end
    0 s.i32.const   8 s.i32.const   0 s.i32.store
    4 s.i32.const   1 s.i32.const   0 s.i32.store
    8 s.i32.const   0 s.local.get   0 s.i64.store8
    0 s.i32.const   rt.write   s.call
  emit.word.end

  emit.word.start words.builtin.. cell.set
    l[i32,i64]
    31 s.i32.const
    0  s.local.tee    \ addr = 31
    32 s.i32.const
    0  s.i32.store8   \ *addr = ' '
    rt.stack.pop-num s.call
    1 s.local.set     \ n = pop_num()
    s.loop            \ do {...} while (n != 0)
      0 s.local.get
      1 s.i32.const
      s.i32.sub
      0 s.local.tee   \   addr -= 1
      1 s.local.get
      10 s.i64.const
      s.i64.rem_u
      48 s.i64.const
      s.i64.add
      0 s.i64.store8  \   *addr = '0' + (n % 10)
      1 s.local.get
      10 s.i64.const
      s.i64.div_u
      1 s.local.tee   \   n = n / 10
      0 s.i64.const
      s.i64.ne
      0 s.br_if
    s.end
    0 s.i32.const
    0 s.local.get
    0 s.i32.store     \ *(0) = addr
    4 s.i32.const
    32 s.i32.const
    0 s.local.get
    s.i32.sub
    0 s.i32.store     \ *(4) = len()
    0 s.i32.const
    rt.write s.call
  emit.word.end

  emit.word.start words.builtin.fail cell.set
    0 b%u
    rt.stack.pop-num  s.call
                      s.i32.wrap_i64
    builtin.proc_exit s.call
  emit.word.end



  emit.word.start words.builtin.bytes.new cell.set
    l[]
  emit.word.end
  emit.word.start words.builtin.bytes.clear cell.set
    l[]
  emit.word.end
  emit.word.start words.builtin.bytes.length cell.set
    l[]
  emit.word.end
  emit.word.start words.builtin.b% cell.set
    l[]
  emit.word.end
  emit.word.start words.builtin.b@ cell.set
    l[]
  emit.word.end
  emit.word.start words.builtin.b! cell.set
    l[]
  emit.word.end
