#!/usr/bin/boron -s
; SVG Outline - Convert Markdown list items to SVG objects
; Version 1.0

file: first args
ifn file [
    print "Usage: svg-outline <text-file>"
    quit/return 64
]

parse-md-lists: func [file items] [
    white: charset " ^-"
    dash:  charset "*--+"
    bullet: [any white dash some white]
    parse read/text file [some[
        '^/' ls: bullet tok: to '^/' :tok (
            ls: size? slice ls tok
            indent: div add 2 ls 4
            append append items indent tok
        )
      | skip to '^/'
    ]]
]

obj: make block! 128
parse-md-lists file obj
;probe obj

svg: make string! 2048
emit:  func [data] [append svg data]
emitr: func [data replace] [emit construct data replace]

pos-rules: ["$X" x "$Y" y "$W" w "$H" h "$S" style "$T" text]

rect-style: [
    { rx="10" ry="10" style="fill:white;stroke:rgb(50,103,144);stroke-width:3"}
    { rx="10" ry="10" style="fill:rgb(235,235,246);stroke:rgb(115,130,179);stroke-width:3"}
    { rx="4" ry="4" style="fill:rgb(59,163,21)"}
    { rx="4" ry="4" style="fill:rgb(229,165,10)"}
]
rect-metrics: [
    150,50, 10,20
    150,50, 10,20
     60,20,  5,13
     60,16,  5,11
]
text-style: [
    { class="large"}
    { class="large"}
    { class="small"}
    { class="small"}
]

ix: 0
iy: 20

emit {{
    <svg width="201mm" height="297mm">
    <style>
      .large {
          font-family: "Architects Daughter";
      }
      .small {
          font-family: Comfortaa; font-size: 80%; font-weight: bold;
          fill: white;
      }
    </style>
}}
foreach [level item] obj [
    text: item
    rmet: pick rect-metrics level

    x: add ix mul level 40
    y: iy
    w: maximum first rmet mul size? text 9
    h: second rmet
    emit "<g>^/"
    emitr {  <rect x="$X" y="$Y" width="$W" height="$H" } pos-rules
    emit pick rect-style level
    emit "/>^/"

    x: add x third rmet
    y: add iy pick rmet 4
    style: pick text-style level
    emitr { <text x="$X" y="$Y"$S>$T</text>^/} pos-rules
    emit "</g>^/"

    iy: add iy add h 16
]
emit "</svg>^/"

print svg
