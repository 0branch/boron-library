; Load INI format into context.
;
; Key names are converted to words so funky names with paths or arrays
; are not supported.

load-ini: func [file | tree blk wname n v] [
    tree: blk: make block! 16
    wname: func [str] [
        to-set-word replace/all trim str ' ' '_'
    ]
    parse read/text file [some[
        ';' thru '^/'
      | '#' thru '^/'
      | '^/'
      | '[' n: to ']' :n thru '^/' (
            append/block append tree wname n blk: copy []
        )
      | n: to '=' :n skip v: thru '^/' :v (
            append append blk wname n trim v
        )
    ]]
    context tree
]

;probe load-ini %/home/karl/.gitconfig
;probe load-ini %/home/karl/.kde/share/config/konsolerc
;probe load-ini %/lib/systemd/system/systemd-modules-load.service
