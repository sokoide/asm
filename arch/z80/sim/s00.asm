; s00: scratch

org 0x0100

_start:
	ld      a, 1
	ld      b, 2
	jp      _sub2

_sub1:
	ld      e, 5
	ld      a, 0
	ret

_sub2:
	ld      c, 3
	ld      d, 4
	jp      _sub1
