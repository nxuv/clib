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

    /++ Transfers elements from another list to this list
        Params:
          position = Position in this list where elements will be inserted
          other = List to transfer elements from
          start = Start position in other list (inclusive)
          end = End position in other list (inclusive)
    +/
    void splice(size_t position, ref list!(T, A) other,
                size_t start = 0, size_t end = size_t.max) @nogc nothrow
    {
        if (_allocator is null) _allocator = _new!A();

        // Early exit conditions
        if (other._root is null || start >= other._size) return;
        if (&other == &this) return; // Prevent self-splicing
        if (end >= other._size) end = other._size - 1;
        if (start > end) return;
        if (position > _size) position = _size;

        // Get nodes from other list
        Node* first = other.get_node_at(start);
        Node* last = other.get_node_at(end);
        if (first is null || last is null) return;

        size_t elements_to_move = end - start + 1;
        if (elements_to_move == 0) return;

        // Update other list's links
        Node* prev_first = first.prev;
        Node* next_last = last.next;

        // Disconnect nodes from other list
        if (prev_first !is null) prev_first.next = next_last;
        if (next_last !is null) next_last.prev = prev_first;

        // Update other's root/end if needed
        if (start == 0) other._root = next_last;
        if (end == other._size - 1) other._end = prev_first;

        // Handle other list becoming empty
        if (other._size == elements_to_move) {
            other._root = null;
            other._end = null;
        }

        // Update other's size
        other._size -= elements_to_move;

        // Insert into this list
        if (_size == 0) {
            _root = first;
            _end = last;
            first.prev = null;
            last.next = null;
        } else if (position == _size) {
            _end.next = first;
            first.prev = _end;
            _end = last;
            last.next = null;
        } else if (position == 0) {
            last.next = _root;
            _root.prev = last;
            _root = first;
            first.prev = null;
        } else {
            Node* pos_node = get_node_at(position);
            if (pos_node is null) return;
            Node* prev_node = pos_node.prev;
            if (prev_node is null) return;

            prev_node.next = first;
            first.prev = prev_node;
            last.next = pos_node;
            pos_node.prev = last;
        }

        // Update size to finish
        _size += elements_to_move;
    }

    /++ Merges two sorted lists into one
        Both lists must be sorted according to operator <
        After the operation, other becomes empty
        Params:
          other = List to merge with this list
    +/
    void merge(ref list!(T, A) other) @nogc nothrow {
        if (_allocator is null) _allocator = _new!A();
        if (other._root is null) return;
        if (&other == &this) return;

        // Handle case when this list is empty
        if (_root is null) {
            _root = other._root;
            _end = other._end;
            _size = other._size;
            other._root = null;
            other._end = null;
            other._size = 0;
            return;
        }

        Node* current = _root;
        Node* other_current = other._root;

        // Handle case when first element from other should be at start
        if (other_current.value < current.value) {
            _root = other_current;
            other_current = other_current.next;
            _root.prev = null;
            _root.next = current;
            current.prev = _root;
            current = _root;
        }

        // Merge the lists
        while (other_current !is null) {
            if (current.next is null) {
                // Append remaining other elements
                current.next = other_current;
                other_current.prev = current;
                _end = other._end;
                break;
            }

            if (other_current.value < current.next.value) {
                // Insert other_current between current and current.next
                Node* next = other_current.next;
                other_current.next = current.next;
                other_current.prev = current;
                current.next.prev = other_current;
                current.next = other_current;
                other_current = next;
            } else {
                current = current.next;
            }
        }

        // Update sizes
        _size += other._size;
        other._root = null;
        other._end = null;
        other._size = 0;
    }

    /++ Sorts the list in ascending order using merge sort
    The list is sorted in-place using operator <
    +/
    void sort() @nogc nothrow {
        if (_root is null || _root.next is null) return;

        _root = merge_sort_internal(_root);

        // Fix end pointer and prev links
        Node* current = _root;
        while (current.next !is null) {
            current.next.prev = current;
            current = current.next;
        }
        _end = current;
    }

    private Node* merge_sorted_lists(Node* first, Node* second) @nogc nothrow {
        if (first is null) return second;
        if (second is null) return first;

        Node* result;
        if (first.value <= second.value) {
            result = first;
            result.next = merge_sorted_lists(first.next, second);
            if (result.next !is null) result.next.prev = result;
        } else {
            result = second;
            result.next = merge_sorted_lists(first, second.next);
            if (result.next !is null) result.next.prev = result;
        }
        result.prev = null;
        return result;
    }

    private Node* get_middle_node(Node* head) @nogc nothrow {
        if (head is null || head.next is null) return head;

        Node* slow = head;
        Node* fast = head.next;

        while (fast !is null) {
            fast = fast.next;
            if (fast !is null) {
                fast = fast.next;
                slow = slow.next;
            }
        }
        return slow;
    }

    private Node* merge_sort_internal(Node* head) @nogc nothrow {
        if (head is null || head.next is null) return head;

        // Find middle point
        Node* middle = get_middle_node(head);
        Node* next_to_middle = middle.next;

        // Split the list
        middle.next = null;
        if (next_to_middle !is null) next_to_middle.prev = null;

        // Recursively sort
        Node* left = merge_sort_internal(head);
        Node* right = merge_sort_internal(next_to_middle);

        // Merge sorted halves
        return merge_sorted_lists(left, right);
    }

    /++ Reverses the order of elements in the list in-place +/
    void reverse() @nogc nothrow {
        if (_root is null || _root.next is null) return;

        Node* prev = null;
        Node* current = _root;
        Node* next = null;

        // Swap next and prev pointers for all nodes
        while (current !is null) {
            next = current.next;
            current.next = prev;
            current.prev = next;
            prev = current;
            current = next;
        }

        // Swap root and end
        _end = _root;
        _root = prev;
    }

    /++ Removes consecutive duplicate elements from the list.
        The list must be sorted first if you want to remove all duplicates.
    +/
    void unique() @nogc nothrow {
        if (_root is null || _root.next is null) return;

        Node* current = _root;
        while (current.next !is null) {
            if (current.value == current.next.value) {
                // Remove the next node
                Node* to_remove = current.next;
                current.next = to_remove.next;
                if (to_remove.next !is null) {
                    to_remove.next.prev = current;
                } else {
                    _end = current;
                }
                _allocator.deallocate_vptr(to_remove);
                --_size;
            } else {
                current = current.next;
            }
        }
    }
}

@nogc nothrow {
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
        q.erase(7);
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

    unittest {
        import core.stdc.stdio : printf;

        // Test full list splice
        list!int l1 = list!int(1, 2, 3);
        list!int l2 = list!int(4, 5, 6);
        l1.splice(1, l2);

        assert(l2.empty, "l2 should be empty");

        // Test partial splice
        l1 = list!int(1, 2, 3);
        l2 = list!int(4, 5, 6, 7, 8);
        l1.splice(0, l2, 1, 3);
        assert(l1.array == [5, 6, 7, 1, 2, 3]);
        assert(l2.array == [4, 8]);

        // Test splice to end
        l1 = list!int(1, 2);
        l2 = list!int(3, 4, 5);
        l1.splice(2, l2);
        assert(l1.array == [1, 2, 3, 4, 5]);
        assert(l2.empty);

        // Test splice from empty list
        l1 = list!int(1, 2);
        l2 = list!int();
        l1.splice(0, l2);
        assert(l1.array == [1, 2]);

        // Test splice to empty list
        l1 = list!int();
        l2 = list!int(1, 2, 3);
        l1.splice(0, l2);
        assert(l1.array == [1, 2, 3]);
        assert(l2.empty);

        // Test single element splice
        l1 = list!int(1, 2, 3);
        l2 = list!int(4, 5, 6);
        l1.splice(1, l2, 1, 1);
        assert(l1.array == [1, 5, 2, 3]);
        assert(l2.array == [4, 6]);
    }

    unittest {
        // Test basic merge
        list!int l1 = list!int(1, 3, 5);
        list!int l2 = list!int(2, 4, 6);
        l1.merge(l2);
        assert(l1.array == [1, 2, 3, 4, 5, 6]);
        assert(l2.empty);

        // Test merge with empty lists
        l1 = list!int();
        l2 = list!int(1, 2, 3);
        l1.merge(l2);
        assert(l1.array == [1, 2, 3]);
        assert(l2.empty);

        l1 = list!int(1, 2, 3);
        l2 = list!int();
        l1.merge(l2);
        assert(l1.array == [1, 2, 3]);
        assert(l2.empty);

        // Test merge with duplicate values
        l1 = list!int(1, 2, 2, 3);
        l2 = list!int(2, 2, 4);
        l1.merge(l2);
        assert(l1.array == [1, 2, 2, 2, 2, 3, 4]);
        assert(l2.empty);

        // Test merge when all elements from one list are smaller
        l1 = list!int(1, 2, 3);
        l2 = list!int(4, 5, 6);
        l1.merge(l2);
        assert(l1.array == [1, 2, 3, 4, 5, 6]);
        assert(l2.empty);

        // Test merge when all elements from one list are larger
        l1 = list!int(4, 5, 6);
        l2 = list!int(1, 2, 3);
        l1.merge(l2);
        assert(l1.array == [1, 2, 3, 4, 5, 6]);
        assert(l2.empty);
    }

    unittest {
        // Test basic sort
        list!int l = list!int(3, 1, 4, 1, 5, 9, 2, 6, 5, 3);
        l.sort();
        assert(l.array == [1, 1, 2, 3, 3, 4, 5, 5, 6, 9]);

        // Test already sorted list
        l = list!int(1, 2, 3, 4, 5);
        l.sort();
        assert(l.array == [1, 2, 3, 4, 5]);

        // Test reverse sorted list
        l = list!int(5, 4, 3, 2, 1);
        l.sort();
        assert(l.array == [1, 2, 3, 4, 5]);

        // Test list with duplicates
        l = list!int(3, 3, 3, 2, 2, 1, 1);
        l.sort();
        assert(l.array == [1, 1, 2, 2, 3, 3, 3]);

        // Test empty list
        l = list!int();
        l.sort();
        assert(l.empty);

        // Test single element list
        l = list!int(1);
        l.sort();
        assert(l.array == [1]);

        // Test two element list
        l = list!int(2, 1);
        l.sort();
        assert(l.array == [1, 2]);

        // Test list with negative numbers
        l = list!int(-3, 4, -1, 5, -2, 6);
        l.sort();
        assert(l.array == [-3, -2, -1, 4, 5, 6]);
    }

    unittest {
        // Test reverse
        list!int l = list!int(1, 2, 3, 4, 5);
        l.reverse();
        assert(l.array == [5, 4, 3, 2, 1]);

        // Test reverse with two elements
        l = list!int(1, 2);
        l.reverse();
        assert(l.array == [2, 1]);

        // Test reverse with one element
        l = list!int(1);
        l.reverse();
        assert(l.array == [1]);

        // Test reverse with empty list
        l = list!int();
        l.reverse();
        assert(l.empty);

        // Test reverse twice returns to original
        l = list!int(1, 2, 3);
        l.reverse();
        l.reverse();
        assert(l.array == [1, 2, 3]);
    }

    unittest {
        // Test unique on sorted list
        list!int l = list!int(1, 1, 2, 2, 2, 3, 3, 4, 5, 5);
        l.unique();
        assert(l.array == [1, 2, 3, 4, 5]);

        // Test unique on already unique list
        l = list!int(1, 2, 3, 4, 5);
        l.unique();
        assert(l.array == [1, 2, 3, 4, 5]);

        // Test unique on empty list
        l = list!int();
        l.unique();
        assert(l.empty);

        // Test unique on single element
        l = list!int(1);
        l.unique();
        assert(l.array == [1]);

        // Test unique on list with all same elements
        l = list!int(1, 1, 1, 1, 1);
        l.unique();
        assert(l.array == [1]);

        // Test unique on unsorted list (only removes consecutive duplicates)
        l = list!int(1, 2, 2, 1, 1, 3, 2);
        l.unique();
        assert(l.array == [1, 2, 1, 3, 2]);
    }
}