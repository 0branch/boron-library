/*
    Simple string formatting
    Version 1.0
*/

format: func [fmt data | op txt out] [
    out: make string! 32
    data: reduce data
    foreach op fmt [
        either int? op [
            txt: to-text first ++ data
            append out txt
            loop sub op size? txt [append out ' ']
        ][
            append out op
        ]
    ]
    out
]

/* Example
*/
foreach [item n name][
    cookies 30 "Joe Smith"
    cake 102 "Sally M. Longshanks"
    tea 5 "Fred"
][
    print format ["  | " 11 6 12 " |"] [item n name]
]
