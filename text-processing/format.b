/*
    Simple string formatting
    Version 2.0
    Requires Boron 0.2.6
*/

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
      | 'pad set pad skip
    ]]
    out
]


;  Examples

foreach [item n name][
    cookies 30 "Joe Smith"
    cake 102 "Sally M. Longshanks"
    tea 5 "Fred"
][
    print format ["  | " 11 6 12 " |"] [item n name]
]

foreach [file h m s][
    %some/file 1 22 3
    %some/other/file 0 4 45
][
    print format [pad '.' 20 pad 0 -2 ':' -2 ':' -2] [file h m s]
]
