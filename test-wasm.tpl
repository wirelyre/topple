bytes.new constant filename
bytes.new constant contents

\ tmp
filename
    116 over b%
    109 over b%
    112 over b%
drop

\ README.md
contents
     82 over b%
     69 over b%
     65 over b%
     68 over b%
     77 over b%
     69 over b%
     46 over b%
    109 over b%
    100 over b%
drop

\ src/simple.py
filename
    115 over b% 
    114 over b% 
     99 over b% 
     47 over b% 
    115 over b% 
    105 over b% 
    109 over b% 
    112 over b% 
    108 over b% 
    101 over b% 
     46 over b% 
    112 over b% 
    121 over b%
drop

contents filename file.write .

10 putc
