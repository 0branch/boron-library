#!/usr/bin/boron
; Dice Sheet Generator v1.0


dice: [20 20 20 20 12 10 10 8 8 8 6 6 3,6 3,6 4 4]
rows: 40

if args [
    ifn parse args [
        some [
            "-d" set dice string! (dice: to-block dice)
          | "-r" set rows string! (rows: to-int rows)
        ]
    ][
        print "Usage: dice-sheet [-d <dice>] [-r <rows>]^/"
        quit/return 64
    ]
]

hd: ""
hr: ""
ln: ""
cs: "    "
hcs: skip cs 2

prev-d: none
foreach d dice [
    either ne? d prev-d [
        if prev-d [
            append hr cs
        ]
        prev-d: d

        ; Column Header
        str: either coord? d
            [rejoin [first d 'd' second d]]
            [join "d" d]
        append hd str
        append hd skip "      " size? str
    ][
        append hd "    "
        append hr "--"
    ]
    append hr "--"
]

print hd
print hr

random/seed to-decimal now
loop rows [
    clear ln
    prev-d: first dice
    foreach d dice [
        either coord? d [
            v: second d
            roll: 0
            loop first d [
                roll: add roll random v
            ]
        ][
            roll: random d
        ]
        if ne? d prev-d [
            prev-d: d
            append ln hcs
        ]
        if lt? roll 10 [append ln ' ']
        append append ln roll hcs
    ]
    print ln
]

print hr
