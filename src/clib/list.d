// SPDX-FileCopyrightText: (C) 2023 Alisa Lain <al1-ce@null.net>
// SPDX-License-Identifier: OSL-3.0

/// NoGC compatible double ended container
module clib.list;

import clib.exception;
import clib.vector;
import clib.memory;
import clib.iterator;

/// FCFS container
struct list(T, A: IAllocator!T = allocator!T) {
    private struct Node {
        T value;
        Node* next = null;
        Node* prev = null;
    }

    private Node* _root = null;
    private Node* _end = null;
    private size_t _size = 0;
    private size_t _size_limit = -1;
    private A _allocator = null;

    /// Length of list
    @property size_t size() @nogc nothrow { return _size; }

    /// Is list empty
    @property bool empty() @nogc nothrow { return _root == null; }

    /// Returns first value or T.init without removing it from list
    @property T front() @nogc nothrow {
        if (_root == null) return T.init;
        return (*_root).value;
    }

    /// Returns last value or T.init without removing it from list
    @property T back() @nogc nothrow {
        if (_root == null) return T.init;
        return (*_end).value;
    }

    /// Returns iterator to beginning
    @property forward_iterator!(list!(T, A), T) begin() @nogc nothrow {
        return forward_iterator!(list!(T, A), T)(this, _size);
    }
    /// Returns iterator to end
    @property backward_iterator!(list!(T, A), T) end() @nogc nothrow {
        return backward_iterator!(list!(T, A), T)(this, _size);
    }

    /// Creates list filled with vals
    this(T[] vals...) @nogc nothrow {
        _allocator = _new!A();
        push_back(vals);
    }

    // Copy ctor (slow)
    this(ref scope list!(T, A) other) @nogc nothrow {
        for (int i = 0; i < other.size; ++i) {
            push_back(other[i]);
        }
        _size_limit = other._size_limit;
        _size = other._size;
    }

    ~this() @nogc nothrow {
        while (_size > 0) pop_front();
        _free(_allocator);
    }

    /// Creates a copy of this list (slow)
    scope list!(T, A) clone() @nogc nothrow {
        list!(T, A) l;
        for (int i = 0; i < _size; ++i) {
            l.push_back(get_node_at(i).value);
        }
        l._size_limit = _size_limit;
        l._size = _size;
        return l;
    }

    /// Returns true if has element (slow)
    bool has(T val) @nogc nothrow {
        for (int i = 0; i < _size; ++i) if (val == get_node_at(i).value) return true;
        return false;
    }

    /// Returns index of value or -1 (size_t.max == -1) (slow)
    size_t find(T val) @nogc nothrow {
        for (int i = 0; i < _size; ++i) if (val == get_node_at(i).value) return i;
        return -1;
    }

    /// Length of vector
    size_t opDollar() @nogc nothrow const { return _size; }

    void opOpAssign(string op: "~")( in T b ) @nogc nothrow {
        push_back(b);
    }

    void opOpAssign(string op: "~")( in T[] b ) @nogc nothrow {
        push_back(b);
    }

    /// Ditto
    void opIndexAssign(T val, size_t index) @nogc nothrow {
        if (index >= _size || _size == 0) return;
        Node* n = get_node_at(index);
        import std.format: format;
        if (n != null) (*n).value = val;
    }

    /// Returns element of vector or T.init
    T opIndex(size_t index) @nogc nothrow {
        if (index >= _size || _size == 0) return T.init;
        Node* n = get_node_at(index);
        if (n == null) return T.init;
        return (*n).value;
    }

    /// Removes element at `pos`
    /// If `pos >= size` then it will do nothing
    void erase(size_t index) @nogc nothrow {
        if (index >= _size || _size == 0) return;
        if (index == 0) { pop_front(); return; }
        if (index == _size - 1) { pop_back(); return; }
        Node* n = get_node_at(index);
        if (n == null) return;
        Node* p = (*n).prev;
        Node* x = (*n).next;
        (*p).next = x;
        (*x).prev = p;
        _allocator.deallocate_vptr(n);
        --_size;
    }

    /// Removes elements between `p_start` and `p_end`, including start and end
    void erase(size_t p_start, size_t p_end) @nogc nothrow {
        if (_size == 0) return;
        if (p_start >= _size || p_end >= _size) return;
        if (p_start > p_end) return;
        if (p_end == p_start) { erase(p_start); return; }
        if (p_end >= _size - 1) p_end = _size - 1;
        if (p_start == 0 && p_end == _size - 1) {
            while (_size > 0) pop_front();
            return;
        }
        size_t diff = p_end - p_start + 1;

        Node* n = get_node_at(p_start);
        if (n == null) return;
        Node* ns = (*n).prev;
        for (size_t i = 0; i < diff; ++i) {
            Node* tmp = n;
            n = (*n).next;
            if (tmp != null) _allocator.deallocate_vptr(tmp);
            if (n == null) break;
        }
        // n is new end here

        if (ns == null && n != null) {
            _root = n;
            (*_root).prev = null;
        }

        if (n == null && ns != null) {
            _end = ns;
            (*_end).next = null;
        }
        if (ns != null && n != null) {
            (*n).prev = ns;
            (*ns).next = n;
        }

        if (n == null && ns == null) {
            _root = null;
            _end = null;
        }

        _size -= diff;
    }

    /// Inserts value into vector at `p_pos`
    void insert(size_t pos, T val) @nogc nothrow {
        if (_size == 0) push_back(val);
        if (pos == 0) { push_front(val); return; }
        if (pos >= _size) { push_back(val); return; }
        Node* n = get_node_at(pos - 1);
        if (n == null) return;
        Node* x = (*n).next;
        Node* v = cast(Node*) _allocator.allocate_vptr(Node.sizeof);
        (*v).value = val;
        (*v).next = x;
        (*n).next = v;
        if (x != null) (*x).prev = v;
        ++_size;
    }

    /// Adds vals at end of list (last val becomes back)
    void push_back(T[] vals...) @nogc nothrow {
        if (_allocator is null) _allocator = _new!A();
        if (vals.length == 0) return;
        if (_size >= _size_limit) return;

        int i = 0;
        if (_root == null && _size < _size_limit) {
            Node* ptr = cast(Node*) _allocator.allocate_vptr(Node.sizeof);
            (*ptr).value = vals[i];
            (*ptr).next = null;
            (*ptr).prev = null;
            _root = ptr;
            _end = _root;
            ++_size;
            ++i;
        }

        for (;i < vals.length; ++i) {
            if (_size >= _size_limit) break;
            Node* ptr = cast(Node*) _allocator.allocate_vptr(Node.sizeof);
            (*ptr).value = vals[i];
            (*ptr).next = null;
            (*ptr).prev = _end;
            (*_end).next = ptr;
            _end = ptr;
            ++_size;
        }
    }

    /// Adds vals at start of list (last val becomes front)
    void push_front(T[] vals...) @nogc nothrow {
        if (_allocator is null) _allocator = _new!A();
        if (vals.length == 0) return;
        if (_size >= _size_limit) return;

        int i = 0;
        if (_root == null && _size < _size_limit) {
            Node* ptr = cast(Node*) _allocator.allocate_vptr(Node.sizeof);
            (*ptr).value = vals[i];
            (*ptr).next = null;
            (*ptr).prev = null;
            _root = ptr;
            _end = _root;
            ++_size;
            ++i;
        }

        for (;i < vals.length; ++i) {
            if (_size >= _size_limit) break;
            Node* ptr = cast(Node*) _allocator.allocate_vptr(Node.sizeof);
            (*ptr).value = vals[i];
            (*ptr).next = _root;
            (*ptr).prev = null;
            (*_root).prev = ptr;
            _root = ptr;
            ++_size;
        }
    }

    /// Returns first value and removes it from list or returns T.init if empty
    T pop_front() @nogc nothrow {
        if (_root == null) { return T.init; }
        T val = (*_root).value;
        --_size;
        if ((*_root).next != null) {
            Node* tmp = _root;
            _root = (*_root).next;
            _root.prev = null;
            _allocator.deallocate_vptr(tmp);
        } else {
            _allocator.deallocate_vptr(_root);
            _root = null;
            _end = null;
        }
        return val;
    }

    /// Returns first value and removes it from list or returns T.init if empty
    T pop_back() @nogc nothrow {
        if (_end == null) { return T.init; }
        T val = (*_end).value;
        --_size;
        if ((*_end).prev != null) {
            Node* tmp = _end;
            _end = (*_end).prev;
            _end.next = null;
            _allocator.deallocate_vptr(tmp);
        } else {
            _allocator.deallocate_vptr(_end);
            _root = null;
            _end = null;
        }
        return val;
    }

    /++
    Limits length of list, default is -1 which is limitless.
    If length is limited and new element is attempted to be
    pushed when list is overfilled nothing will happen.
    +/
    void limit_length(size_t len) @nogc nothrow {
        if (_root == null) return;
        if (len == 0) {
            while (_size > 0) pop_front();
            return;
        }
        if (len >= _size) return;
        Node* _node = _root;
        for (int i = 0; i < len; ++i) {
            if (i != len - 1) {
                _node = (*_node).next;
            } else {
                Node* n = (*_node).next;
                for (int j = i + 1; j < _size; ++j) {
                    if (n == null) break;
                    Node* tmp = n;
                    n = (*n).next;
                    _allocator.deallocate_vptr(tmp);
                }
                (*_node).next = null;
                _end = _node;
            }
        }
        _size = len;
        _size_limit = len;
    }

    /// Removes all elements from list
    void clear() @nogc nothrow {
        while (_size > 0) pop_front();
        _root = null;
        _end = null;
        _size = 0;
    }

    /// Returns data as vector
    scope vector!T array() @nogc nothrow {
        vector!T arr;
        if (_root == null) return arr;

        Node* last = _root;

        for (int i = 0; i < _size; ++i) {
            arr ~= (*last).value;
            if ((*last).next == null) break;
            last = (*last).next;
        }
        return arr;
    }

    private Node* get_node_at(size_t pos) @nogc nothrow {
        if (_size == 0 || _root == null) return null;
        if (pos >= _size - 1) return _end;
        if (pos == 0) return _root;
        bool top = pos > _size  / 2;
        size_t idx;
        Node* node;
        if (top) {
            idx = _size - 1;
            node = _end;
        } else {
            idx = 0;
            node = _root;
        }

        while (idx != pos) {
            if (top) {
                node = (*node).prev;
                --idx;
            } else {
                node = (*node).next;
                ++idx;
            }
        }
        return node;
    }
}

@nogc nothrow:
// Unittests

unittest {
    list!int q = list!int(1, 2, 3, 4);
    assert(q.size == 4);
    assert(q.front == 1);
    assert(q.back == 4);
    assert(q.pop_front() == 1);
    assert(q.pop_back() == 4);
    assert(q.front == 2);
    assert(q.back == 3);
    assert(q.size == 2);
    assert(q.array == [2, 3]);
}

unittest {
    list!int q;
    assert(q.empty);
    assert(q.front == int.init);
    assert(q.back == int.init);
    q.push_front(3, 2, 1);
    assert(q.front == 1);
    assert(q.back == 3);
    q ~= 3;
    q.push_back(2);
    assert(q.front == 1);
    assert(q.array == [1, 2, 3, 3, 2]);
}

unittest {
    list!int q = list!int(1, 2, 3, 4);
    q.clear();
    assert(q.size == 0);
    assert(q.pop_front() == int.init);
    assert(q.pop_back() == int.init);
}

unittest {
    list!int q = list!int(1, 2, 3, 4);
    q.push_back(5, 6, 7, 8, 9, 10);
    q.limit_length(7);
    assert(q.size == 7);
    assert(q.array == [1, 2, 3, 4, 5, 6, 7]);
}

unittest {
    list!int q = list!int(1, 2, 3, 4);
    q.insert(2, 5);
    assert(q.array == [1, 2, 5, 3, 4]);
}

unittest {
    list!int q = list!int(0, 1, 2, 3, 4, 5, 6, 7, 8);
    q.erase(2, 5);
    assert(q.array == [0, 1, 6, 7, 8]);
    assert(q.size == 5);
    q.erase(0, 1);
    assert(q.array == [6, 7, 8]);
    assert(q.size == 3);
    q.erase(1, 2);
    assert(q.array == [6]);
    assert(q.size == 1);
    q = list!int(0, 1, 2, 3, 4, 5, 6, 7, 8);
    q.erase(0);
    q.erase(7);
    assert(q.array == [1, 2, 3, 4, 5, 6, 7]);
    // q.erase(5, 9);
}

unittest {
    list!int l = list!int(1, 2, 4, 2, 6, 1);
    int[6] a = [1, 2, 4, 2, 6, 1];
    int i = 0;
    foreach (v; l.begin()) {
        assert(a[i] == v);
        ++i;
    }

    i = 5;
    foreach_reverse (v; l.end()) {
        assert(a[i] == v);
        --i;
    }
}

