/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.ArrayList;
public import dcollections.model.List,
       dcollections.model.Keyed,
       std.array; // needed for range functions on arrays.
private import dcollections.DefaultFunctions;

version(unittest) private import std.traits;

/***
 * This class is a wrapper around an array which provides the necessary
 * implemenation to implement the List interface
 *
 * Adding or removing any element invalidates all cursors.
 *
 * This class serves as the gateway between builtin arrays and dcollection
 * classes.  You can construct an ArrayList with a builtin array serving as
 * the storage, and you can access the ArrayList as an array with the asArray
 * function.  Neither of these make copies of the array, so you can continue
 * to use the array in both forms.
 */
class ArrayList(V) : Keyed!(uint, V), List!(V) 
{
    version(unittest) private enum doUnittest = isIntegral!V;
    else private enum doUnittest = false;

    private V[] _array;

    /**
     * Iterate over the elements in the ArrayList, telling it which ones
     * should be removed
     *
     * Use like this:
     *
     * -------------
     * // remove all odd elements
     * foreach(ref doRemove, v; &arrayList.purge)
     * {
     *   doRemove = (v & 1) != 0;
     * }
     * ------------
     */
    final int purge(scope int delegate(ref bool doRemove, ref V value) dg)
    {
        return _apply(dg, _array);
    }

    static if(doUnittest) unittest
    {
        auto al = new ArrayList;
        al.add(cast(V[])[0, 1, 2, 3, 4]);
        foreach(ref p, i; &al.purge)
        {
            p = (i & 1);
        }

        assert(al == cast(V[])[0, 2, 4]);
    }

    /**
     * Iterate over the elements in the ArrayList, telling it which ones
     * should be removed.
     *
     * Use like this:
     * -------------
     * // remove all odd indexes
     * foreach(ref doRemove, k, v; &arrayList.purge)
     * {
     *   doRemove = (k & 1) != 0;
     * }
     * ------------
     */
    final int keypurge(scope int delegate(ref bool doRemove, ref uint key, ref V value) dg)
    {
        return _apply(dg, _array);
    }

    static if(doUnittest) unittest
    {
        auto al = new ArrayList;
        al.add(cast(V[])[1, 2, 3, 4, 5]);
        foreach(ref p, k, i; &al.keypurge)
        {
            p = (k & 1);
        }

        assert(al == cast(V[])[1, 3, 5]);
    }

    /**
     * The array cursor gives a reference to an element in the array.
     *
     * All operations on the cursor are O(1)
     */
    struct cursor
    {
        private V *ptr;
        private bool _empty = false;
        
        /**
         * get the value pointed to
         */
        @property V front()
        {
            assert(!_empty, "Attempting to read the value of an empty cursor of " ~ ArrayList.stringof);
            return *ptr;
        }

        /**
         * set the value pointed to
         */
        @property V front(V v)
        {
            assert(!_empty, "Attempting to write the value of an empty cursor of " ~ ArrayList.stringof);
            return (*ptr = v);
        }

        /**
         * pop the front of the cursor.  This only is valid if the cursor is
         * not empty.  Normally you do not use this, but it allows the cursor
         * to be considered a range, convenient for passing to range-accepting
         * functions.
         */
        void popFront()
        {
            assert(!_empty, "Attempting to popFront() an empty cursor of " ~ ArrayList.stringof);
            ptr++;
            _empty = true;
        }

        /**
         * returns true if this cursor does not point to a valid element.
         */
        @property bool empty()
        {
            return _empty;
        }

        /**
         * compare two cursors for equality.  Note that only the position of
         * the cursor is checked, whether it's empty or not is not checked.
         */
        bool opEquals(ref const(cursor) it) const
        {
            return it.ptr is ptr;
        }
    }

    static if(doUnittest) unittest
    {
        auto al = new ArrayList;
        al.add(cast(V[])[1, 2, 3, 4, 5]);
        auto cu = al.elemAt(2);
        assert(!cu.empty);
        assert(cu.front == 3);
        assert((cu.front = 8)  == 8);
        assert(cu.front  == 8);
        assert(al == cast(V[])[1, 2, 8, 4, 5]);
        cu.popFront();
        assert(cu.empty);
        assert(al == cast(V[])[1, 2, 8, 4, 5]);
    }


    /**
     * An array list range is a D builtin array.  Using the builtin array
     * allows for all possible array functions already present in the library.
     */
    alias V[] range;

    /**
     * Use an array as the backing storage.  This does not duplicate the
     * array.  Use new ArrayList(storage.dup) to make a distinct copy.
     */
    this(V[] storage = null)
    {
        _array = storage;
    }

    /**
     * clear the container of all values.  Note that unlike arrays, it is no
     * longer safe to use elements that were in the array list.  This is
     * consistent with the other container types.
     */
    ArrayList clear()
    {
        _array.length = 0;
        _array.assumeSafeAppend();
        return this;
    }

    /**
     * return the number of elements in the collection
     */
    @property uint length() const
    {
        return _array.length;
    }

    /**
     * return a cursor that points to the first element in the list.
     */
    @property cursor begin()
    {
        return _array.begin;
    }

    /**
     * return a cursor that points to just beyond the last element in the
     * list.  The cursor will be empty, so you cannot call front on it.
     */
    @property cursor end()
    {
        return _array.end;
    }

    private int _apply(scope int delegate(ref bool, ref uint, ref V) dg, range r)
    {
        int dgret;
        auto i = r.ptr;
        auto nextGood = i;
        auto last = r.ptr + r.length;
        auto endref = end.ptr;

        bool doRemove;

        //
        // loop before removal
        //
        for(; dgret == 0 && i != last; i++, nextGood++)
        {
            doRemove = false;
            uint key = i - _array.ptr;
            if((dgret = dg(doRemove, key, *i)) == 0)
            {
                if(doRemove)
                {
                    //
                    // first removal
                    //
                    i++;
                    break;
                }
            }
        }

        //
        // loop after first removal
        //
        if(nextGood != i)
        {
            for(; i < endref; i++, nextGood++)
            {
                doRemove = false;
                uint key = i - _array.ptr;
                if(i >= last || dgret != 0 || (dgret = dg(doRemove, key, *i)) != 0 || !doRemove)
                {
                    //
                    // either not calling dg any more or doRemove was
                    // false.
                    //
                    *nextGood = *i;
                }
                else
                {
                    //
                    // dg requested a removal
                    //
                    nextGood--;
                }
            }
        }

        //
        // shorten the length
        //
        if(nextGood != endref)
        {
            // TODO: we know we are always shrinking.  So we should probably
            // set the length value directly rather than calling the runtime
            // function.
            _array.length = nextGood - _array.ptr;
            _array.assumeSafeAppend();
        }
        return dgret;
    }

    private int _apply(scope int delegate(ref bool, ref V) dg, range r)
    {
        int _dg(ref bool b, ref uint k, ref V v)
        {
            return dg(b, v);
        }
        return _apply(&_dg, r);
    }

    /**
     * remove all the elements in the given range.  Returns a valid cursor that
     * points to the element just beyond the given range
     *
     * Runs in O(n) time.
     */
    cursor remove(range r)
    in
    {
        assert(r.ptr >= _array.ptr);
        assert(r.ptr + r.length <= _array.ptr + _array.length);
    }
    body
    {
        int check(ref bool b, ref V)
        {
            b = true;
            return 0;
        }
        _apply(&check, r);
        return cursor(r.ptr);
    }

    static if(doUnittest) unittest
    {
        auto al = new ArrayList;
        al.add(cast(V[])[1, 2, 3, 4, 5]);
        al.remove(al[2..4]);
        assert(al == cast(V[])[1, 2, 5]);
    }

    /**
     * remove the element pointed to by elem.  Returns a cursor to the element
     * just beyond this one.
     *
     * Runs in O(n) time
     */
    cursor remove(cursor elem)
    {
        return remove(elem.ptr[0..1]);
    }

    static if(doUnittest) unittest
    {
        auto al = new ArrayList;
        al.add(cast(V[])[1, 2, 3, 4, 5]);
        al.remove(al.elemAt(2));
        assert(al == cast(V[])[1, 2, 4, 5]);
    }

    /**
     * get a cursor at the given index
     */
    cursor elemAt(uint idx)
    {
        assert(idx < _array.length);
        cursor it;
        it.ptr = _array.ptr + idx;
        return it;
    }

    /**
     * get the value at the given index.
     */
    V opIndex(uint key)
    {
        return _array[key];
    }

    /**
     * set the value at the given index.
     */
    V opIndexAssign(V value, uint key)
    {
        return _array[key] = value;
    }

    /**
     * set the value at the given index
     */
    ArrayList set(uint key, V value, out bool wasAdded)
    {
        this[key] = value;
        wasAdded = false;
        return this;
    }

    /**
     * set the value at the given index
     */
    ArrayList set(uint key, V value)
    {
        this[key] = value;
        return this;
    }

    static if(doUnittest) unittest
    {
        auto al = new ArrayList;
        al.add(cast(V[])[1, 2, 3, 4, 5]);
        bool wasAdded = true;
        assert(al.set(2, 8, wasAdded)[2] == 8);
        assert(!wasAdded);
        assert(al.set(3, 10)[3] == 10);
        assert(al == cast(V[])[1, 2, 8, 10, 5]);
    }

    /**
     * iterate over the collection
     */
    int opApply(scope int delegate(ref V value) dg)
    {
        int retval;
        foreach(ref v; _array)
        {
            if((retval = dg(v)) != 0)
                break;
        }
        return retval;
    }

    /**
     * iterate over the collection with key and value
     */
    int opApply(scope int delegate(ref uint key, ref V value) dg)
    {
        int retval = 0;
        foreach(i, ref v; _array)
        {
            if((retval = dg(i, v)) != 0)
                break;
        }
        return retval;
    }

    static if(doUnittest) unittest
    {
        auto al = new ArrayList;
        al.add(cast(V[])[1, 2, 3, 4, 5]);
        uint idx = 0;
        foreach(i; al)
        {
            assert(i == al[idx++]);
        }
        assert(idx == al.length);
        idx = 0;
        foreach(k, i; al)
        {
            assert(idx == k);
            assert(i == idx + 1);
            assert(i == al[idx++]);
        }
        assert(idx == al.length);
    }

    /**
     * returns true if the given index is valid
     *
     * Runs in O(1) time
     */
    bool containsKey(uint key)
    {
        return key < length;
    }

    /**
     * add the given value to the end of the list.  Always returns true.
     */
    ArrayList add(V v, out bool wasAdded)
    {
        //
        // append to this array.
        //
        _array ~= v;
        wasAdded = true;
        return this;
    }

    /**
     * add the given value to the end of the list.
     */
    ArrayList add(V v)
    {
        bool ignored;
        return add(v, ignored);
    }

    /**
     * adds all elements from the given iterator to the end of the list.
     */
    ArrayList add(Iterator!(V) coll)
    {
        uint ignored;
        return add(coll, ignored);
    }

    /**
     * adds all elements from the given iterator to the end of the list.
     */
    ArrayList add(Iterator!(V) coll, out uint numAdded)
    {
        auto al = cast(ArrayList)coll;
        if(al)
        {
            //
            // optimized case
            //
            return add(al._array, numAdded);
        }

        //
        // generic case
        //
        numAdded = coll.length;
        if(numAdded != NO_LENGTH_SUPPORT)
        {
            if(numAdded > 0)
            {
                int i = _array.length;
                _array.length += numAdded;
                foreach(v; coll)
                    _array [i++] = v;
            }
        }
        else
        {
            auto origlength = _array.length;
            foreach(v; coll)
                _array ~= v;
            numAdded = _array.length - origlength;
        }
        return this;
    }


    /**
     * appends the array to the end of the list
     */
    ArrayList add(V[] array)
    {
        uint ignored;
        return add(array, ignored);
    }

    /**
     * appends the array to the end of the list
     */
    ArrayList add(V[] array, out uint numAdded)
    {
        numAdded = array.length;
        if(array.length)
        {
            _array ~= array;
        }
        return this;
    }

    static if(doUnittest) unittest
    {
        // add single element
        bool wasAdded = false;
        auto al = new ArrayList;
        al.add(1);
        al.add(2, wasAdded);
        assert(al.length == 2);
        assert(al == cast(V[])[1, 2]);
        assert(wasAdded);

        // add other collection
        uint numAdded = 0;
        al.add(al, numAdded);
        al.add(al);
        assert(al == cast(V[])[1, 2, 1, 2, 1, 2, 1, 2]);
        assert(numAdded == 2);

        // add array
        al.clear();
        al.add(cast(V[])[1, 2, 3, 4, 5]);
        al.add(cast(V[])[1, 2, 3, 4, 5], numAdded);
        assert(al == cast(V[])[1, 2, 3, 4, 5, 1, 2, 3, 4, 5]);
        assert(numAdded == 5);
    }


    /**
     * returns a concatenation of the array list and another list.
     */
    ArrayList concat(List!(V) rhs)
    {
        return dup().add(rhs);
    }

    /**
     * returns a concatenation of the array list and an array.
     */
    ArrayList concat(V[] array)
    {
        return new ArrayList(_array ~ array);
    }

    /**
     * returns a concatenation of the array list and an array.
     */
    ArrayList concat_r(V[] array)
    {
        return new ArrayList(array ~ _array);
    }

    version(testcompiler)
    {
    }
    else
    {
        // workaround for compiler deficiencies
        alias concat opCat;
        alias concat_r opCat_r;
        alias add opCatAssign;
    }

    static if(doUnittest) unittest
    {
        auto al = new ArrayList;
        al.add(cast(V[])[1, 2, 3, 4, 5]);
        auto al2 = al.concat(al);
        assert(al2 !is al);
        assert(al2 == cast(V[])[1, 2, 3, 4, 5, 1, 2, 3, 4, 5]);
        assert(al == cast(V[])[1, 2, 3, 4, 5]);

        al2 = al.concat(cast(V[])[6, 7, 8, 9, 10]);
        assert(al2 !is al);
        assert(al2 == cast(V[])[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
        assert(al == cast(V[])[1, 2, 3, 4, 5]);

        al2 = al.concat_r(cast(V[])[6, 7, 8, 9, 10]);
        assert(al2 !is al);
        assert(al2 == cast(V[])[6, 7, 8, 9, 10, 1, 2, 3, 4, 5]);
        assert(al == cast(V[])[1, 2, 3, 4, 5]);

        al2 = al ~ al;
        assert(al2 !is al);
        assert(al2 == cast(V[])[1, 2, 3, 4, 5, 1, 2, 3, 4, 5]);
        assert(al == cast(V[])[1, 2, 3, 4, 5]);

        al2 = al ~ cast(V[])[6, 7, 8, 9, 10];
        assert(al2 !is al);
        assert(al2 == cast(V[])[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
        assert(al == cast(V[])[1, 2, 3, 4, 5]);

        al2 = cast(V[])[6, 7, 8, 9, 10] ~ al;
        assert(al2 !is al);
        assert(al2 == cast(V[])[6, 7, 8, 9, 10, 1, 2, 3, 4, 5]);
        assert(al == cast(V[])[1, 2, 3, 4, 5]);
    }

    /**
     * Returns a slice of an array list.
     *
     * The returned slice begins at index b and ends at, but does not include,
     * index e.
     */
    range opSlice(uint b, uint e)
    {
        return _array[b..e];
    }

    /**
     * Slice an array given the cursors
     */
    range opSlice(cursor b, cursor e)
    {
        if(e.ptr >= b.ptr && e.ptr <= end.ptr && b.ptr >= begin.ptr)
            return b.ptr[0..(e.ptr-b.ptr)];
        throw new Exception("invalid slice parameters to " ~ ArrayList.stringof);
    }

    /**
     * get the array that this array represents.  This is NOT a copy of the
     * data, so modifying elements of this array will modify elements of the
     * original ArrayList.  Appending elements from this array will not affect
     * the original array list just like appending to an array will not affect
     * the original.
     */
    range opSlice()
    {
        return _array;
    }

    /**
     * Returns a copy of an array list
     */
    ArrayList dup()
    {
        return new ArrayList(_array.dup);
    }

    static if(doUnittest) unittest
    {
        auto al = new ArrayList;
        al.add(1);
        al.add(2);
        auto al2 = al.dup;
        assert(al._array !is al2._array);
        assert(al == al2);
        al[0] = 0;
        al.add(3);
        assert(al2 == cast(V[])[1, 2]);
        assert(al == cast(V[])[0, 2, 3]);
    }

    /**
     * operator to compare two objects.
     *
     * If o is a List!(V), then this does a list compare.
     * If o is null or not an ArrayList, then the return value is 0.
     */
    override bool opEquals(Object o)
    {
        if(o !is null)
        {
            auto li = cast(List!(V))o;
            if(li !is null && li.length == length)
            {
                auto al = cast(ArrayList)o;
                if(al !is null)
                    return _array == al._array;
                else
                {
                    int i = 0;
                    foreach(elem; li)
                    {
                        if(elem != _array[i++])
                            return false;
                    }

                    //
                    // equal
                    //
                    return true;
                }
            }

        }
        //
        // no comparison possible.
        //
        return false;
    }

    static if(doUnittest) unittest
    {
        auto al = new ArrayList;
        al.add(cast(V[])[1, 2, 3, 4, 5]);
        assert(al == al.dup);
    }

    /**
     * Compare to a V array.
     *
     * equivalent to this[] == array.
     */
    bool opEquals(V[] array)
    {
        return _array == array;
    }

    /**
     *  Look at the element at the front of the ArrayList.
     *  TODO: this should be inout
     */
    @property V front()
    {
        return _array[0];
    }

    /**
     * Look at the element at the end of the ArrayList.
     * TODO: this should be inout
     */
    @property V back()
    {
        return _array[$-1];
    }

    /**
     * Remove the element at the end of the ArrayList and return its value.
     */
    V take()
    {
        auto retval = _array[$-1];
        _array = _array[0..$-1];
        _array.assumeSafeAppend();
        return retval;
    }

    static if(doUnittest) unittest
    {
        auto al = new ArrayList;
        al.add(cast(V[])[1, 2, 3, 4, 5]);
        assert(al.take() == 5);
        assert(al == cast(V[])[1, 2, 3, 4]);
    }

    /**
     * Get the index of a particular cursor.
     */
    uint indexOf(cursor c)
    {
        assert(belongs(c));
        return c.ptr - begin.ptr;
    }

    /**
     * returns true if the given cursor belongs points to an element that is
     * part of the container.  If the cursor is the same as the end cursor,
     * true is also returned.
     */
    bool belongs(cursor c)
    {
        auto last = end;
        if(c.ptr == last.ptr && !c.empty)
            // a non-empty cursor which points past the array 
            return false;
        return c.ptr >= _array.ptr && c.ptr <= last.ptr;
    }

    bool belongs(range r)
    {
        return(r.ptr >= _array.ptr && r.ptr + r.length <= _array.ptr + _array.length);
    }

    static if(doUnittest) unittest
    {
        auto al = new ArrayList;
        al.add(cast(V[])[1, 2, 3, 4, 5]);
        auto cu = al.elemAt(2);
        assert(cu.front == 3);
        assert(al.belongs(cu));
        assert(al.indexOf(cu) == 2);
        auto r = al[0..2];
        assert(al.belongs(r));
        assert(al.indexOf(r.end) == 2);

        auto al2 = al.dup;
        assert(!al2.belongs(cu));
        assert(!al2.belongs(r));
    }

    /**
     * Sort according to a given comparison function
     */
    ArrayList sort(scope bool delegate(ref V v1, ref V v2) comp)
    {
        std.algorithm.sort!(comp)(_array);
        return this;
    }

    /**
     * Sort according to a given comparison function
     */
    ArrayList sort(bool function(ref V v1, ref V v2) comp)
    {
        std.algorithm.sort!(comp)(_array);
        return this;
    }

    /**
     * Sort according to the default comparison routine for V
     */
    ArrayList sort()
    {
        std.algorithm.sort!(DefaultLess!(V))(_array);
        return this;
    }

    /**
     * Sort the list according to the given compare functor.  This is
     * a templatized version, and so can be used with functors, and might be
     * inlined.
     *
     * TODO: this should be called sort
     * TODO: if bug 3051 is resolved, then this can probably be
     * sortX(alias less)()
     * instead.
     */
    ArrayList sortX(T)(T less)
    {
        std.algorithm.sort!less(_array);
        return this;
    }

    static if(doUnittest) unittest
    {
        auto al = new ArrayList;
        al.add(cast(V[])[1, 3, 5, 6, 4, 2]);
        al.sort();
        assert(al == cast(V[])[1, 2, 3, 4, 5, 6]);
        al.sort(delegate bool (ref V a, ref V b) { return b < a; });
        assert(al == cast(V[])[6, 5, 4, 3, 2, 1]);
        al.sort(function bool (ref V a, ref V b) { if((a ^ b) & 1) return cast(bool)(a & 1); return a < b; });
        assert(al == cast(V[])[1, 3, 5, 2, 4, 6]);

        struct X
        {
            V pivot;
            // if a and b are on both sides of pivot, sort normally, otherwise,
            // values >= pivot are treated less than values < pivot.
            bool opCall(V a, V b)
            {
                if(a < pivot)
                {
                    if(b < pivot)
                    {
                        return a < b;
                    }
                    return false;
                }
                else if(b >= pivot)
                {
                    return a < b;
                }
                return true;
            }
        }

        X x;
        x.pivot = 4;
        al.sortX(x);
        assert(al == cast(V[])[4, 5, 6, 1, 2, 3]);
    }
}

// some extra functions needed to support range functions guaranteed by dcollections.

/**
 * Get the begin cursor of an ArrayList range.
 */
@property ArrayList!(T).cursor begin(T)(T[] r)
{
    ArrayList!(T).cursor c;
    c.ptr = r.ptr;
    c._empty = r.empty;
    return c;
}

/**
 * Get the end cursor of an ArrayList range.
 */
@property ArrayList!T.cursor end(T)(T[] r)
{
    ArrayList!T.cursor c;
    c.ptr = r.ptr + r.length;
    c._empty = true;
    return c;
}

unittest
{
    // declare the array list types that should be unit tested.
    ArrayList!ubyte  al1;
    ArrayList!byte   al2;
    ArrayList!ushort al3;
    ArrayList!short  al4;
    ArrayList!uint   al5;
    ArrayList!int    al6;
    ArrayList!ulong  al7;
    ArrayList!long   al8;

    // ensure that reference types can be used
    ArrayList!(uint*) al9;
    class C {}
    ArrayList!C al10;
}
