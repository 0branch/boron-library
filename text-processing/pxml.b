#!/usr/bin/boron -s
; Process XML v1.0.1

usage: {{
    Usage: pxml [OPTIONS] <xml-file>

    Options:
      -c    Do not convert tags to boron word! & paren! values.
      -f    Keep tag list flat; do not nest.
      -h    Print this help and quit.
      -i    Follow xi:include tags.
}}

boronify: true
follow-include: false
keep-flat: false
file: none

forall args [
    switch first args [
        "-c" [boronify: false]
        "-f" [keep-flat: true]
        "-h" [print usage quit]
        "-i" [follow-include: true]
        [file: first args]
    ]
]
ifn file [
    print usage
    quit/return 64
]

xml-processor: context [
    items: none
    close-tag: "/>"

    dt-stuff: complement charset "[>"
    doctype: [
        "DOCTYPE" some dt-stuff ['[' thru ']' | any dt-stuff] '>'
    ]

    ; Create flat string! list of tags and content.
    set 'flat-xml func [file] [
        items: make block! 64
        parse read/text file [some[
            tok:
            '<' [
                '!' ["--" thru "-->" | doctype | thru '>']
              | thru '>' :tok (append items mark-sol tok)
            ]
          | to '<' :tok (
                ifn zero? size? tt: trim tok [
                    append items mark-sol tt
                ]
            )
        ]]
        items
    ]

    set 'expand-include func [list /local it] [
        lcopy: make block! size? list
        foreach it list [
            either all [
                eq? "<xi:include" slice it 11
                parse it [thru {href="} file: to '"' :file thru close-tag]
            ][
                append lcopy expand-include flat-xml file
            ][
                append lcopy it
            ]
        ]
        lcopy
    ]

    new-block: does [make block! 16]

    set 'nest-tags func [list /local it] [
        lcopy: cblk: new-block
        stack: new-block
        foreach it list [
            case [
                eq? "</" slice it 2 [pop stack cblk: last stack]
                all [
                    eq? '<' first it
                    ne? '?' second it
                    ne? '/' pick tail it -2
                ][
                    append/block append cblk it newb: new-block
                    append/block stack cblk: newb
                ]
                true [append cblk it]
            ]
        ]
        lcopy
    ]

    paren: make paren! 16
    name-term:  charset " />"
    digits:     charset "0-9"
    word-chars: charset "a-z0-9_?!"

    to-boron: func [tag blk] [
        clear paren
        parse tag [
            '<' n: to name-term :n skip (
                if name-space: find n ':' [n: next name-space]
                append blk mark-sol to-word trim n
            )
            any [
                n: to '=' :n skip (
                    if name-space: find n ':' [n: next name-space]
                    append paren to-set-word trim n
                )
                '"' v: [
                    some digits     '"' :v (append paren to-int v)
                  | some word-chars '"' :v (append paren to-word slice v -1)
                  | to '"' :v skip         (append paren v)
                ]
            ]
        ]
        ifn empty? paren [
            append/block blk copy paren
        ]
    ]

    set 'nest-to-boron func [list /local it] [
        lcopy: cblk: new-block
        stack: new-block
        foreach it list [
            case [
                eq? "</" s2: slice it 2 [pop stack cblk: last stack]
                eq? "<?" s2 []          ; Drop <?xml ?>
                eq? '<' first it [
                    to-boron it cblk
                    if ne? '/' pick tail it -2 [
                        append/block cblk newb: new-block
                        append/block stack cblk: newb
                    ]
                ]
                true [append cblk it]
            ]
        ]
        lcopy
    ]
]

top: flat-xml file
if follow-include [
    top: expand-include top
]
ifn keep-flat [
    top: either boronify [
        nest-to-boron top
    ][
        nest-tags top
    ]
]
print mold/contents top
