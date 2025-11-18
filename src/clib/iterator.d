// SPDX-FileCopyrightText: (C) 2023 Alisa Lain <al1-ce@null.net>
// SPDX-License-Identifier: OSL-3.0

/// Iterator/Range for internal use
module clib.iterator;

import clib.traits;

struct forward_iterator(I, T) if (IS_VALID_ITERABLE!I) {
    private I iterable;
    private size_t size = 0;
    private size_t index = 0;

    this(ref I _iterable, size_t _size) @nogc nothrow {
        iterable = _iterable;
        size = _size;
    }

    @property bool empty() @nogc nothrow => index >= size;
    @property T front() @nogc nothrow => iterable[index];

    void popFront() @nogc nothrow { ++index; }
}

struct backward_iterator(I, T) if (IS_VALID_ITERABLE!I) {
    private I iterable;
    private size_t size = 0;
    private size_t index = 0;

    this(ref I _iterable, size_t _size) @nogc nothrow {
        iterable = _iterable;
        size = _size;
    }

    @property bool empty() @nogc nothrow => index >= size;
    @property T back() @nogc nothrow => iterable[size - index - 1];

    void popBack() @nogc nothrow { ++index; }
}

private bool IS_VALID_ITERABLE(T)() @nogc nothrow {
    static if (IS_ARRAY!T) {
        return true;
    } else {
        return __traits(hasMember, T, "opIndex");
    }
}

@nogc nothrow {
    unittest {
        int[12] arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
        auto f = forward_iterator!(typeof(arr), int)(arr, arr.length);
        int i = 0;
        foreach (int el; f) {
            assert(el == i + 1);
            ++i;
        }
    }

    unittest {
        import clib.string;
        cstring s = "testing my patience";
        string t = "testing my patience";
        int i = 0;
        foreach (char c; forward_iterator!(cstring, char)(s, s.size)) {
            assert(c == t[i]);
            ++i;
        }
    }

    unittest {
        import clib.string;
        cstring s = "testing my patience";
        string t = "testing my patience";
        int i = cast(int) s.size - 1;
        foreach_reverse (char c; backward_iterator!(cstring, char)(s, s.size)) {
            assert(c == t[i]);
            --i;
        }
    }
}