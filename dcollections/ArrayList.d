/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.ArrayList;
public import dcollections.model.List,
       dcollections.model.Keyed,
       std.array; // needed for range functions on arrays.

private struct Array
{
    int length;
    void *ptr;
}

private extern (C) long _adSort(Array arr, TypeInfo ti);

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

    unittest
    {
        auto al = new ArrayList!uint;
        al.add([0u, 1, 2, 3, 4]);
        foreach(ref p, i; &al.purge)
        {
            p = (i & 1);
        }

        assert(al == [0u, 2, 4]);
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

    unittest
    {
        auto al = new ArrayList!uint;
        al.add([1u, 2, 3, 4, 5]);
        foreach(ref p, k, i; &al.keypurge)
        {
            p = (k & 1);
        }

        assert(al == [1u, 3, 5]);
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

    unittest
    {
        auto al = new ArrayList!uint;
        al.add([1u, 2, 3, 4, 5]);
        auto cu = al.elemAt(2);
        assert(!cu.empty);
        assert(cu.front == 3);
        assert((cu.front = 8)  == 8);
        assert(cu.front  == 8);
        assert(al == [1u, 2, 8, 4, 5]);
        cu.popFront();
        assert(cu.empty);
        assert(al == [1u, 2, 8, 4, 5]);
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

    unittest
    {
        auto al = new ArrayList!uint;
        al.add([1u, 2, 3, 4, 5]);
        al.remove(al[2..4]);
        assert(al == [1u, 2, 5]);
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

    unittest
    {
        auto al = new ArrayList!uint;
        al.add([1u, 2, 3, 4, 5]);
        al.remove(al.elemAt(2));
        assert(al == [1u, 2, 4, 5]);
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

    unittest
    {
        auto al = new ArrayList!uint;
        al.add([1u, 2, 3, 4, 5]);
        bool wasAdded = true;
        assert(al.set(2, 8, wasAdded)[2] == 8);
        assert(!wasAdded);
        assert(al.set(3, 10)[3] == 10);
        assert(al == [1u, 2, 8, 10, 5]);
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

    unittest
    {
        auto al = new ArrayList!uint;
        al.add([1u, 2, 3, 4, 5]);
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

    unittest
    {
        // add single element
        bool wasAdded = false;
        auto al = new ArrayList!uint;
        al.add(1u);
        al.add(2u, wasAdded);
        assert(al.length == 2);
        assert(al == [1u, 2]);
        assert(wasAdded);

        // add other collection
        uint numAdded = 0;
        al.add(al, numAdded);
        al.add(al);
        assert(al == [1u, 2, 1, 2, 1, 2, 1, 2]);
        assert(numAdded == 2);

        // add array
        al.clear();
        al.add([1u, 2, 3, 4, 5]);
        al.add([1u, 2, 3, 4, 5], numAdded);
        assert(al == [1u, 2, 3, 4, 5, 1, 2, 3, 4, 5]);
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

    unittest
    {
        auto al = new ArrayList!uint;
        al.add([1u, 2, 3, 4, 5]);
        auto al2 = al.concat(al);
        assert(al2 !is al);
        assert(al2 == [1u, 2, 3, 4, 5, 1, 2, 3, 4, 5]);
        assert(al == [1u, 2, 3, 4, 5]);

        al2 = al.concat([6u, 7, 8, 9, 10]);
        assert(al2 !is al);
        assert(al2 == [1u, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
        assert(al == [1u, 2, 3, 4, 5]);

        al2 = al.concat_r([6u, 7, 8, 9, 10]);
        assert(al2 !is al);
        assert(al2 == [6u, 7, 8, 9, 10, 1, 2, 3, 4, 5]);
        assert(al == [1u, 2, 3, 4, 5]);

        /** this currently doesn't work but should **/
        version(none)
        {
            al2 = al ~ al;
            assert(al2 !is al);
            assert(al2 == [1u, 2, 3, 4, 5, 1, 2, 3, 4, 5]);
            assert(al == [1u, 2, 3, 4, 5]);

            al2 = al ~ [6u, 7, 8, 9, 10];
            assert(al2 !is al);
            assert(al2 == [1u, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
            assert(al == [1u, 2, 3, 4, 5]);

            al2 = [6u, 7, 8, 9, 10] ~ al;
            assert(al2 !is al);
            assert(al2 == [6u, 7, 8, 9, 10, 1, 2, 3, 4, 5]);
            assert(al == [1u, 2, 3, 4, 5]);
        }
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
        assert(e.ptr >= b.ptr && e.ptr <= end.ptr && b.ptr >= begin.ptr);
        return b.ptr[0..(e.ptr-b.ptr)];
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

    unittest
    {
        auto al = new ArrayList!uint;
        al.add(1u);
        al.add(2u);
        auto al2 = al.dup;
        assert(al._array !is al2._array);
        assert(al == al2);
        al[0] = 0;
        al.add(3u);
        assert(al2 == [1u, 2]);
        assert(al == [0u, 2, 3]);
    }

    /**
     * operator to compare two objects.
     *
     * If o is a List!(V), then this does a list compare.
     * If o is null or not an ArrayList, then the return value is 0.
     */
    bool opEquals(Object o)
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
                            return 0;
                    }

                    //
                    // equal
                    //
                    return 1;
                }
            }

        }
        //
        // no comparison possible.
        //
        return 0;
    }

    /**
     * Compare to a V array.
     *
     * equivalent to this[] == array.
     */
    int opEquals(V[] array)
    {
        return _array == array;
    }

    /**
     *  Look at the element at the front of the ArrayList.
     */
    @property V front() const
    {
        return _array[0];
    }

    /**
     * Look at the element at the end of the ArrayList.
     */
    @property V back() const
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

    unittest
    {
        auto al = new ArrayList!uint;
        al.add([1u, 2, 3, 4, 5]);
        assert(al.take() == 5);
        assert(al == [1u, 2, 3, 4]);
    }

    /**
     * Get the index of a particular cursor.
     */
    uint indexOf(cursor c)
    {
        assert(c.ptr >= begin.ptr);
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

    class SpecialTypeInfo(bool useFunction) : TypeInfo
    {
        static if(useFunction)
            alias int function(ref V v1, ref V v2) CompareFunction;
        else
            alias int delegate(ref V v1, ref V v2) CompareFunction;
        private CompareFunction cf;
        private TypeInfo derivedFrom;
        this(TypeInfo derivedFrom, CompareFunction comp)
        {
            this.derivedFrom = derivedFrom;
            this.cf = comp;
        }

        /// Returns a hash of the instance of a type.
        override hash_t getHash(in void *p) { return derivedFrom.getHash(p); }

        /// Compares two instances for equality.
        override bool equals(in void *p1, in void *p2) { return derivedFrom.equals(p1, p2); }

        /// Compares two instances for &lt;, ==, or &gt;.
        override int compare(in void *p1, in void *p2)
        {
            return cf(*cast(V *)p1, *cast(V *)p2);
        }

        /// Returns size of the type.
        override size_t tsize() { return derivedFrom.tsize(); }

        /// Swaps two instances of the type.
        override void swap(void *p1, void *p2)
        {
            return derivedFrom.swap(p1, p2);
        }

        /// Get TypeInfo for 'next' type, as defined by what kind of type this is,
        /// null if none.
        override TypeInfo next() { return derivedFrom; }

        /// Return default initializer, null if default initialize to 0
        override void[] init() { return derivedFrom.init(); }

        /// Get flags for type: 1 means GC should scan for pointers
        override uint flags() { return derivedFrom.flags(); }

        /// Get type information on the contents of the type; null if not available
        override OffsetTypeInfo[] offTi() { return derivedFrom.offTi(); }
    }

    /**
     * Sort according to a given comparison function
     */
    ArrayList sort(scope int delegate(ref V v1, ref V v2) comp)
    {
        //
        // can't really do this without extra library help.  Luckily, the
        // function to sort an array is always defined by the runtime.  We
        // just need to access it.  However, it requires that we pass in a
        // TypeInfo structure to do all the dirty work.  What we need is a
        // derivative of the real TypeInfo structure with the compare function
        // overridden to call the comp function.
        //
        scope sti = new SpecialTypeInfo!(false)(typeid(V), comp);
        int x;
        Array ar;
        ar.length = _array.length;
        ar.ptr = _array.ptr;
        _adSort(ar, sti);
        return this;
    }

    /**
     * Sort according to a given comparison function
     */
    ArrayList sort(int function(ref V v1, ref V v2) comp)
    {
        //
        // can't really do this without extra library help.  Luckily, the
        // function to sort an array is always defined by the runtime.  We
        // just need to access it.  However, it requires that we pass in a
        // TypeInfo structure to do all the dirty work.  What we need is a
        // derivative of the real TypeInfo structure with the compare function
        // overridden to call the comp function.
        //
        scope sti = new SpecialTypeInfo!(true)(typeid(V), comp);
        int x;
        Array ar;
        ar.length = _array.length;
        ar.ptr = _array.ptr;
        _adSort(ar, sti);
        return this;
    }

    /**
     * Sort according to the default comparison routine for V
     */
    ArrayList sort()
    {
        _array.sort;
        return this;
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
    auto al = new ArrayList!(uint);
    al.add([0U, 1, 2, 3, 4, 5]);
    assert(al.length == 6);
    al.add(al[0..3]);
    assert(al.length == 9);
    foreach(ref dp, uint idx, uint val; &al.keypurge)
        dp = (val % 2 == 1);
    assert(al.length == 5);
    assert(al == [0U, 2, 4, 0, 2]);
    assert(al == new ArrayList!(uint)([0U, 2, 4, 0, 2]));
    assert(al.begin.ptr is al[].ptr);
    assert(al.end.ptr is al[].ptr + al.length);
}
