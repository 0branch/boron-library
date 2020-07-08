#!/usr/bin/boron -sp
; Supplement file tracker v0.6.
; External commands used: cp, curl, find, install, rsync

usage: {{
Usage: sup <action>

Actions:
  add <files>           Add files to supplement and index.
  convert               Convert git-annex to supplement.
  help                  Print usage.
  init                  Create new local supplement repository.
  prune                 Remove all supplement files not in the current index.
  pull [remote]         Transfer files from remote to local supplement.
  push [remote]         Transfer files from local to remote supplement.
  remove <files>        Remove files from supplement and index.
  reset                 Restore working files from index.
  source <name> <url>   Define remote supplement to fetch files from.
  verify                Show working files which do not match the index.
}}

ifn args [print usage quit]

sup-dir: %.supplement
sroot: sup-dir
;sroot: %/tmp/sup
config: context [
    version:
    repository:
    remotes: none
]
index: none

_execute: :print    ; For testing.

fatal: func ['code msg] [
    print msg
    quit/return select [
       ;ok          0
       ;fail        1
        usage       64 ; EX_USAGE
        noinput     66 ; EX_NOINPUT
        unavailable 69 ; EX_UNAVAILABLE
    ] code
]

set-sroot: func [/extern sroot] [
    ; Checking current directory (or hard-coded test path) first.
    ifn exists? sroot [
        path: current-dir
        clear prev tail path    ; Remove trailing slash.
        while [pos: find/last path '/'][
            change next pos sup-dir
           ;probe path
            if exists? path [
               ;return sroot: path
                clear pos
                change-dir path
                return true
            ]
            clear pos
        ]
        fatal unavailable "No .supplement directory found"
    ]
]

make-checksum-dir: func [csum] [
    make-dir rejoin [sroot '/' slice csum 2]
]

checksum-name: func [csum] [
    rejoin [sroot '/' slice csum 2 '/' csum]
]

checksum-ipath: func [csum] [
    rejoin [slice csum 2 '/' csum]
]

checksum-str: func [file] [
    slice mold checksum to-file file 2,-1
]

http-url?: func [url] [
    eq? "http" slice url 4
]

valid-name?: func [name] [
    alpha: charset "abcdefghijklmnopqrstuvwxyz"
    alpha-num: or alpha charset "0123456789-_"
    parse name [alpha any alpha-num]
]

init-repository: does [
    ifn exists? cf: join sroot %/config [
        make-dir sroot
        save cf [
            version: 1
            repository: true
            remotes: []
        ]
    ]
]

load-config: does [
    do bind/secure load join sroot %/config config
]

save-config: does [
    save join sroot %/config config
]

load-config-url: func [rname] [
    load-config
    either rname [
        ifn valid-name? rname [
            fatal usage join "Invalid remote name " rname
        ]
        url: select config/remotes to-word rname
    ][
        url: second config/remotes
    ]
    ifn url [
        fatal usage "Remote not defined. Use 'sup source' to setup one."
    ]
    url
]

parse-index: func [str] [
    ; Should probably store file size for quick modify check.
    index: make block! 128
    hex: charset "0123456789abcdefABCDEF"
    parse str [some[
        cs: some hex :cs ' ' fn: to '^/' :fn skip
        (append append index mark-sol cs fn)
    ]]
    index
]

load-index: does [
    ; index: load join sroot %/index
    parse-index read/text join sroot %/index
]

copy-from-index: func [idx /local cs fn] [
    ; Obtain the set of unique paths, create those directories, then copy
    ; the files.

    paths: []
    foreach [cs fn] idx [
        if pos: find/last fn '/' [
            path: slice fn pos
            ifn empty? path [
                append paths path
            ]
        ]
    ]
    paths: intersect paths paths
    forall paths [
        make-dir/all first paths
    ]
    foreach [cs fn] idx [
        execute rejoin [
            "install -p -m 664 " checksum-name cs ' ' '"' fn '"'
        ]
    ]
]


rc: 0
act: to-word first args
switch act [
    add [
        ; FIXME: Must currently add from root for correct path.
        ; FIXME: Check if file is already indexed.
        set-sroot
        index: make string! 1024
        foreach fn next args [
            make-checksum-dir cs: checksum-str fn
            execute rejoin [{cp -L "} fn {" } checksum-name cs]

            append index rejoin [cs ' ' fn '^/']
        ]
        write/append join sroot %/index index
    ]

    remove [
        print "TODO: Implement remove"
        /*
        set-sroot
        with-flock join sroot %/lock [
            idx: load-index
            foreach fn next args [
                if index-remove fn [
                    delete fn
                ]
            ]
        ]
        */
    ]

    verify [
        set-sroot
        foreach [cs fn] load-index [
            either exists? fn [
                if ne? cs checksum-str fn [
                    print ["Modified" fn]
                    rc: 1
                ]
            ][
                print ["Missing" fn]
                rc: 1
            ]
        ]
    ]

    pull [
        set-sroot
        url: load-config-url second args
        either http-url? url [
            execute rejoin [
                "curl -s -S " terminate url '/' %index " -o " sroot %/index
            ]
            foreach [cs fn] load-index [
                print ["Downloading" fn]
                ipath: checksum-ipath cs
                execute rejoin [
                    "curl -s -S " url ipath " --create-dirs -o " sroot '/' ipath
                ]
            ]
        ][
            execute rejoin [
                "rsync -a -e ssh --exclude=lock --exclude=config "
                terminate url '/' ' ' sup-dir
            ]
        ]
        copy-from-index load-index
    ]

    push [
        set-sroot
        url: load-config-url second args
        if http-url? url [
            fatal usage "Cannot push to HTTP remote"
        ]
        execute rejoin [
            "rsync -a -e ssh --exclude=lock --exclude=config "
            sup-dir "/ " url
        ]
    ]

    prune [
        print "TODO: Implement prune"
    ]

    reset [
        set-sroot
        copy-from-index load-index
    ]

    source [
        ifn all [
            name: second args
            url: third args
            valid-name? name
        ][
            fatal usage "Invalid source arguments"
        ]
        name: to-word name

        set-sroot
        with-flock join sroot %/lock [
            load-config
            remotes: config/remotes
            either pos: find remotes name [
                poke pos 2 url
            ][
                append append remotes mark-sol name url
            ]
            save-config
        ]
    ]

    init [
        init-repository
    ]

    convert [
        ifn exists? %.git/annex [
            fatal noinput "Convert must be run from a Git project root"
        ]

        list: make string! 2048
        db: []
        execute/out "find . -type l -ls" list

        ; Parse filename and link from find -ls output.
        parse list [some[
            ; 75 skips over leading "./" of filename.
            75 skip fn: to " -> " :fn 4 skip ln: to '^/' :ln skip
            (
                if ln: find ln ".git/annex/" [
                    append append db fn ln
                ]
            )
        ]]
        ;probe db

        init-repository

        index: make string! 2048
        emit: func [d] [append index d]
        foreach [fn ln] db [
            emit cs: checksum-str ln
            emit ' '
            emit fn
            emit '^/'

            make-checksum-dir cs
            execute rejoin [{cp -L "} fn {" } checksum-name cs]
        ]
        write join sroot %/index index
    ]

    help [
        print usage
    ]

    [fatal usage ["Unknown action" first args]]
]
quit/return rc
