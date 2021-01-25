#!/usr/bin/boron -s
; Show x86 CPU C6 State using Linux msr device.
; Requires Boron 2.0.4.

read-msr: func [msr int!] [
    skip f: open %/dev/cpu/0/msr msr    ; See man msr.
    parse read/part f 8 [bits [val: u64]]
    close f
    to-hex val
]

enabled-msr: func [msr mask] [
    val: read-msr msr
    either eq? mask and val mask "Enabled" "Disabled"
]

c6-package: 0xC0010292
c6-core:    0xC0010296

op: 'list
if args [
    parse args [
        "-e" (op: 'enable)
      | "-d" (op: 'disable)
      | "-l" (op: 'list)
    ]
]

switch op [
    enable [
        ;write-msr and read-msr c6-package 0x100000000
        ;write-msr and read-msr c6-core    0x000404040
    ]
    disable [
        ;write-msr and read-msr c6-package complement 0x100000000
        ;write-msr and read-msr c6-core    complement 0x000404040
    ]
    list [
        print ["C6 State Package:" enabled-msr c6-package 0x100000000]
        print ["C6 State Core:   " enabled-msr c6-core    0x000404040]
    ]
]
