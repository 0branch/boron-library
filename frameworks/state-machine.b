/*
    State Machine
    Version 1.0
    Requires Boron 0.1.11 (3f7c9ee5)

    export [
        state-machine
        state-machine-goto
        update-state-machines
    ]
*/


context [
    _sm-list: []

    activate-state-machine: func [sm /*init-state*/] [
        append _sm-list sm
        do sm/_state/1
        ;do first sm/_state: get in sm init-state
        sm
    ]

    ; Returns new machine.
    set 'state-machine func [def block! | states index tok] [
        states: make block! 6

        index: copy [_state: none]

        ifn parse def [some[
            tok: set-word! [1 3 block! | 'none] :tok
            (
                append states next tok
                switch size? tok [
                    2 [append states [none none]]
                    3 [append states none]
                ]
                append index first tok
                append/block index skip tail states -3
            )
        ]][
            error "Bad state-machine definition"
        ]

        ; Reduce to convert none words to none! - speeds up eval. by ~10%.
        poke index 2 reduce bind states 'goto
        activate-state-machine context index ;to-word first index
    ]

    set 'update-state-machines func [| sm] [
        foreach sm _sm-list [
            do sm/_state/2
        ]
    ]

    set 'state-machine-goto func [sm state] [
        do sm/_state/3                      ; leave current state
        do first sm/_state: sm/:state       ; enter new state
    ]

    goto: func ['new-state | ctx] [
        ctx: binding? new-state
        do ctx/_state/3                     ; leave current state
        do first ctx/_state: get new-state  ; enter new state
    ]

    ;deactivate: does [ remove find _sm-list _sm-current ]
]


/* Example

signal: no

state-machine [
    init:
        [print 'init goto s1]
    s1:
        [print 's1]
        [sleep 2.0 goto s2]
        [print 'leave-s1 signal: yes]
    s2:
        [print 's2]
        [sleep 2.0 goto exit]
    exit:
        [print 'exit quit]
]

m2: state-machine [
    init:   none
    enable: [print "^-M2 Enabled"]
]

forever [
    update-state-machines
    if signal [
        signal: no
        state-machine-goto m2 'enable
    ]
]
*/


;eof
