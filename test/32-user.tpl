\ OK -- 1 1 2 2 

type ty1
type ty2

block.new constant ptr

1 ptr !

ptr >ty1 <ty1 @ . \ 1
ptr >ty2 <ty2 @ . \ 1

ptr >ty1 ptr 1 +p !
ptr >ty2 ptr 2 +p !

2 ptr !

ptr 1 +p @ <ty1 @ . \ 2
ptr 2 +p @ <ty2 @ . \ 2
