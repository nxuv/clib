# #!/usr/bin/env -S just --justfile
# just reference: https://just.systems/man/en/
# monolith flavor: ~/.config/nvim/readme/build.md
#
# set positional-arguments

build: && _make

TEST_UNIT := "./bin/clib-test-library"

test: _make && (_check_leak TEST_UNIT) _warning_leak

test_full: _make && (_check_full TEST_UNIT) _warning_leak

test_complete:
    dub build     --compiler dmd
    dub test      --compiler dmd

    dub build     --compiler ldc2
    dub test      --compiler ldc2

    dub build     --compiler gdc
    dub test      --compiler gdc

unit: && _clean_vgcore _warning_leak
    @dub test --vquiet
    valgrind {{TEST_UNIT}}

reuse:
    reuse lint

_make:
    @dub build       --quiet  --compiler dmd
    @dub test        --vquiet --compiler dmd

_clean_vgcore:
    @-rm vgcore.*

_check_leak FPATH: && _clean_vgcore
    valgrind {{FPATH}}

_check_full FPATH: && _clean_vgcore
    valgrind --leak-check=full --show-leak-kinds=all {{FPATH}}

_warning_leak:
    @echo "EXPECT LEAK OF <=72 BYTES UNTIL 23106 IS RESOLVED"
    @echo "23106 moved to https://github.com/dlang/dmd/issues/17446"
    @echo "Or apparently 96 bytes now..?"

