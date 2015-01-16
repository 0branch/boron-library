#!/usr/bin/boron -s
/*
    dpatch v0.6
    Patch directory using tar and xdelta.

    TODO: Handle file renaming.
*/

if empty? args [
    print "Usage: dpatch <directory> [<new directory> | <patch file>]"
    quit
]

context [
    flist: make block! 128

    read-dir2: func [dir | name] [
        foreach name read dir [
            name: join dir name
            either dir? name [
                read-dir2 terminate name '/'
            ][
                append flist mark-sol name
            ]
        ]
    ]

    set 'read-dir func [dir] [
        clear flist
        read-dir2 terminate to-file dir '/'
        sort flist
    ]
]

format: func [fmt data | out txt pad tok plen] [
    out: make string! 32
    data: reduce data
    pad: ' '
    parse fmt [some[
        set tok
        int! (
            txt: to-text first ++ data
            plen: sub abs tok size? txt
            either lt? tok 0 [
                append/repeat out pad plen
                append out txt
            ][
                append out txt
                append/repeat out pad plen
            ]
        )    
      | string!/char! (append out tok)
      | coord! (
            txt: to-text first ++ data
            append out slice txt tok
        )
      | 'pad set pad skip
    ]]
    out
]

file-size: func [f] [second info? f]
file-perm: func [f] [pick info? f 5]

exec: func [cmd] [
    rc: execute /*probe*/ rejoin cmd
    ifn zero? rc [quit/return rc]
]

;-----------------------------------------------------------------------------

local-paths: func [root files | loc f] [
    root: size? root
    loc: copy files
    map f loc [skip f root]
]

print-file: func [f] [
   ;print format [-9 ' ' 2,7 ' ' 0] reduce [file-size f  checksum f  f]
    print format [-9 ' ' 0] reduce [file-size f  f]
]

build-patch: does [
    d1: terminate to-file d1 '/'
    d2: terminate to-file d2 '/'
    f1: read-dir d1
    f2: read-dir d2
    loc1: local-paths d1 f1
    loc2: local-paths d2 f2

    pdir: %patch
    ifn exists? pdir [make-dir pdir]

    new-files: []
    deltas: []

    count: 0
    delta-fn: does [
        format [pad '0' -5 ".xd"] to-block ++ count
    ]

    foreach f difference loc2 loc1 [
        out: delta-fn
        append append new-files
            mark-sol to-file out
            mark-sol/clear f
        exec [{cp "} d2 f {" } pdir '/' out]
    ]

    foreach f intersect loc1 loc2 [
        old: join d1 f
        new: join d2 f
        if any [
            ne? file-size old file-size new
            ne? checksum  old checksum  new
        ][
            out: delta-fn
            append append deltas
                mark-sol to-file out
                mark-sol/clear f
            exec [{xdelta3 -f -S djw -s "} old {" "} new {" } pdir '/' out]
        ]
    ]

    patch: context [
        added:   new-files
        removed: difference loc1 loc2
        xdelta:  deltas
        ;chmod:   []
    ]
    ;probe patch
    save join pdir %/database.b patch

    execute rejoin [ {tar cJf "} slice d2 -1 {.tar.xz" } pdir]
]

apply-patch: func [root patch | db delta f tmp] [
    root: terminate to-file root  '/'
    tmp: join root %_dpatch_.tmp    ; Keep tmp on same filesystem as root!

    exec [{tar xJf "} patch '"']
    patch: %patch/
    db: load join patch %database.b

    foreach [delta f] db/added [
        rename join patch delta join root f
    ]

    foreach f db/removed [
        delete join root f
    ]

    foreach [delta f] db/xdelta [
        f: join root f
        rename f tmp
        exec [{xdelta3 -d -s "} tmp {" "} patch delta {" "} f '"']
        if ne? p: file-perm tmp 6,6,4,0 [
            exec [{chmod } p/4 p/1 p/2 p/3 { "} f '"']
        ]
    ]

    ;foreach [p f] db/chmod [
    ;    exec [{chmod } p { "} join root f '"']
    ;]

    if exists? tmp [delete tmp]

    pop patch
    foreach f read-dir patch [delete f]
    delete patch
]

;-----------------------------------------------------------------------------

ifn dir? d1: first args [
    print "Expected directory for first argument."
    quit/return 255
]

switch size? args [
    2 [
        d2: second args
        either dir? d2
            [build-patch d1 d2]
            [apply-patch d1 d2]
    ]
    1 [foreach f read-dir d1 [print-file f]]
]

;eof
