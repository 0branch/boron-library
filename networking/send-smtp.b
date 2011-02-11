/*
    Send email to SMTP server.
    Version 1.0
    Requires Boron 0.1.11 (3f7c9ee5)
*/

smtp: context [
    reply: make string! 128
    ok: "250"
    crlf: "^d^a"
    sock:

    server:
    helo:
    from:
    rcpt:
    header:
        none

    confirm: func [port code] [
        read/into port reply
        ;probe reply
        ifn find/case/part reply code 3 [error reply]
    ]

    set-address: func [smtp-server from-addr to-addr] [
        server: join "tcp://" smtp-server
        ifn find smtp-server ':' [append server ":25"]
        helo: rejoin ["HELO " next find from-addr '@' crlf]
        from: rejoin ["MAIL FROM:<" from-addr ">^d^a"]
        rcpt: rejoin ["RCPT TO:<" to-addr ">^d^a"]

        ; From & Date are required by spec, some servers also require Subject.
        header: rejoin [
            "From: " from-addr crlf
            "To: " to-addr crlf
           ;"Date: Thu, 3 Feb 2011 00:06:04 -0800^d^a"
        ]
    ]

    months: [
        "Jan" "Feb" "Mar" "Apr" "May" "Jun"
        "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"
    ]

    rfc2822-date: func [| y m d t o] [
        parse to-string now/date [
            y: to '-' :y skip
            m: to '-' :m skip
            d: to 'T' :d skip
            t: 8 skip :t o:
        ]
        remove find o ':'
        rejoin [
            "Date: " d ' ' pick months to-int m ' ' y ' ' t ' ' o crlf
        ]
    ]

    set 'send func [msg] [
        sock: open server   ; "tcp://somewhere.net:25"
        confirm sock "220"

        write sock helo     ; "HELO box.somewhere.net^d^a"
        confirm sock ok

        write sock from     ; "MAIL FROM:<user@somewhere.net>^d^a"
        confirm sock ok

        write sock rcpt     ; rejoin ["RCPT TO:<" dest ">^d^a"]
        confirm sock ok

        write sock "DATA^d^a"
        confirm sock "354"

        write sock rejoin [header rfc2822-date msg "^d^a.^d^a"]
        confirm sock ok

        write sock "QUIT^d^a"
        confirm sock "221"

        close sock
    ]
]

/* Example
smtp/set-address "smtp-server.host.com" "me@somewhere.net" "you@somewhere.net"
send "Subject: Test 8^d^a^d^aTest from Boron^/Line 2"
*/
