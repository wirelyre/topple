\ words.tpl
\
\ A hashmap of defined words.
\
\   words             ( -- hashmap )
\
\   words.builtin.+   ( -- cell )
\   words.builtin.-   ( -- cell )
\   (etc)
\
\   words.user        ( span -- cell )
\   words.user.getter ( span -- cell )
\   words.user.setter ( span -- cell )
\   words.user.opener ( span -- cell )
\   words.user.closer ( span -- cell )
\
\ Everything above except 'words' creates a new entry in the map.
\ The 'builtin' words cannot be called more than once.
\
\ The user words create new entries:
\   words.user          =>   (name)
\   words.user.getter   =>   (name)@
\   words.user.setter   =>   (name)!
\   words.user.opener   =>   <(name)
\   words.user.closer   =>   >(name)
\
\ In order to create those names, there is an internal string pool which the
\ provided names are copied to.

hashmap.new constant words

: words.user
  dup words hashmap.find if
    "duplicate word\n" 1 fail
  then
  words hashmap.insert
;



bytes.new   constant words._strpool
            variable words._str
words._strpool span.new words._str!

: words._insert-str
  words._str@
  dup span.rest
  dup span.next words._str!
  words.user
;

: words.user.getter
  words._strpool swap span.b% drop
  64 words._strpool b%
  words._insert-str
;

: words.user.setter
  words._strpool swap span.b% drop
  33 words._strpool b%
  words._insert-str
;

: words.user.opener
  60 words._strpool b%
  words._strpool swap span.b% drop
  words._insert-str
;

: words.user.closer
  62 words._strpool b%
  words._strpool swap span.b% drop
  words._insert-str
;



: words._insert-builtin
  begin dup while
    words._strpool b%
  repeat drop
  words._insert-str
;

: words.builtin.+      0 43                words._insert-builtin ;
: words.builtin.-      0 45                words._insert-builtin ;
: words.builtin.*      0 42                words._insert-builtin ;
: words.builtin./      0 47                words._insert-builtin ;

: words.builtin.<<     0 60 60             words._insert-builtin ;
: words.builtin.>>     0 62 62             words._insert-builtin ;
: words.builtin.not    0 116 111 110       words._insert-builtin ;
: words.builtin.and    0 100 110 97        words._insert-builtin ;
: words.builtin.or     0 114 111           words._insert-builtin ;
: words.builtin.xor    0 114 111 120       words._insert-builtin ;

: words.builtin.=      0 61                words._insert-builtin ;
: words.builtin.<>     0 62 60             words._insert-builtin ;
: words.builtin.<      0 60                words._insert-builtin ;
: words.builtin.>      0 62                words._insert-builtin ;
: words.builtin.<=     0 61 60             words._insert-builtin ;
: words.builtin.>=     0 61 62             words._insert-builtin ;

: words.builtin.dup    0 112 117 100       words._insert-builtin ;
: words.builtin.drop   0 112 111 114 100   words._insert-builtin ;
: words.builtin.swap   0 112 97 119 115    words._insert-builtin ;
: words.builtin.nip    0 112 105 110       words._insert-builtin ;
: words.builtin.tuck   0 107 99 117 116    words._insert-builtin ;
: words.builtin.over   0 114 101 118 111   words._insert-builtin ;
: words.builtin.rot    0 116 111 114       words._insert-builtin ;
: words.builtin.-rot   0 116 111 114 45    words._insert-builtin ;
: words.builtin.pick   0 107 99 105 112    words._insert-builtin ;

: words.builtin..      0 46                words._insert-builtin ;
: words.builtin.putc   0 99 116 117 112    words._insert-builtin ;
: words.builtin.fail   0 108 105 97 102    words._insert-builtin ;

: words.builtin.bytes.new
  0 119 101 110 46 115 101 116 121 98      words._insert-builtin ;
: words.builtin.bytes.clear
  0 114 97 101 108 99 46 115 101 116 121 98   words._insert-builtin ;
: words.builtin.bytes.length
  0 104 116 103 110 101 108 46 115 101 116 121 98   words._insert-builtin ;
: words.builtin.b%     0 37 98             words._insert-builtin ;
: words.builtin.b@     0 64 98             words._insert-builtin ;
: words.builtin.b!     0 33 98             words._insert-builtin ;
: words.builtin.argv   0 118 103 114 97    words._insert-builtin ;
: words.builtin.file.read
  0 100 97 101 114 46 101 108 105 102      words._insert-builtin ;
: words.builtin.file.write
  0 101 116 105 114 119 46 101 108 105 102   words._insert-builtin ;

: words.builtin.block.new
  0 119 101 110 46 107 99 111 108 98       words._insert-builtin ;
: words.builtin.@      0 64                words._insert-builtin ;
: words.builtin.!      0 33                words._insert-builtin ;
: words.builtin.+p     0 112 43            words._insert-builtin ;
