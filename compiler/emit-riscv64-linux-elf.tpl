\ emit-riscv64-linux-elf.tpl
\
\ Implementation of 'emit' interface that produces ELF object files.
\
\ This uses two code sections: one for word definitions, and one for top-level
\ "main" code.  Constants and variables are kept in a data section.

bytes.new constant object._section-words
bytes.new constant object._section-main
bytes.new constant object._file

64   56 3 *   +   constant object._header-size

: emit._cur-offset object._section-words bytes.length ;
: emit._cur-addr   emit._cur-offset 262376 + ;
: emit._rel        emit._cur-addr - ;

variable emit._data-pointer
268435456 emit._data-pointer!



\ Assembly routines

: s.ra   1 ;
: s.sp   2 ;
: s.t0   5 ;
: s.t1   6 ;
: s.t2   7 ;
: s.s0   8 ;
: s.a0  10 ;
: s.a1  11 ;
: s.a2  12 ;
: s.a7  17 ;
: s.s11 27 ;
: s.t3  28 ;
: s.t4  29 ;
: s.t5  30 ;

: emit.imm12?     2048 +    4095 not and 0 =   ;
: emit.imm20?   524288 + 1048575 not and 0 =   ;

: emit.imm12!
  dup emit.imm12? not if "invalid immediate\n" 14 fail then
  4095 and
;
: emit.imm13!
  dup 1 and if "invalid immediate\n" 14 fail then
  dup 4096 + 8191 not and 0 <> if "invalid immediate\n" 14 fail then
  8191 and
;
: emit.imm20!
  dup emit.imm20? not if "invalid immediate\n" 14 fail then
  1048575 and
;

: s.R-type
  swap 12 << or
  swap 25 << or
  swap  7 << or
  swap 15 << or
  swap 20 << or
;

: s.I-type
  swap 12 << or
  swap  7 << or
  swap 15 << or
  swap emit.imm12! 20 << or
;

: s.S-type
  swap 12 << or
  swap 15 << or
  swap 20 << or
  swap emit.imm12!
  dup 4064 and 20 <<
  swap  31 and  7 <<
  or or
;

: s.B-type
  swap 12 << or
  swap 15 << or
  swap 20 << or
  swap emit.imm13!
  dup 4096 and 19 << swap
  dup 2016 and 20 << swap
  dup   30 and  7 << swap
      2048 and  4 >>
  or or or or
;

: s.split
  4294967295 and
  dup 4095 and
  dup 11 >>
  rot 12 >> +
;

: emit._align-4
  begin
    dup bytes.length 3 and
  while
    0 b%1
  repeat
;

: emit._string
  dup 1 + pick
  over b%2 drop
  begin dup while
    dup 1 + pick
    rot swap b%
    1 -
  repeat drop
  emit._align-4
;

: s.ADD    0 0 51 s.R-type   b%4 ;
: s.SUB   32 0 51 s.R-type   b%4 ;
: s.SLL    0 1 51 s.R-type   b%4 ;
: s.SLT    0 2 51 s.R-type   b%4 ;
: s.SLTU   0 3 51 s.R-type   b%4 ;
: s.XOR    0 4 51 s.R-type   b%4 ;
: s.SRL    0 5 51 s.R-type   b%4 ;
: s.SRA   32 5 51 s.R-type   b%4 ;
: s.OR     0 6 51 s.R-type   b%4 ;
: s.AND    0 7 51 s.R-type   b%4 ;
: s.MUL    1 0 51 s.R-type   b%4 ;
: s.DIVU   1 5 51 s.R-type   b%4 ;
: s.REMU   1 7 51 s.R-type   b%4 ;

: s.LB      0   3 s.I-type   b%4 ;
: s.LH      1   3 s.I-type   b%4 ;
: s.LW      2   3 s.I-type   b%4 ;
: s.LD      3   3 s.I-type   b%4 ;
: s.LBU     4   3 s.I-type   b%4 ;
: s.LHU     5   3 s.I-type   b%4 ;
: s.LWU     6   3 s.I-type   b%4 ;
: s.ADDI    0  19 s.I-type   b%4 ;
: s.SLTI    2  19 s.I-type   b%4 ;
: s.SLTIU   3  19 s.I-type   b%4 ;
: s.XORI    4  19 s.I-type   b%4 ;
: s.ORI     6  19 s.I-type   b%4 ;
: s.ANDI    7  19 s.I-type   b%4 ;
: s.JALR    0 103 s.I-type   b%4 ;

: s.SB      0  35 s.S-type   b%4 ;
: s.SH      1  35 s.S-type   b%4 ;
: s.SW      2  35 s.S-type   b%4 ;
: s.SD      3  35 s.S-type   b%4 ;

: s.BEQ     0  99 s.B-type   b%4 ;
: s.BNE     1  99 s.B-type   b%4 ;
: s.BLT     4  99 s.B-type   b%4 ;
: s.BGE     5  99 s.B-type   b%4 ;
: s.BLTU    6  99 s.B-type   b%4 ;
: s.BGEU    7  99 s.B-type   b%4 ;

: s.ECALL 115 b%4 ;

: s.LUI
  55
  swap 7 << or
  swap emit.imm20! 12 << or
  b%4
;

: s.SRAI
  rot
  dup 64 >= if "invalid shift amount\n" 14 fail then
  1024 or -rot
  5 19 s.I-type
  b%4
;

: s.JAL
  7 << 111 or
  over 1048576 and 11 << or
  over 2046 and 20 << or
  over 2048 and 9 << or
  swap 1044480 and or
  b%4
;

: s.LI
  over emit.imm12? if 0 swap s.ADDI exit then
  over emit.imm20? if
    -rot 2 pick s.LUI
    12 rot dup s.SRAI
    exit
  then
  2 pick   12   2 pick   s.JAL drop
  -rot b%8
  0 rot dup s.LD
;

: s.JMP
  s.split
  2 pick swap s.ra s.LUI drop
  s.ra 0 s.JALR
;
: s.CALL
  s.split
  2 pick swap s.ra s.LUI drop
  s.ra s.ra s.JALR
;
: s.CALL.t0
  s.split
  2 pick swap s.t0 s.LUI drop
  s.t0 s.t0 s.JALR
;

: emit._patch-jump
  s.split
  12 <<   183 or   2 pick     object._section-words b!4   \ LUI
  20 << 32871 or   swap 4 +   object._section-words b!4   \ JALR
;



\ Primitive words and subroutines

object._section-words

\ print string
    emit._cur-addr constant emit.prims.print-string
         0        s.a0 s.LI
         2  s.ra  s.a1 s.ADDI
         0  s.ra  s.a2 s.LHU
        64        s.a7 s.LI
      s.a2  s.a1 s.s11 s.ADD
         3 s.s11 s.s11 s.ADDI
     0 4 - s.s11 s.s11 s.ANDI
                       s.ECALL
         0 s.s11     0 s.JALR

\ error: stack underflow
    emit._cur-addr constant emit.prims.fail.stack-underflow
      emit.prims.print-string s.CALL
      10 119 111 108 102 114 101 100 110 117 32 107 99 97 116 115 16
      emit._string
      15 s.a0 s.LI
      93 s.a7 s.LI
      s.ECALL

\ error: stack overflow
    emit._cur-addr constant emit.prims.fail.stack-overflow
      emit.prims.print-string s.CALL
      10 119 111 108 102 114 101 118 111 32 107 99 97 116 115 15
      emit._string
      15 s.a0 s.LI
      93 s.a7 s.LI
      s.ECALL

\ error: expected number
    emit._cur-addr constant emit.prims.fail.expected-number
      emit.prims.print-string s.CALL
      10 114 101 98 109 117 110 32 100 101 116 99 101 112 120 101 16
      emit._string
      15 s.a0 s.LI
      93 s.a7 s.LI
      s.ECALL

\ error: division by zero
    emit._cur-addr constant emit.prims.fail.division-by-zero
      emit.prims.print-string s.CALL
      10 111 114 101 122 32 121 98 32 110 111 105 115 105 118 105 100 17
      emit._string
      15 s.a0 s.LI
      93 s.a7 s.LI
      s.ECALL

\ error: uninitialized data
    emit._cur-addr constant emit.prims.fail.uninitialized-data
      emit.prims.print-string s.CALL
      10 97 116 97 100 32 100 101 122 105 108 97 105 116 105 110 105 110 117
        19 emit._string
      15 s.a0 s.LI
      93 s.a7 s.LI
      s.ECALL

\ error: unprintable character
    emit._cur-addr constant emit.prims.fail.unprintable-character
      emit.prims.print-string s.CALL
      10 114 101 116 99 97 114 97 104 99 32 101 108 98 97 116 110 105 114 112
        110 117 22 emit._string
      15 s.a0 s.LI
      93 s.a7 s.LI
      s.ECALL

\ pop anything
    emit._cur-addr constant emit.prims.pop-any
      32 s.t1 s.LUI
      emit.prims.fail.stack-underflow emit._rel
        s.s0 s.t1 s.BGEU
      0 10 - s.s0 s.s0 s.ADDI
      0 s.s0 s.a0 s.LD
      8 s.s0 s.a1 s.LHU
      0 s.t0 0 s.JALR

\ pop number
    emit._cur-addr constant emit.prims.pop-num
      32 s.t1 s.LUI
      emit.prims.fail.stack-underflow emit._rel
        s.s0 s.t1 s.BGEU
      0 10 - s.s0 s.s0 s.ADDI
      0 s.s0 s.a0 s.LD
      8 s.s0 s.t1 s.LHU
      2 s.t2 s.LI
      emit.prims.fail.expected-number emit._rel
        s.t2 s.t1 s.BNE
      0 s.t0 0 s.JALR

\ pop two numbers
    emit._cur-addr constant emit.prims.pop-2-nums
      0 s.t0 s.t3 s.ADDI
      emit.prims.pop-num s.CALL.t0
      0 s.a0 s.a1 s.ADDI
      emit.prims.pop-num s.CALL.t0
      0 s.t3 0 s.JALR

\ push number
    emit._cur-addr constant emit.prims.push-num
      2 s.a1 s.LI
      \ fall through

\ push anything
    emit._cur-addr constant emit.prims.push-any
      231072 s.t1 s.LI
      emit.prims.fail.stack-overflow emit._rel
        s.t1 s.s0 s.BGEU
      0 s.a0 s.s0 s.SD
      8 s.a1 s.s0 s.SH
      10 s.s0 s.s0 s.ADDI
      0 s.t0 0 s.JALR

\ get from address
    emit._cur-addr constant emit.prims.get
      8 s.a0 s.a1 s.LHU
      0 s.a0 s.a0 s.LD
      emit.prims.fail.uninitialized-data emit._rel
        s.a1 0 s.BEQ
      0 s.t0 0 s.JALR

\ set at address
    emit._cur-addr constant emit.prims.set
      0 s.a0 s.a2 s.SD
      8 s.a1 s.a2 s.SH
      0 s.t0 0 s.JALR

\ +
    emit._cur-addr words.builtin.+ cell.set
      emit.prims.pop-2-nums s.CALL.t0
      s.a1 s.a0 s.a0 s.ADD
      emit.prims.push-num s.CALL.t0
      0 s.ra 0 s.JALR

\ -
    emit._cur-addr words.builtin.- cell.set
      emit.prims.pop-2-nums s.CALL.t0
      s.a1 s.a0 s.a0 s.SUB
      emit.prims.push-num s.CALL.t0
      0 s.ra 0 s.JALR

\ *
    emit._cur-addr words.builtin.* cell.set
      emit.prims.pop-2-nums s.CALL.t0
      s.a1 s.a0 s.a0 s.MUL
      emit.prims.push-num s.CALL.t0
      0 s.ra 0 s.JALR

\ /
    emit._cur-addr words.builtin./ cell.set
      emit.prims.pop-2-nums s.CALL.t0
      emit.prims.fail.division-by-zero emit._rel
        s.a1 0 s.BEQ
      s.a1 s.a0 s.a0 s.DIVU
      emit.prims.push-num s.CALL.t0
      0 s.ra 0 s.JALR

\ <<
    emit._cur-addr words.builtin.<< cell.set
      emit.prims.pop-2-nums s.CALL.t0
      s.a1 s.a0 s.a0 s.SLL
      emit.prims.push-num s.CALL.t0
      0 s.ra 0 s.JALR

\ >>
    emit._cur-addr words.builtin.>> cell.set
      emit.prims.pop-2-nums s.CALL.t0
      s.a1 s.a0 s.a0 s.SRL
      emit.prims.push-num s.CALL.t0
      0 s.ra 0 s.JALR

\ not
    emit._cur-addr words.builtin.not cell.set
      emit.prims.pop-num s.CALL.t0
      0 1 - s.a0 s.a0 s.XORI
      emit.prims.push-num s.CALL.t0
      0 s.ra 0 s.JALR

\ and
    emit._cur-addr words.builtin.and cell.set
      emit.prims.pop-2-nums s.CALL.t0
      s.a1 s.a0 s.a0 s.AND
      emit.prims.push-num s.CALL.t0
      0 s.ra 0 s.JALR

\ or
    emit._cur-addr words.builtin.or cell.set
      emit.prims.pop-2-nums s.CALL.t0
      s.a1 s.a0 s.a0 s.OR
      emit.prims.push-num s.CALL.t0
      0 s.ra 0 s.JALR

\ xor
    emit._cur-addr words.builtin.xor cell.set
      emit.prims.pop-2-nums s.CALL.t0
      s.a1 s.a0 s.a0 s.XOR
      emit.prims.push-num s.CALL.t0
      0 s.ra 0 s.JALR

\ =
    emit._cur-addr words.builtin.= cell.set
      emit.prims.pop-2-nums s.CALL.t0
      s.a1 s.a0 s.a0 s.SUB
      1 s.a0 s.a0 s.SLTIU
      s.a0 0 s.a0 s.SUB
      emit.prims.push-num s.CALL.t0
      0 s.ra 0 s.JALR

\ <>
    emit._cur-addr words.builtin.<> cell.set
      emit.prims.pop-2-nums s.CALL.t0
      s.a1 s.a0 s.a0 s.SUB
      s.a0 0 s.a0 s.SLTU
      s.a0 0 s.a0 s.SUB
      emit.prims.push-num s.CALL.t0
      0 s.ra 0 s.JALR

\ <
    emit._cur-addr words.builtin.< cell.set
      emit.prims.pop-2-nums s.CALL.t0
      s.a1 s.a0 s.a0 s.SLTU
      s.a0 0 s.a0 s.SUB
      emit.prims.push-num s.CALL.t0
      0 s.ra 0 s.JALR

\ >
    emit._cur-addr words.builtin.> cell.set
      emit.prims.pop-2-nums s.CALL.t0
      s.a0 s.a1 s.a0 s.SLTU
      s.a0 0 s.a0 s.SUB
      emit.prims.push-num s.CALL.t0
      0 s.ra 0 s.JALR

\ <=
    emit._cur-addr words.builtin.<= cell.set
      emit.prims.pop-2-nums s.CALL.t0
      s.a0 s.a1 s.a0 s.SLTU
      1 s.a0 s.a0 s.XORI
      s.a0 0 s.a0 s.SUB
      emit.prims.push-num s.CALL.t0
      0 s.ra 0 s.JALR

\ >=
    emit._cur-addr words.builtin.>= cell.set
      emit.prims.pop-2-nums s.CALL.t0
      s.a1 s.a0 s.a0 s.SLTU
      1 s.a0 s.a0 s.XORI
      s.a0 0 s.a0 s.SUB
      emit.prims.push-num s.CALL.t0
      0 s.ra 0 s.JALR

\ dup
    emit._cur-addr words.builtin.dup cell.set
      131082 s.t0 s.LI
      emit.prims.fail.stack-underflow emit._rel
        s.t0 s.s0 s.BLT
      231072 s.t1 s.LI
      emit.prims.fail.stack-overflow emit._rel
        s.t1 s.s0 s.BGEU
      0 10 - s.s0 s.t0 s.LD
      0  2 - s.s0 s.t1 s.LHU
      0 s.t0 s.s0 s.SD
      8 s.t1 s.s0 s.SH
      10 s.s0 s.s0 s.ADDI
      0 s.ra 0 s.JALR

\ drop
    emit._cur-addr words.builtin.drop cell.set
      131082 s.t0 s.LI
      emit.prims.fail.stack-underflow emit._rel
        s.t0 s.s0 s.BLT
      0 10 - s.s0 s.s0 s.ADDI
      0 s.ra 0 s.JALR

\ swap
    emit._cur-addr words.builtin.swap cell.set
      131092 s.t0 s.LI
      emit.prims.fail.stack-underflow emit._rel
        s.t0 s.s0 s.BLT
      0 20 - s.s0 s.t0 s.LD
      0 12 - s.s0 s.t1 s.LHU
      0 10 - s.s0 s.t2 s.LD
      0  2 - s.s0 s.t3 s.LHU
      0 20 - s.t2 s.s0 s.SD
      0 12 - s.t3 s.s0 s.SH
      0 10 - s.t0 s.s0 s.SD
      0  2 - s.t1 s.s0 s.SH
      0 s.ra 0 s.JALR

\ nip
    emit._cur-addr words.builtin.nip cell.set
      131092 s.t0 s.LI
      emit.prims.fail.stack-underflow emit._rel
        s.t0 s.s0 s.BLT
      0 10 - s.s0 s.t0 s.LD
      0  2 - s.s0 s.t1 s.LHU
      0 20 - s.t0 s.s0 s.SD
      0 12 - s.t1 s.s0 s.SH
      0 10 - s.s0 s.s0 s.ADDI
      0 s.ra 0 s.JALR

\ tuck
    emit._cur-addr words.builtin.tuck cell.set
      131092 s.t0 s.LI
      emit.prims.fail.stack-underflow emit._rel
        s.t0 s.s0 s.BLT
      231072 s.t1 s.LI
      emit.prims.fail.stack-overflow emit._rel
        s.t1 s.s0 s.BGEU
      0 20 - s.s0 s.t0 s.LD
      0 12 - s.s0 s.t1 s.LHU
      0 10 - s.s0 s.t2 s.LD
      0  2 - s.s0 s.t3 s.LHU
      0 20 - s.t2 s.s0 s.SD
      0 12 - s.t3 s.s0 s.SH
      0 10 - s.t0 s.s0 s.SD
      0  2 - s.t1 s.s0 s.SH
           0 s.t2 s.s0 s.SD
           8 s.t3 s.s0 s.SH
      10 s.s0 s.s0 s.ADDI
      0 s.ra 0 s.JALR

\ over
    emit._cur-addr words.builtin.over cell.set
      131092 s.t0 s.LI
      emit.prims.fail.stack-underflow emit._rel
        s.t0 s.s0 s.BLT
      231072 s.t1 s.LI
      emit.prims.fail.stack-overflow emit._rel
        s.t1 s.s0 s.BGEU
      0 20 - s.s0 s.t0 s.LD
      0 12 - s.s0 s.t1 s.LHU
      0 s.t0 s.s0 s.SD
      8 s.t1 s.s0 s.SH
      10 s.s0 s.s0 s.ADDI
      0 s.ra 0 s.JALR

\ rot
    emit._cur-addr words.builtin.rot cell.set
      131102 s.t0 s.LI
      emit.prims.fail.stack-underflow emit._rel
        s.t0 s.s0 s.BLT
      0 30 - s.s0 s.t0 s.LD
      0 22 - s.s0 s.t1 s.LHU
      0 20 - s.s0 s.t2 s.LD
      0 12 - s.s0 s.t3 s.LHU
      0 10 - s.s0 s.t4 s.LD
      0  2 - s.s0 s.t5 s.LHU
      0 30 - s.t2 s.s0 s.SD
      0 22 - s.t3 s.s0 s.SH
      0 20 - s.t4 s.s0 s.SD
      0 12 - s.t5 s.s0 s.SH
      0 10 - s.t0 s.s0 s.SD
      0  2 - s.t1 s.s0 s.SH
      0 s.ra 0 s.JALR

\ -rot
    emit._cur-addr words.builtin.-rot cell.set
      131102 s.t0 s.LI
      emit.prims.fail.stack-underflow emit._rel
        s.t0 s.s0 s.BLT
      0 30 - s.s0 s.t0 s.LD
      0 22 - s.s0 s.t1 s.LHU
      0 20 - s.s0 s.t2 s.LD
      0 12 - s.s0 s.t3 s.LHU
      0 10 - s.s0 s.t4 s.LD
      0  2 - s.s0 s.t5 s.LHU
      0 30 - s.t4 s.s0 s.SD
      0 22 - s.t5 s.s0 s.SH
      0 20 - s.t0 s.s0 s.SD
      0 12 - s.t1 s.s0 s.SH
      0 10 - s.t2 s.s0 s.SD
      0  2 - s.t3 s.s0 s.SH
      0 s.ra 0 s.JALR

\ pick
    emit._cur-addr words.builtin.pick cell.set
      emit.prims.pop-num s.CALL.t0
      32 s.t0 s.LUI
      s.t0 s.s0 s.t0 s.SUB
      10 s.t1 s.LI
      s.t1 s.t0 s.t0 s.DIVU
      emit.prims.fail.stack-underflow emit._rel
        s.t0 s.a0 s.BGEU
      1 s.a0 s.a0 s.ADDI
      s.t1 s.a0 s.a0 s.MUL
      s.a0 s.s0 s.a0 s.SUB
      emit.prims.get s.CALL.t0
      emit.prims.push-any s.CALL.t0
      0 s.ra 0 s.JALR

\ .
    emit._cur-addr words.builtin.. cell.set
      0 s.ra s.s11 s.ADDI

      emit.prims.pop-num s.CALL.t0
      0 s.a0 s.t0 s.ADDI
      32 s.t1 s.LI
      10 s.t2 s.LI
      0 s.a0 s.LI
      20 s.sp s.a1 s.ADDI
      1 s.a2 s.LI
      0 s.t1 s.a1 s.SB

      s.t2 s.t0 s.t3 s.DIVU
      s.t2 s.t0 s.t4 s.REMU
      0 1 - s.a1 s.a1 s.ADDI
      1 s.a2 s.a2 s.ADDI
      0 s.t3 s.t0 s.ADDI
      48 s.t4 s.t1 s.ADDI
      0 s.t1 s.a1 s.SB

      0 28 - 0 s.t0 s.BNE

      64 s.a7 s.LI
      s.ECALL
      0 s.s11 0 s.JALR

\ putc
    emit._cur-addr words.builtin.putc cell.set
      0 s.ra s.s11 s.ADDI
      emit.prims.pop-num s.CALL.t0
      10 s.t0 s.LI
      20 s.t0 s.a0 s.BEQ
      32 s.t0 s.LI
      emit.prims.fail.unprintable-character emit._rel
        s.t0 s.a0 s.BLTU
      127 s.t0 s.LI
      emit.prims.fail.unprintable-character emit._rel
        s.t0 s.a0 s.BGEU
      0 s.a0 s.LI
      0 s.s0 s.a1 s.ADDI
      1 s.a2 s.LI
      64 s.a7 s.LI
      s.ECALL
      0 s.s11 0 s.JALR

\ fail
    emit._cur-addr words.builtin.fail cell.set
      emit.prims.pop-num s.CALL.t0
      93 s.a7 s.LI
      s.ECALL

drop



\ Object file generation

: object.init
  object._section-main
    32     s.s0 s.LUI
    231072 s.sp s.LI
  drop
;

: object._file-size
  232
  object._section-words bytes.length +
  object._section-main bytes.length +
;

: object.finalize

  object._section-main
    0 s.a0 s.LI
    93 s.a7 s.LI
    s.ECALL
  drop

  object._file

  \ magic
  127 b%1
   69 b%1
   76 b%1
   70 b%1

    2 b%1 \ EI_CLASS = ELFCLASS64
    1 b%1 \ EI_DATA = ELFDATA2LSB
    1 b%1 \ EI_VERSION = 1 (current)
    3 b%1 \ EI_OSABI = Linux
    0 b%8 \ padding

    2 b%2 \ e_type = ET_EXEC
  243 b%2 \ e_machine = EM_RISCV
    1 b%4 \ e_version = 1

  emit._cur-addr b%8 \ e_entry
   64 b%8 \ e_phoff
    0 b%8 \ e_shoff
    0 b%4 \ e_flags
   64 b%2 \ e_ehsize
   56 b%2 \ e_phentsize
    3 b%2 \ e_phnum
   64 b%2 \ e_shentsize
    0 b%2 \ e_shnum
    0 b%2 \ e_shstrndx

  \ Program header entry 1 (stacks)
    1 b%4 \ p_type = PT_LOAD
    6 b%4 \ p_flags = PF_W | PF_R
    0 b%8 \ p_offset
  131072 b%8 \ p_vaddr
    0 b%8 \ p_paddr
    0 b%8 \ p_filesz
  131072 b%8 \ p_memsz
    0 b%8 \ p_align

  \ Program header entry 2 (code)
    1 b%4 \ p_type = PT_LOAD
    5 b%4 \ p_flags = PF_X | PF_R
    0 b%8 \ p_offset
  262144 b%8 \ p_vaddr
    0 b%8 \ p_paddr
    object._file-size b%8 \ p_filesz
    object._file-size b%8 \ p_memsz
    0 b%8 \ p_align

  \ Program header entry 3 (data)
    1 b%4 \ p_type = PT_LOAD
    6 b%4 \ p_flags = PF_W | PF_R
    0 b%8 \ p_offset
  268435456 b%8 \ p_vaddr
    0 b%8 \ p_paddr
    0 b%8 \ p_filesz
  emit._data-pointer@ 268435456 - b%8 \ p_memsz
    0 b%8 \ p_align

  object._section-words bytes.append
  object._section-main  bytes.append

;



\ Code generation

: emit.main.word
  object._section-main swap
    s.CALL
  drop
;
: emit.main.number
  object._section-main swap
    s.a0 s.LI
    emit.prims.push-num s.CALL.t0
  drop
;

: emit.type TODO ;

: emit.constant
  emit._cur-addr
  object._section-words
    emit._data-pointer@ s.a0 s.LI
    emit.prims.get s.CALL.t0
    emit.prims.push-any s.CALL.t0
    0 s.ra 0 s.JALR
  drop

  object._section-main
    emit.prims.pop-any s.CALL.t0
    emit._data-pointer@ s.a2 s.LI
    emit.prims.set s.CALL.t0
  drop

  emit._data-pointer@ 10 +
  emit._data-pointer!
;

: emit.variable
  object._section-words
    emit._cur-addr swap
    emit._data-pointer@ s.a0 s.LI
    emit.prims.get s.CALL.t0
    emit.prims.push-any s.CALL.t0
    0 s.ra 0 s.JALR

    emit._cur-addr swap
    emit.prims.pop-any s.CALL.t0
    emit._data-pointer@ s.a2 s.LI
    emit.prims.set s.CALL.t0
    0 s.ra 0 s.JALR
  drop

  emit._data-pointer@ 10 +
  emit._data-pointer!
;

: emit.word.:
  emit._cur-addr
  object._section-words
    0 s.ra s.sp s.SD
    8 s.sp s.sp s.ADDI
  drop
;
: emit.word.;
  object._section-words
    0 8 - s.sp s.sp s.ADDI
    0 s.sp s.ra s.LD
    0 s.ra 0 s.JALR
  drop
;

: emit.word.word
  object._section-words swap
    s.CALL
  drop
;
: emit.word.number
  object._section-words swap
    s.a0 s.LI
    emit.prims.push-num s.CALL.t0
  drop
;

: emit.word.string
  object._section-words
    emit.prims.print-string s.CALL
    0 b%2
  swap span.unescape
  emit._cur-offset over - 2 -
  object._section-words b!2
  object._section-words emit._align-4 drop
;

: emit.word.if
  object._section-words
    emit.prims.pop-any s.CALL.t0
    12 s.a0 0 s.BNE
    emit._cur-offset swap
    0 b%8
  drop
;
: emit.word.if-else
  emit._cur-offset swap
  object._section-words 0 b%8 drop
  emit._cur-addr emit._patch-jump
;
: emit.word.if-else-then
  emit._cur-addr emit._patch-jump
  drop
;
: emit.word.if-then
  emit._cur-addr emit._patch-jump
;

: emit.word.begin
  emit._cur-addr
;
: emit.word.while
  object._section-words
    emit.prims.pop-any s.CALL.t0
    12 s.a0 0 s.BNE
    emit._cur-offset swap
    0 b%8
  drop
;
: emit.word.repeat
  object._section-words rot s.JMP drop
  emit._cur-addr emit._patch-jump
;

: emit.word.exit emit.word.; ;
