#!/usr/bin/boron -sp
; Supplement file tracker v0.6.9.
; Documentation is at http://urlan.sourceforge.net/sup.html
; External commands used: cp, curl, find, install, rsync

usage: {{
Usage: sup <action>

Actions:
  add <files>           Add files to supplement and index.
  help                  Print usage.
  import                Copy git-annex files into a new supplement.
  init [-r]             Create new local supplement repository.
  move <from> <to>      Change file path in working directory and index.
  prune                 Remove all supplement files not in the current index.
  pull [<remote>] [-i]  Transfer files from remote to local supplement.
  push [<remote>]       Transfer files from local to remote supplement.
  remove <files>        Remove files from the index and working directory.
  reset [<files>] [-r <remote>]
                        Restore working files from index.
  source <name> <url>   Define remote supplement to fetch files from.
  verify                Show working files which do not match the index.
}}

ifn args [print usage quit]

sroot:
sup-dir: %.supplement
local-path: %
config: context [
    version:
    repository:
    remotes: none
]
index: none

;execute: :print    ; For testing.

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

/*
  Change the current directory to where the supplement resides and set
  local-path to the path nodes from there to the previously current directory.
*/
set-sroot: func [/extern sroot] [
    clear local-path

    ; Checking current directory (or hard-coded test path) first.
    ifn exists? sroot [
        path: copy cd: current-dir
        clear prev tail path    ; Remove trailing slash.
        while [pos: find/last path '/'][
            change next pos sup-dir
           ;probe path
            if exists? path [
                clear pos
                change-dir path
                append local-path skip cd index? pos
                exit
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

ssh-opt: func [url] [
    either eq? '/' first url "" "-e ssh "
]

valid-name?: func [name] [
    alpha: charset "abcdefghijklmnopqrstuvwxyz"
    alpha-num: or alpha charset "0123456789-_"
    parse name [alpha any alpha-num]
]

filter-index: func [idx files] [
    if empty? files [
        return idx
    ]
    fin: []
    forall files [
        fn: join local-path first files
        if pos: find idx fn [
            append fin slice prev pos 2
        ]
    ]
    fin
]

init-repository: func [repo] [
    ifn exists? cf: join sroot %/config [
        make-dir sroot
        save cf context [
            version: 1
            repository: repo
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

config-url: func [rname] [
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
    if string? str [
        hex: charset "0123456789abcdefABCDEF"
        parse str [some[
            cs: some hex :cs ' ' fn: to '^/' :fn skip
            (append append index mark-sol cs fn)
        ]]
    ]
    index
]

load-index: does [
    ; index: load join sroot %/index
    parse-index read/text join sroot %/index
]

save-index: func [idx /local cs fn] [
    istr: make string! 4096
    foreach [cs fn] idx [
        append istr rejoin [cs ' ' fn '^/']
    ]
    write join sroot %/index istr
]

copy-from-index: func [idx /local cs fn] [
    ; Obtain the set of unique paths, create those directories, then copy
    ; the files.

    paths: make block! 128
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
        execute rejoin ["install -C -m 664 " checksum-name cs ' ' '"' fn '"']
    ]
]

/*
  The parse-args spec has two rules:
     char!  word!   Set word to none or true if the option is present.
     /value word!   Set word to any argument not starting with '-'
*/
parse-args: func [ai spec block!] [
    set spec none
    forall ai [
        arg: first ai
        either eq? '-' first arg [
            if word: select spec second arg [set word true]
        ][
            if word: select spec /value [set word arg]
        ]
    ]
]


rc: 0
act: to-word first args
switch act [
    add [
        set-sroot
        with-flock join sroot %/lock [
            modified: false
            index: load-index
            foreach fn next args [
                fn: join local-path fn
                cs: checksum-str fn
                in-repo: find index cs

                file-mod: either pos: find index fn [
                    if ne? cs pick pos -1 [
                        poke pos -1 cs
                        true
                    ]
                ][
                    append append index mark-sol cs fn
                    true
                ]

                if file-mod [
                    modified: true
                    ifn in-repo [
                        make-checksum-dir cs
                        execute rejoin [{cp -L "} fn {" } checksum-name cs]
                    ]
                ]
            ]
            if modified [save-index index]
        ]
    ]

    remove [
        ; Remove the working file and index entry, but don't touch the repo.
        set-sroot
        with-flock join sroot %/lock [
            removed: 0
            index: load-index
            foreach fn next args [
                fn: join local-path fn
                either pos: find index fn [
                    remove/part prev pos 2
                    delete fn
                    ++ removed
                ][
                    print ["Index does not contain" fn]
                    rc: 1
                ]
            ]
            ifn zero? removed [save-index index]
        ]
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
        parse-args next args ['i' fetch-index /value remote]

        set-sroot
        load-config
        url: config-url remote
        either http-url? url [
            terminate url '/'
            if fetch-index [
                execute rejoin [
                    "curl -s -S " url %index " -o " sroot %/index
                ]
            ]
            foreach [cs fn] load-index [
                print ["Downloading" fn]
                ipath: checksum-ipath cs
                if config/repository [
                    fn: rejoin [sroot '/' ipath]
                ]
                execute rejoin [
                    "curl -s -S " url ipath " --create-dirs -o " fn
                ]
            ]
            if config/repository [
                copy-from-index load-index
            ]
        ][
            execute rejoin [
                "rsync -a " ssh-opt url "--exclude=lock --exclude=config "
                either fetch-index "" "--exclude=index "
                terminate url '/' ' ' sup-dir
            ]
            copy-from-index load-index
        ]
    ]

    push [
        set-sroot
        load-config
        url: config-url second args
        if http-url? url [
            fatal usage "Cannot push to HTTP remote"
        ]
        execute rejoin [
            "rsync -a " ssh-opt url "--exclude=lock --exclude=config "
            sup-dir "/ " url
        ]
    ]

    reset [
        url: none
        files: []
        parse next args [some[
            "-r" set url skip | set fn skip (append files fn)
        ]]

        set-sroot
        load-config
        either config/repository [
            copy-from-index filter-index load-index files
        ][
            url: config-url url
            ifn http-url? url [
                fatal usage "Cannot reset via rsync in lean mode"
            ]
            foreach [cs fn] filter-index load-index files [
                if any [
                    not exists? fn
                    ne? cs checksum-str fn
                ][
                    print ["Downloading" fn]
                    execute rejoin [
                        "curl -s -S " url checksum-ipath cs
                        " --create-dirs -o " fn
                    ]
                ]
            ]
        ]
    ]

    move [
        ifn all [
            from: second args
            to: third args
            ne? from to
        ][
            fatal usage "Move requires from and to arguments"
        ]

        set-sroot
        from: join local-path from
        to:   join local-path to
        with-flock join sroot %/lock [
            index: load-index
            either pos: find index from [
                rename from to
                poke pos 1 to
                save-index index
            ][
                fatal unavailable "File not found in .supplement/index"
            ]
        ]
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

    prune [
        print "TODO: Implement prune"
        rc: 1
    ]

    init [
        init-repository eq? "-r" second args
        ifn exists? index: join sroot %/index [
            write index ""
        ]
    ]

    import [
        ifn exists? %.git/annex [
            fatal noinput
                "No annex found; import must be run from a Git project root"
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

        init-repository true

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
