#!/usr/bin/boron -s
/*
   Converts a single binary STL file to a Boron-GL buffer.
   Version: 1.0
   Requires Boron 2.0.4
*/

; STL Triangle buffer.
stri: make vector! 'f32

; Geometry output.
attrib: reserve make vector! 'f32 2048
indices: make vector! 'i32

vindex: []

; Search for a copy of the vertex at the end of buf and return its index.
emit-vertex-similar: func [buf stride] [
    new-attrib: skip tail buf negate stride
    either pos: find vindex new-attrib [
        ;print "; reused"
        clear new-attrib
    ][
        pos: tail vindex
        append vindex mark-sol slice new-attrib stride
        print [' ' to-text new-attrib]
    ]
    sub index? pos 1
]

; Print vertex at the end of buf and return its index.
emit-vertex: func [buf stride] [
    new-attrib: skip tail buf negate stride
    print [' ' to-text new-attrib]
    div index? new-attrib stride
]

emitv: func [offset] [
    append attrib slice skip stri offset 3
    append attrib slice stri 3
    append indices emit-vertex attrib 6
]

file: none
parse args [some[
    "-s" (emit-vertex: :emit-vertex-similar)
  | "-h" (print "Usage: stl_to_bgl.b [-s] <stl-file>" quit)
  | set file skip
]]

parse read file [
    [
        "solid" (print "STL ASCII format not supported" quit/return 1)
      | about: 80 skip
    ]
    bits [count: u32]
    (
        print [';' trim to-string slice about 80 "^/;" count]
        print "buffer [vertex normal] #["
    )
    count [
        ; 12 f32 (normal v1 v2 v3)
        nv: 50 skip (
            append clear stri slice nv 48
           ;probe stri

            emitv 3
            emitv 6
            emitv 9
        )
       ;bits [attr-len: u16]
       ;attr-len skip
    ]
]

print rejoin ["]^/tris " either lt? count 21845 'u16 "" "#[^/" indices "^/]"]
