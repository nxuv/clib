// SPDX-FileCopyrightText: (C) 2023 Alisa Lain <al1-ce@null.net>
// SPDX-License-Identifier: OSL-3.0

/// extern(C++) TypeInfo alternative
module clib.typeinfo;

// To prevent usage without reading readme (I hate when people are not reading readme)
// version(D_BetterC) { version = CLIB_USE_TYPEINFO; }
version(CLIB_USE_TYPEINFO):

import clib.string: strcmp;
import clib.traits;
import clib.conv;

import clib.memory;

/// LINK: https://github.com/ldc-developers/ldc/issues/2425
/// HACK: _d_array_slice_copy
version(LDC) extern(C) void _d_array_slice_copy(void* dst, size_t dstlen, void* src, size_t srclen, size_t elemsz){
    import ldc.intrinsics;
    llvm_memcpy!size_t(dst, src, dstlen * elemsz, 0);
}

// TODO: maybe store rtti in char[][]?

/// Use this as parent for all `extern(C++)` classes
/// if you want to have typeinfo
extern(C++) abstract class CppObject {
    this() @nogc nothrow {}

    /// Convert CppObject into human readable string
    const(char*) toString() const @nogc nothrow {
        // return cast(char*) __traits(identifier, typeof(this)).ptr;
        return _typeid(this).name;
    }

    /// Compute hash function for CppObject
    size_t toHash() const @trusted @nogc nothrow {
        size_t addr = cast(size_t) cast(void*) this;
        return addr ^ (addr >>> 4);
    }

    /// Compares with another object. (must implement, default compares hash)
    /// Returns:
    /// -1 if `this < o`
    ///  0 if `this == o`
    ///  1 if `this > o`
    int opCmp(CppObject o) const @nogc nothrow {
        size_t a = this.toHash();
        size_t b = o.toHash();
        if (a < b) return -1;
        if (a > b) return 1;
        return 0;
    }

    bool opEquals(CppObject o) const @nogc nothrow {
        return this is o;
    }

    void __clib_cpp_object_identifier() {}
}

/// D's TypeInfo alternative
struct type_info {
    /// Fully qualified type name
    const char* name = "\0".ptr;
    /// Is type a pointer
    const bool IS_POINTER = false;
    /// Is type a function
    const bool is_function = false;
    private const char[] _str_name;
    private bool _is_a_cpp_object = false;

    /// Returns fully qualified type name
    const(char*) toString() const { return name; }

    /// Returns 0
    size_t toHash() const @trusted @nogc nothrow {
        return 0;
    }

    int opCmp(CppObject other) const @nogc nothrow {
        return strcmp(name, _typeid(other).name);
    }

    int opCmp(type_info other) const @nogc nothrow {
        return strcmp(name, other.name);
    }

    bool opEquals(type_info other) const @nogc nothrow {
        return name == other.name;
    }

    bool opEquals(CppObject other) const @nogc nothrow {
        return name == _typeid(other).name;
    }

    /// Is T a child of type_info owner
    bool is_base_of(T)(T t) @nogc nothrow {
        return is_base_of!T;
    }

    /// Ditto
    bool is_base_of(T)() @nogc nothrow {
        if (IS_POINTER || is_function) return false;
        import clib.string: strlen, memcmp;
        if (!IS_SUBCLASS_OF_CPP_OBJECT!T) return false;
        if (_is_a_cpp_object) return true;
        char[200] s = ' ';
        char[] t = cast(char[]) _str_name;

        s[0..2] = cast(char[]) "__";

        for (int i = 0 ; i < t.length; ++i) {
            char c = t[i];
            if ( (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ) {
                s[2 + i] = c;
            } else {
                s[2 + i] = '_';
            }
        }

        s[(2 + t.length)..(2 + t.length + 13)] = "_clib_parent\0";

        foreach (m; __traits(allMembers, T)) {
            size_t ms = t.length + 14;
            if (memcmp(s.ptr, cast(char*) m.ptr, ms * char.sizeof) == 0) return true;
        }

        return false;
    }
}

/// Queries information about type
type_info _typeid(T)(T t) @nogc nothrow if (IS_SUITABLE_FOR_TYPEID!T) {
    return _typeid!T();
}

/// Ditto
type_info _typeid(T)() @nogc nothrow if (IS_SUITABLE_FOR_TYPEID!T) {
    type_info t = {
        cast(const(char*)) __traits(fullyQualifiedName, UNQUAL!T).ptr,
        IS_POINTER!T,
        IS_FUNCTION_POINTER!T || IS_DELEGATE!T,
        cast(const(char[])) __traits(fullyQualifiedName, UNQUAL!T),
        is(T == CppObject)
    };

    return t;
}

private bool IS_SUITABLE_FOR_TYPEID(T)() @nogc nothrow {
    static if (is(T == interface)) return true;
    const bool isPtr = IS_ANY_POINTER_TYPE!T;
    static if (!isPtr) {
        return IS_SUBCLASS_OF_CPP_OBJECT!T;
    } else {
        return true;
    }
}

private bool IS_SUBCLASS_OF_CPP_OBJECT(T)() @nogc nothrow if (!IS_ANY_POINTER_TYPE!T) {
    bool isCpp = __traits(getLinkage, T) == "C++";
    bool isObj = __traits(hasMember, T, "__clib_cpp_object_identifier");
    return isCpp && isObj;
}

private bool IS_ANY_POINTER_TYPE(T)() @nogc nothrow {
    return IS_POINTER!T || IS_FUNCTION_POINTER!T || IS_DELEGATE!T;
}

/// Injects RunTime Type Information (allows type_info to see inheritance)
mixin template RTTI(T) if ((IS_SUBCLASS_OF_CPP_OBJECT!T || is(T == interface)) && !is(T == CppObject)) {
    mixin( __cpp_class_inheritance_generator!T() );
}

char[200] __cpp_class_inheritance_generator(T)() {
    import clib.string: strlen;
    char[200] s = ' ';
    char[] t = cast(char[]) __traits(fullyQualifiedName, T);

    s[0..7] = cast(char[]) "void __";

    for (int i = 0 ; i < t.length; ++i) {
        char c = t[i];
        if ( (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ) {
            s[7 + i] = c;
        } else {
            s[7 + i] = '_';
        }
    }

    s[(7 + t.length)..(7 + t.length + 18)] = "_clib_parent (){}\0";
    return s;
}

