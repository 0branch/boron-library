#!/bin/boron -s
; Change library SONAME to put the version before the ".so" suffix and write
; a new library with a matching name.  This is required by Android packages.

basename: func [path] [
    if name: find/last path '/' [return next name]
    path
]

; Change name suffix from ".so.X" to "_X.so" in place.
rename-so: func [suffix] [
    remove/part suffix 3
    replace/all suffix '.' '_'
    append suffix ".so"
]

ifn args [print "Usage: soname.b <files>" quit]
forall args [
    f: copy first args
    either all [
        suffix: find/last f ".so"
        gt? size? suffix 3
    ][
        buf: read f
        name: basename f
        either pos: find buf name [
            rename-so suffix
            change pos to-binary name
            write f buf
            execute rejoin ["chmod 775 " f]
        ][
            print ["No name" name "found in" f]
        ]
    ][
        print ["Ignoring" f]
    ]
]
