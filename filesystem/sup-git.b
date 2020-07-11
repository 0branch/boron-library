#!/usr/bin/boron -sp
; Supplement file tracker Git integration v0.6.5.
; Documentation is at http://urlan.sourceforge.net/sup.html
; External commands used: chmod, sup

usage: {Usage: sup-git <action>

Actions:
  diff-clean        Use diff of index from stdin to sync. working files.
  help              Print usage.
  install           Put syncronization commands into .git/hooks
}

ifn args [print usage quit]

rc: 0
switch to-word first args [
    diff-clean [
        ; Read diff from stdin.
        modified: make string! 2048
        fp: open 0
        while [read/append fp modified] []
        close fp

        if gt? size? modified 40 [
            new-dat: false
            removed: []
            hex: charset "0123456789abcdefABCDEF"
            fn-rule: [some hex ' ' fn: to '^/' :fn skip]
            parse modified [some[
                '-' fn-rule (append removed fn)
              | '+' fn-rule (if pos: find removed fn [remove pos] new-dat: true)
              | thru '^/'
            ]]
            ;probe removed

            ; NOTE: Git sets directory to root before running hooks.
            foreach fn removed [
                ;print ["KR: Removing" fn]
                delete fn
            ]
            if new-dat [
                ;print ["KR: sup reset"]
                execute "sup reset"
            ]
        ]
    ]

    install [
        ; NOTE: This assumes only a single .supplement in the repo. root.
        ifn exists? %.git/hooks [
            print "Install must be run from a Git repository root."
            quit/return 69
        ]
        ; FIXME: Git complains when checking out commit before index added.
        checkout: {
git diff -U0 HEAD@{1}:.supplement/index .supplement/index | sup-git diff-clean
}
        install-hook: func [hook cmd] [
            either exists? hook [
                if find read/text hook cmd [exit]
                write/append hook cmd
            ][
                write hook join "#!/bin/sh^/" cmd
                execute join "chmod 755 " hook
            ]
            print ["Modified" hook]
        ]

        install-hook %.git/hooks/post-checkout checkout
        install-hook %.git/hooks/post-merge    checkout

        write/append %.gitignore "/.supplement/*^/!/.supplement/index^/"
        print "Modified .gitignore"
    ]

    help [print usage]

    [rc: 64 print ["Unknown action" first args]]
]
quit/return rc
