/* dub.sdl
name "test"
targetType "executable"
sourcePaths "test/"
importPaths "test/"
targetPath "../bin/"
dependency "clib" path="../"
*/
import clib;
// import clib.memory;

// import core.stdc.stdio;

extern(C) __gshared string[] rt_options = [ "gcopt=disable:1" ];
void main(string[] args)
    // @nogc nothrow
    {
    // { import core.memory; GC.disable(); }

    printf("Starting NOGC tests\n\n");
    class TestParent {}
    interface ITest {}
    class TestClass: TestParent, ITest { this() @nogc nothrow {} int i = 2; }

    __gshared TestClass tc = new TestClass();
    TestClass s = _new!TestClass();
    printf("%i\n", s.i);
    _free(s);
    printf("%s\n", typeid(tc).name.ptr);
    printf("\n");

    printf("No need to test type_info since it's GC compatible\n");

    queue!int q;
    q ~= 2;
    q.push(8, 3, 4, 5, 6);
    printf("%i\n", q.front());
    assert(q.pop() == 2);
    printf("%i\n", q.front());
    assert(q.pop() == 8);
    printf("%i\n", q.front());
    assert(q.pop() == 3);
    printf("%i\n", q.front());
    assert(q.pop() == 4);
    // still has 5 6
    q.push(8, 3, 4, 54, 6, 72, 18, 9, 10);
    q.limitLength(7); // cut 72
    vector!int v = q.array;
    for (int i = 0; i < v.size; ++i) {
        printf("%i, ", v[i]);
    }
    printf("\n");

    _try(() {
        _throw!bad_cast("Oh oh");
    })._catch((runtime_error e) {
        printf("RUNTIME %s - %s\n", e.what.ptr, e.msg);
    })._catch((bad_cast e) {
        printf("BAD CAST %s - %s\n", e.what.ptr, e.msg);
    })._catch((exception e) {
        printf("EXCEPTION %s - %s\n", e.what.ptr, e.msg);
    })._finally(() {
        printf("Finally\n");
    });
    printf("Ending tests\n");
    import std.traits;

    map!(int, char) m;

    // throw _new!Exception("test");
}

immutable(char)[] asString(bool val) {
    return val ? "true" : "false";
}


