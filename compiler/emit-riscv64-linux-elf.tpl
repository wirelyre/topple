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

: emit._cur-addr
  object._section-words bytes.length
  262376 +
;



\ Assembly routines

: s.ra   1 ;
: s.sp   2 ;
: s.s0   8 ;
: s.a0  10 ;
: s.a1  11 ;
: s.a2  12 ;
: s.a7  17 ;
: s.s11 27 ;

: emit.imm12?     2048 +    4095 not and 0 =   ;
: emit.imm20?   524288 + 1048575 not and 0 =   ;

: emit.imm12!
  dup emit.imm12? not if "invalid immediate\n" 14 fail then
  4095 and
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

: s.split
  4294967295 and
  dup 4095 and
  dup 11 >>
  rot 12 >> +
;

: emit._string
  dup 1 + pick
  over b%2 drop
  begin dup while
    dup 1 + pick
    rot swap b%
    1 -
  repeat drop
  begin
    dup bytes.length 3 and
  while
    0 b%1
  repeat
;

: s.ADD   0 0 51 s.R-type   b%4 ;

: s.LD     3   3 s.I-type   b%4 ;
: s.LHU    5   3 s.I-type   b%4 ;
: s.ADDI   0  19 s.I-type   b%4 ;
: s.ANDI   7  19 s.I-type   b%4 ;
: s.JALR   0 103 s.I-type   b%4 ;

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

: s.CALL
  s.split
  2 pick swap s.ra s.LUI drop
  s.ra s.ra s.JALR
;



\ Code generation

object._section-words

  emit._cur-addr constant
emit.prims.print-string
     0        s.a0 s.LI
     2  s.ra  s.a1 s.ADDI
     0  s.ra  s.a2 s.LHU
    64        s.a7 s.LI
  s.a2  s.a1 s.s11 s.ADD
     3 s.s11 s.s11 s.ADDI
 0 4 - s.s11 s.s11 s.ANDI
                   s.ECALL
     0 s.s11     0 s.JALR

drop
object._section-main

  32     s.s0 s.LUI
  231072 s.sp s.LI

  emit.prims.print-string s.CALL
  10 33 100 108 114 111 119 32 44 111 108 108 101 72 14
  emit._string

  42 s.a0 s.LI
  93 s.a7 s.LI
  s.ECALL

drop



\ Object file generation

: object._file-size
  232
  object._section-words bytes.length +
  object._section-main bytes.length +
;

: object.finalize

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
  4096 b%8 \ p_memsz
    0 b%8 \ p_align

  object._section-words bytes.append
  object._section-main  bytes.append

;

object.finalize
bytes.dump
