// SPDX-FileCopyrightText: (C) 2023 Alisa Lain <al1-ce@null.net>
// SPDX-License-Identifier: OSL-3.0

/++
NoGC traits

Taken directly from std.traits

Contains only things that I've deemed necessary and ensures that no
std is used because nogc

However normally it's safe to use std.traits and std.meta with nogc
+/
module clib.traits;

auto assume_nogc_nothrow(T)(T t) if (IS_FUNCTION_POINTER!T || IS_DELEGATE!T) {
    import std.traits;
    enum attrs = FUNCTION_ATTRIBUTES!T
               | FunctionAttribute.nogc
               | FunctionAttribute.nothrow_;
    return cast(SET_FUNCTION_ATTRIBUTES!(T, iFUNCTION_LINKAGE!T, attrs)) t;
}

@nogc nothrow:

public import std.traits: fullyQualifiedName;

/**
 * Detect whether `T` is a built-in boolean type or enum of boolean base type.
 */
enum bool IS_BOOLEAN(T) = __traits(isUnsigned, T) && is(T : bool);

/**
 * Detect whether `T` is a built-in integral type.
 * Integral types are `byte`, `ubyte`, `short`, `ushort`, `int`, `uint`, `long`, `ulong`, `cent`, `ucent`,
 * and enums with an integral type as its base type.
 * Params:
 *      T = type to test
 * Returns:
 *      `true` if `T` is an integral type
 * Note:
 *      this is not the same as $(LINK2 https://dlang.org/spec/traits.html#IS_INTEGRAL, `__traits(IS_INTEGRAL)`)
 */
template IS_INTEGRAL(T)
{
    static if (!__traits(isIntegral, T))
        enum IS_INTEGRAL = false;
    else static if (is(T U == enum))
        enum IS_INTEGRAL = IS_INTEGRAL!U;
    else
        enum IS_INTEGRAL = __traits(isZeroInit, T) // Not char, wchar, or dchar.
            && !is(immutable T == immutable bool) && !is(T == __vector);
}

/**
 * Detect whether `T` is a built-in floating point type.
 *
 * See also: $(DDSUBLINK spec/traits, isFloating, `__traits(isFloating, T)`)
 */
// is(T : real) to discount complex types
enum bool IS_FLOATING_POINT(T) = __traits(isFloating, T) && is(T : real);

/**
 * Detect whether `T` is a built-in numeric type (integral or floating
 * point).
 */
template IS_NUMERIC(T)
{
    static if (!__traits(isArithmetic, T))
        enum IS_NUMERIC = false;
    else static if (__traits(isFloating, T))
        enum IS_NUMERIC = is(T : real); // Not __vector, imaginary, or complex.
    else static if (is(T U == enum))
        enum IS_NUMERIC = IS_NUMERIC!U;
    else
        enum IS_NUMERIC = __traits(isZeroInit, T) // Not char, wchar, or dchar.
            && !is(immutable T == immutable bool) && !is(T == __vector);
}

/**
 * Detect whether `T` is a scalar type (a built-in numeric, character or
 * boolean type).
 *
 * See also: $(DDSUBLINK spec/traits, isScalar, `__traits(isScalar, T)`)
 */
// is(T : real) to discount complex types
enum bool IS_SCALAR_TYPE(T) = __traits(isScalar, T) && is(T : real);

/**
 * Detect whether `T` is a basic type (scalar type or void).
 */
enum bool IS_BASIC_TYPE(T) = IS_SCALAR_TYPE!T || is(immutable T == immutable void);

/**
 * Detect whether `T` is a built-in unsigned numeric type.
 */
template IS_UNSIGNED(T)
{
    static if (!__traits(isUnsigned, T))
        enum IS_UNSIGNED = false;
    else static if (is(T U == enum))
        enum IS_UNSIGNED = IS_UNSIGNED!U;
    else
        enum IS_UNSIGNED = __traits(isZeroInit, T) // Not char, wchar, or dchar.
            && !is(immutable T == immutable bool) && !is(T == __vector);
}

/**
 * Detect whether `T` is a built-in signed numeric type.
 */
enum bool IS_SIGNED(T) = __traits(isArithmetic, T) && !__traits(isUnsigned, T)
                                                  && is(T : real);

/**
 * Detect whether `T` is one of the built-in character types.
 *
 * The built-in char types are any of `char`, `wchar` or `dchar`, with
 * or without qualifiers.
 */
template IS_SOME_CHAR(T)
{
    static if (!__traits(isUnsigned, T))
        enum IS_SOME_CHAR = false;
    else static if (is(T U == enum))
        enum IS_SOME_CHAR = IS_SOME_CHAR!U;
    else
        enum IS_SOME_CHAR = !__traits(isZeroInit, T);
}

/**
Detect whether `T` is one of the built-in string types.

The built-in string types are `Char[]`, where `Char` is any of `char`,
`wchar` or `dchar`, with or without qualifiers.

Static arrays of characters (like `char[80]`) are not considered
built-in string types.
 */
enum bool IS_SOME_STRING(T) = is(immutable T == immutable C[], C) && (is(C == char) || is(C == wchar) || is(C == dchar));

/**
 * Detect whether type `T` is a narrow string.
 *
 * All arrays that use char, wchar, and their qualified versions are narrow
 * strings. (Those include string and wstring).
 */
enum bool IS_NARROW_STRING(T) = is(immutable T == immutable C[], C) && (is(C == char) || is(C == wchar));

/**
 * Detects whether `T` is a comparable type. Basic types and structs and
 * classes that implement opCmp are ordering comparable.
 */
enum bool IS_ORDERING_COMPARABLE(T) = is(typeof((ref T a) => a < a ? 1 : 0));

/// ditto
enum bool IS_EQUALITY_COMPARABLE(T) = is(typeof((ref T a) => a == a ? 1 : 0));

/**
 * Detect whether type `T` is a static array.
 *
 * See also: $(DDSUBLINK spec/traits, IS_STATIC_ARRAY, `__traits(isStaticArray, T)`)
 */
enum bool IS_STATIC_ARRAY(T) = __traits(isStaticArray, T);

/**
 * Detect whether type `T` is a dynamic array.
 */
template IS_DYNAMIC_ARRAY(T)
{
    static if (is(T == U[], U))
        enum bool IS_DYNAMIC_ARRAY = true;
    else static if (is(T U == enum))
        // BUG: IS_DYNAMIC_ARRAY / IS_STATIC_ARRAY considers enums
        // with appropriate base types as dynamic/static arrays
        // Retain old behaviour for now, see
        // https://github.com/dlang/phobos/pull/7574
        enum bool IS_DYNAMIC_ARRAY = IS_DYNAMIC_ARRAY!U;
    else
        enum bool IS_DYNAMIC_ARRAY = false;
}

/**
 * Detect whether type `T` is an array (static or dynamic; for associative
 *  arrays see $(LREF IS_ASSOCIATIVE_ARRAY)).
 */
enum bool IS_ARRAY(T) = IS_STATIC_ARRAY!T || IS_DYNAMIC_ARRAY!T;

/**
 * Detect whether `T` is an associative array type
 *
 * See also: $(DDSUBLINK spec/traits, IS_ASSOCIATIVE_ARRAY, `__traits(isAssociativeArray, T)`)
 */
enum bool IS_ASSOCIATIVE_ARRAY(T) = __traits(isAssociativeArray, T);

/**
 * Detect whether type `T` is a builtin type.
 */
enum bool IS_BUILTIN_TYPE(T) = is(BUILTIN_TYPE_OF!T) && !IS_AGGREGATE_TYPE!T;

/**
 * Detect whether type `T` is a pointer.
 */
enum bool IS_POINTER(T) = is(T == U*, U);

/**
Returns the target type of a pointer.
*/
alias POINTER_TARGET(T : T*) = T;

/**
 * Detect whether type `T` is an aggregate type.
 */
enum bool IS_AGGREGATE_TYPE(T) = is(T == struct) || is(T == union) ||
                               is(T == class) || is(T == interface);

/**
 * Returns `true` if T can be iterated over using a `foreach` loop with
 * a single loop variable of automatically inferred type, regardless of how
 * the `foreach` loop is implemented.  This includes ranges, structs/classes
 * that define `opApply` with a single loop variable, and builtin dynamic,
 * static and associative arrays.
 */
enum bool IS_ITERABLE(T) = is(typeof({ foreach (elem; T.init) {} }));

/**
 * Returns true if T is not const or immutable.  Note that IS_MUTABLE is true for
 * string, or immutable(char)[], because the 'head' is mutable.
 */
enum bool IS_MUTABLE(T) = !is(T == const) && !is(T == immutable) && !is(T == inout);

/**
 * Returns true if T is an instance of the template S.
 */
enum bool IS_INSTANCE_OF(alias S, T) = is(T == S!Args, Args...);
/// ditto
template IS_INSTANCE_OF(alias S, alias T)
{
    enum impl(alias T : S!Args, Args...) = true;
    enum impl(alias T) = false;
    enum IS_INSTANCE_OF = impl!T;
}

/**
 * Check whether the tuple T is an expression tuple.
 * An expression tuple only contains expressions.
 *
 * See_Also: $(LREF IS_TYPE_TUPLE).
 */
template IS_EXPRESSION(T...)
{
    static foreach (Ti; T)
    {
        static if (!is(typeof(IS_EXPRESSION) == bool) && // not yet defined
                   (is(Ti) || !__traits(compiles, { auto ex = Ti; })))
        {
            enum IS_EXPRESSION = false;
        }
    }
    static if (!is(typeof(IS_EXPRESSION) == bool)) // if not yet defined
    {
        enum IS_EXPRESSION = true;
    }
}

/**
 * Check whether the tuple `T` is a type tuple.
 * A type tuple only contains types.
 *
 * See_Also: $(LREF IS_EXPRESSION).
 */
enum IS_TYPE_TUPLE(T...) =
{
    static foreach (U; T)
        static if (!is(U))
            if (__ctfe)
                return false;
    return true;
}();

/**
Detect whether symbol or type `T` is a function pointer.
 */
enum bool IS_FUNCTION_POINTER(alias T) = is(typeof(*T) == function);

/**
Detect whether symbol or type `T` is a delegate.
*/
enum bool IS_DELEGATE(alias T) = is(typeof(T) == delegate) || is(T == delegate);

/**
Detect whether symbol or type `T` is a function, a function pointer or a delegate.

Params:
    T = The type to check
Returns:
    A `bool`
 */
enum bool IS_SOME_FUNCTION(alias T) =
    is(T == return) ||
    is(typeof(T) == return) ||
    is(typeof(&T) == return); // @property

/**
Detect whether `T` is a callable object, which can be called with the
function call operator `$(LPAREN)...$(RPAREN)`.
 */
template IS_CALLABLE(alias callable)
{
    static if (is(typeof(&callable.opCall) == delegate))
        // T is a object which has a member function opCall().
        enum bool IS_CALLABLE = true;
    else static if (is(typeof(&callable.opCall) V : V*) && is(V == function))
        // T is a type which has a static member function opCall().
        enum bool IS_CALLABLE = true;
    else static if (is(typeof(&callable.opCall!()) TEMPLATE_INSTANCE_TYPW))
    {
        enum bool IS_CALLABLE = IS_CALLABLE!TEMPLATE_INSTANCE_TYPW;
    }
    else static if (is(typeof(&callable!()) TEMPLATE_INSTANCE_TYPW))
    {
        enum bool IS_CALLABLE = IS_CALLABLE!TEMPLATE_INSTANCE_TYPW;
    }
    else
    {
        enum bool IS_CALLABLE = IS_SOME_FUNCTION!callable;
    }
}

/**
Detect whether `S` is an abstract function.

See also: $(DDSUBLINK spec/traits, IS_ABSTRACT_FUNCTION, `__traits(isAbstractFunction, S)`)
Params:
    S = The symbol to check
Returns:
    A `bool`
 */
enum IS_ABSTRACT_FUNCTION(alias S) = __traits(isAbstractFunction, S);

/**
 * Detect whether `S` is a final function.
 *
 * See also: $(DDSUBLINK spec/traits, IS_FINAL_FUNCTION, `__traits(isFinalFunction, S)`)
 */
enum IS_FINAL_FUNCTION(alias S) = __traits(isFinalFunction, S);

/**
Determines if `f` is a function that requires a context pointer.

Params:
    f = The type to check
Returns
    A `bool`
*/
template IS_NESTED_FUNCTION(alias f)
{
    enum IS_NESTED_FUNCTION = __traits(isNested, f) && IS_SOME_FUNCTION!(f);
}

/**
 * Detect whether `S` is an abstract class.
 *
 * See also: $(DDSUBLINK spec/traits, IS_ABSTRACT_CLASS, `__traits(isAbstractClass, S)`)
 */
enum IS_ABSTRACT_CLASS(alias S) = __traits(isAbstractClass, S);

/**
 * Detect whether `S` is a final class.
 *
 * See also: $(DDSUBLINK spec/traits, IS_FINAL_CLASS, `__traits(isFinalClass, S)`)
 */
enum IS_FINAL_CLASS(alias S) = __traits(isFinalClass, S);

//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
// General Types
//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://

import core.internal.traits : CoreUnconst = Unconst;
alias UNCONST = CoreUnconst;

/++
    Removes `shared` qualifier, if any, from type `T`.

    Note that while `immutable` is implicitly `shared`, it is unaffected by
    UNSHARED. Only explict `shared` is removed.
  +/
template UNSHARED(T)
{
    static if (is(T == shared U, U))
        alias UNSHARED = U;
    else
        alias UNSHARED = T;
}

import core.internal.traits : CoreUnqual = Unqual;
alias UNQUAL = CoreUnqual;

/**
Returns the inferred type of the loop variable when a variable of type T
is iterated over using a `foreach` loop with a single loop variable and
automatically inferred return type.  Note that this may not be the same as
`std.range.ElementType!Range` in the case of narrow strings, or if T
has both opApply and a range interface.
*/
template FOREACH_TYPE(T)
{
    alias FOREACH_TYPE = typeof(
    (inout int x = 0)
    {
        foreach (elem; T.init)
        {
            return elem;
        }
        assert(0);
    }());
}

/**
 * Strips off all `enum`s from type `T`.
 */
template ORIGINAL_TYPE(T)
{
    import core.internal.traits : _ORIGINAL_TYPE = OriginalType;
    alias ORIGINAL_TYPE = _ORIGINAL_TYPE!T;
}

/**
Params:
    T = A built in integral or vector type.

Returns:
    The corresponding unsigned numeric type for `T` with the
    same type qualifiers.

    If `T` is not a integral or vector, a compile-time error is given.
 */
template UNSIGNED(T)
{
    template IMPL(T)
    {
        static if (is(T : __vector(V[N]), V, size_t N))
            alias IMPL = __vector(IMPL!V[N]);
        else static if (IS_UNSIGNED!T)
            alias IMPL = T;
        else static if (IS_SIGNED!T && !IS_FLOATING_POINT!T)
        {
            static if (is(T == byte )) alias IMPL = ubyte;
            static if (is(T == short)) alias IMPL = ushort;
            static if (is(T == int  )) alias IMPL = uint;
            static if (is(T == long )) alias IMPL = ulong;
            static if (is(ucent) && is(T == cent )) alias IMPL = ucent;
        }
        else
            static assert(false, "Type " ~ T.stringof ~
                                 " does not have an UNSIGNED counterpart");
    }

    alias UNSIGNED = MODIFY_TYPE_PRESERVING_TO!(IMPL, ORIGINAL_TYPE!T);
}

/**
Returns the largest type, i.e. T such that T.sizeof is the largest.  If more
than one type is of the same size, the leftmost argument of these in will be
returned.
*/
template LARGEST(T...)
if (T.length >= 1)
{
    alias LARGEST = T[0];
    static foreach (U; T[1 .. $])
        LARGEST = SELECT!(U.sizeof > LARGEST.sizeof, U, LARGEST);
}

/**
Returns the corresponding signed type for T. T must be a numeric integral type,
otherwise a compile-time error occurs.
 */
template SIGNED(T)
{
    template IMPL(T)
    {
        static if (is(T : __vector(V[N]), V, size_t N))
            alias IMPL = __vector(IMPL!V[N]);
        else static if (IS_SIGNED!T)
            alias IMPL = T;
        else static if (IS_UNSIGNED!T)
        {
            static if (is(T == ubyte )) alias IMPL = byte;
            static if (is(T == ushort)) alias IMPL = short;
            static if (is(T == uint  )) alias IMPL = int;
            static if (is(T == ulong )) alias IMPL = long;
            static if (is(ucent) && is(T == ucent )) alias IMPL = cent;
        }
        else
            static assert(false, "Type " ~ T.stringof ~
                                 " does not have an SIGNED counterpart");
    }

    alias SIGNED = MODIFY_TYPE_PRESERVING_TO!(IMPL, ORIGINAL_TYPE!T);
}

/**
Returns the most negative value of the numeric type T.
*/
template MOST_NEGATIVE(T)
if (IS_NUMERIC!T || IS_SOME_CHAR!T || IS_BOOLEAN!T)
{
    static if (is(typeof(T.min_normal)))
        enum MOST_NEGATIVE = -T.max;
    else static if (T.min == 0)
        enum byte MOST_NEGATIVE = 0;
    else
        enum MOST_NEGATIVE = T.min;
}

/**
Get the type that a scalar type `T` will $(LINK2 $(ROOT_DIR)spec/type.html#integer-promotions, promote)
to in multi-term arithmetic expressions.
*/
template PROMOTED(T)
if (IS_SCALAR_TYPE!T)
{
    alias PROMOTED = COPY_TYPE_QUALIFIERS!(T, typeof(T.init + T.init));
}

/++
    Determine if a symbol has a given
    $(DDSUBLINK spec/attribute, uda, user-defined attribute).

    See_Also:
        $(LREF GET_UDAS)
  +/
enum HAS_UDA(alias symbol, alias attribute) = GET_UDAS!(symbol, attribute).length != 0;

/++
    Gets the matching $(DDSUBLINK spec/attribute, uda, user-defined attributes)
    from the given symbol.

    If the UDA is a type, then any UDAs of the same type on the symbol will
    match. If the UDA is a template for a type, then any UDA which is an
    instantiation of that template will match. And if the UDA is a value,
    then any UDAs on the symbol which are equal to that value will match.

    See_Also:
        $(LREF HAS_UDA)
  +/
template GET_UDAS(alias symbol, alias attribute)
{
    import std.meta : Filter;

    alias GET_UDAS = Filter!(IS_DESIRED_UDA!attribute, __traits(getAttributes, symbol));
}

private template IS_DESIRED_UDA(alias attribute)
{
    template IS_DESIRED_UDA(alias TO_CHECK)
    {
        static if (is(typeof(attribute)) && !__traits(isTemplate, attribute))
        {
            static if (__traits(compiles, TO_CHECK == attribute))
                enum IS_DESIRED_UDA = TO_CHECK == attribute;
            else
                enum IS_DESIRED_UDA = false;
        }
        else static if (is(typeof(TO_CHECK)))
        {
            static if (__traits(isTemplate, attribute))
                enum IS_DESIRED_UDA =  IS_INSTANCE_OF!(attribute, typeof(TO_CHECK));
            else
                enum IS_DESIRED_UDA = is(typeof(TO_CHECK) == attribute);
        }
        else static if (__traits(isTemplate, attribute))
            enum IS_DESIRED_UDA = IS_INSTANCE_OF!(attribute, TO_CHECK);
        else
            enum IS_DESIRED_UDA = is(TO_CHECK == attribute);
    }
}

/**
Params:
    symbol = The aggregate type or module to search
    attribute = The user-defined attribute to search for

Returns:
    All symbols within `symbol` that have the given UDA `attribute`.

Note:
    This is not recursive; it will not search for symbols within symbols such as
    nested structs or unions.
 */
template GET_SYMBOLS_BY_UDA(alias symbol, alias attribute)
{
    alias MEMBERS_WITH_UDA = GET_SYMBOLS_BY_UDAIMPL!(symbol, attribute, __traits(allMembers, symbol));

    // if the symbol itself has the UDA, tack it on to the front of the list
    static if (HAS_UDA!(symbol, attribute))
        alias GET_SYMBOLS_BY_UDA = AliasSeq!(symbol, MEMBERS_WITH_UDA);
    else
        alias GET_SYMBOLS_BY_UDA = MEMBERS_WITH_UDA;
}

private template GET_SYMBOLS_BY_UDAIMPL(alias symbol, alias attribute, names...)
{
    import std.meta : Alias, AliasSeq, Filter;
    static if (names.length == 0)
    {
        alias GET_SYMBOLS_BY_UDAIMPL = AliasSeq!();
    }
    else
    {
        alias tail = GET_SYMBOLS_BY_UDAIMPL!(symbol, attribute, names[1 .. $]);

        // Filtering inaccessible members.
        static if (!__traits(compiles, __traits(getMember, symbol, names[0])))
        {
            alias GET_SYMBOLS_BY_UDAIMPL = tail;
        }
        else
        {
            alias member = __traits(getMember, symbol, names[0]);

            // Filtering not compiled members such as alias of basic types.
            static if (isAliasSeq!member ||
                       (IS_TYPE!member && !IS_AGGREGATE_TYPE!member && !is(member == enum)))
            {
                alias GET_SYMBOLS_BY_UDAIMPL = tail;
            }
            // If a symbol is overloaded, get UDAs for each overload (including templated overlaods).
            else static if (__traits(getOverloads, symbol, names[0], true).length > 0)
            {
                enum HAS_SPECIFIC_UDA(alias member) = HAS_UDA!(member, attribute);
                alias OVERLOADS_WITH_UDA = Filter!(HAS_SPECIFIC_UDA, __traits(getOverloads, symbol, names[0]));
                alias GET_SYMBOLS_BY_UDAIMPL = AliasSeq!(OVERLOADS_WITH_UDA, tail);
            }
            else static if (HAS_UDA!(member, attribute))
            {
                alias GET_SYMBOLS_BY_UDAIMPL = AliasSeq!(member, tail);
            }
            else
            {
                alias GET_SYMBOLS_BY_UDAIMPL = tail;
            }
        }
    }
}

/**
   Returns: `true` iff all types `Ts` are the same.
*/
enum bool ALL_SAME_TYPE(Ts...) =
{
    static foreach (T; Ts[Ts.length > 1 .. $])
        static if (!is(Ts[0] == T))
            if (__ctfe)  // Dodge the "statement is unreachable" warning
                return false;
    return true;
}();

/**
 * Detect whether `X` is a type. Analogous to `is(X)`. This is useful when used
 * in conjunction with other templates, e.g. `allSatisfy!(IS_TYPE, X)`.
 *
 * Returns:
 *      `true` if `X` is a type, `false` otherwise
 */
enum IS_TYPE(alias X) = is(X);

/**
 * Detect whether symbol or type `X` is a function. This is different that finding
 * if a symbol is callable or satisfying `is(X == function)`, it finds
 * specifically if the symbol represents a normal function declaration, i.e.
 * not a delegate or a function pointer.
 *
 * Returns:
 *     `true` if `X` is a function, `false` otherwise
 *
 * See_Also:
 *     Use $(LREF IS_FUNCTION_POINTER) or $(LREF IS_DELEGATE) for detecting those types
 *     respectively.
 */
template IS_FUNCTION(alias X)
{
    static if (is(typeof(&X) U : U*) && (is(U == function) ||
               is(typeof(&X) U == delegate)))
    {
        // x is a (nested) function symbol.
        enum IS_FUNCTION = true;
    }
    else static if (is(X T))
    {
        // x is a type.  Take the type of it and examine.
        enum IS_FUNCTION = is(T == function);
    }
    else
        enum IS_FUNCTION = false;
}

/**
 * Detect whether `X` is a final method or class.
 *
 * Returns:
 *     `true` if `X` is final, `false` otherwise
 */
template IS_FINAL(alias X)
{
    static if (is(X == class))
        enum IS_FINAL = __traits(isFinalClass, X);
    else static if (IS_FUNCTION!X)
        enum IS_FINAL = __traits(isFinalFunction, X);
    else
        enum IS_FINAL = false;
}

/++
 + Determines whether the type `S` can be copied.
 + If a type cannot be copied, then code such as `MyStruct x; auto y = x;` will fail to compile.
 + Copying for structs can be disabled by using `@disable this(this)`.
 +
 + See also: $(DDSUBLINK spec/traits, IS_COPYABLE, `__traits(isCopyable, S)`)
 + Params:
 +  S = The type to check.
 +
 + Returns:
 +  `true` if `S` can be copied. `false` otherwise.
 +/
enum IS_COPYABLE(S) = __traits(isCopyable, S);

