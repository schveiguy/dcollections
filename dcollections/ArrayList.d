/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.ArrayList;
public import dcollections.model.List,
       dcollections.model.Keyed;

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
    final int purge(int delegate(ref bool doRemove, ref V value) dg)
    {
        return _apply(dg, _array);
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
    final int keypurge(int delegate(ref bool doRemove, ref uint key, ref V value) dg)
    {
        return _apply(dg, _array);
    }

    /**
     * The array cursor gives a reference to an element in the array.
     *
     * All operations on the cursor are O(1)
     */
    struct cursor
    {
        private V *ptr;
        
        /**
         * get the value pointed to
         */
        @property V value();
        {
            return *ptr;
        }

        /**
         * set the value pointed to
         */
        @property V value(V v)
        {
            return (*ptr = v);
        }

        /**
         * compare two cursors for equality.
         */
        bool opEquals(cursor it)
        {
            return it.ptr is ptr;
        }
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
     * clear the container of all values
     */
    ArrayList clear()
    {
        _array = null;
        return this;
    }

    /**
     * return the number of elements in the collection
     */
    @property uint length()
    {
        return _array.length;
    }

    /**
     * return a cursor that points to the first element in the list.
     */
    @property cursor begin()
    {
        cursor it;
        it.ptr = _array.ptr;
        return it;
    }

    /**
     * return a cursor that points to just beyond the last element in the
     * list.
     */
    @property cursor end()
    {
        cursor it;
        it.ptr = _array.ptr + _array.length;
        return it;
    }

    private int _apply(int delegate(ref bool, ref uint, ref V) dg, range r)
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
                if(i >= last || dgret != 0 || (dgret = dg(doRemove, key, *i.ptr)) != 0 || !doRemove)
                {
                    //
                    // either not calling dg any more or doRemove was
                    // false.
                    //
                    nextGood.value = i.value;
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
        }
        return dgret;
    }

    private int _apply(int delegate(ref bool, ref V) dg, range r)
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
    {
        int check(ref bool b, ref V)
        {
            b = true;
            return 0;
        }
        _apply(&check, r);
        return cursor(r.ptr);
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

    /**
     * remove an element with the specific value.  This is an O(n)
     * operation.  If the collection has duplicate instances, the first
     * element that matches is removed.
     *
     * returns this.
     *
     * Sets wasRemoved to true if the element existed and was removed.
     */
    ArrayList remove(V v, ref bool wasRemoved)
    {
        auto it = find(v);
        if(it == end)
            wasRemoved = false;
        else
        {
            remove(it);
            wasRemoved = true;
        }
        return this;
    }

    /**
     * remove an element with the specific value.  This is an O(n)
     * operation.  If the collection has duplicate instances, the first
     * element that matches is removed.
     *
     * returns this.
     */
    ArrayList remove(V v)
    {
        bool ignored;
        return remove(v, ignored);
    }

    /**
     * same as find(v), but start at given position.
     */
    cursor find(cursor it, V v)
    in
    {
        assert(it.ptr >= _array.ptr && it.ptr <= _array.ptr + _array.length);
    }
    body
    {
        auto last = end;
        while(it < last && it.value != v)
            it.ptr++;
        return it;
    }

    /**
     * find the first occurrence of an element in the list.  Runs in O(n)
     * time.
     */
    cursor find(V v)
    {
        return find(begin, v);
    }

    /**
     * returns true if the collection contains the value.  Runs in O(n) time.
     */
    bool contains(V v)
    {
        return find(v) < end;
    }

    /**
     * remove the element at the given index.  Runs in O(n) time.
     */
    ArrayList removeAt(uint key, ref bool wasRemoved)
    {
        if(key >= length)
        {
            wasRemoved = false;
        }
        else
        {
            remove(_array[key..key+1]);
            wasRemoved = true;
        }
        return this;
    }

    /**
     * remove the element at the given index.  Runs in O(n) time.
     */
    ArrayList removeAt(uint key)
    {
        bool ignored;
        return removeAt(key, ignored);
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
    ArrayList set(uint key, V value, ref bool wasAdded)
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

    /**
     * iterate over the collection
     */
    int opApply(int delegate(ref V value) dg)
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
    int opApply(int delegate(ref uint key, ref V value) dg)
    {
        int retval = 0;
        foreach(i, ref v; _array)
        {
            if((retval = dg(i, v)) != 0)
                break;
        }
        return retval;
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
    ArrayList add(V v, ref bool wasAdded)
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
    ArrayList add(Iterator!(V) coll, ref uint numAdded)
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
        if(numAdded != cast(uint)-1)
        {
            if(numAdded > 0)
            {
                int i = _array.length;
                _array.length = _array.length + numAdded;
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
    ArrayList add(V[] array, ref uint numAdded)
    {
        numAdded = array.length;
        if(array.length)
        {
            _array ~= array;
        }
        return this;
    }

    /**
     * append another list to the end of this list
     */
    ArrayList opCatAssign(List!(V) rhs)
    {
        return add(rhs);
    }

    /**
     * append an array to the end of this list
     */
    ArrayList opCatAssign(V[] array)
    {
        return add(array);
    }

    /**
     * returns a concatenation of the array list and another list.
     */
    ArrayList opCat(List!(V) rhs)
    {
        return dup.add(rhs);
    }

    /**
     * returns a concatenation of the array list and an array.
     */
    ArrayList opCat(V[] array)
    {
        return new ArrayList(_array ~ array);
    }

    /**
     * returns a concatenation of the array list and an array.
     */
    ArrayList opCat_r(V[] array)
    {
        return new ArrayList(array ~ _array);
    }

    /**
     * returns the number of instances of the given element value
     *
     * Runs in O(n) time.
     */
    uint count(V v)
    {
        uint instances = 0;
        foreach(x; this)
            if(v == x)
                instances++;
        return instances;
    }

    /**
     * removes all the instances of the given element value
     *
     * Runs in O(n) time.
     */
    ArrayList removeAll(V v, ref uint numRemoved)
    {
        auto origLength = length;
        foreach(ref b, x; &purge)
        {
            b = cast(bool)(x == v);
        }
        numRemoved = length - origLength;
        return this;
    }

    /**
     * removes all the instances of the given element value
     *
     * Runs in O(n) time.
     */
    ArrayList removeAll(V v)
    {
        uint ignored;
        return removeAll(v, ignored);
    }

    /**
     * Returns a slice of an array list.
     *
     * The returned slice begins at index b and ends at, but does not include,
     * index e.
     */
    range opSlice(uint b, uint e)
    {
        // TODO: throw range error if b > e
        return _array[b..e];
    }

    /**
     * Slice an array given the cursors
     */
    range opSlice(cursor b, cursor e)
    {
        if(e > end || b < begin || b > e) // call checkMutation once
            throw new Exception("slice values out of range");

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

    /**
     * operator to compare two objects.
     *
     * If o is a List!(V), then this does a list compare.
     * If o is null or not an ArrayList, then the return value is 0.
     */
    int opEquals(Object o)
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
     * Remove the element at the front of the ArrayList and return its value.
     * This is an O(n) operation.
     */
    V takeFront()
    {
        auto c = begin;
        auto retval = c.value;
        remove(c);
        return retval;
    }

    /**
     * Remove the element at the end of the ArrayList and return its value.
     * This can be an O(n) operation.
     */
    V takeBack()
    {
        auto c = end;
        c.ptr--;
        auto retval = c.value;
        remove(c);
        return retval;
    }

    /**
     * Get the index of a particular value.
     *
     * If the value isn't in the collection, returns length.
     */
    uint indexOf(V v)
    {
        return find(v).ptr - begin.ptr;
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
        override hash_t getHash(void *p) { return derivedFrom.getHash(p); }

        /// Compares two instances for equality.
        override int equals(void *p1, void *p2) { return derivedFrom.equals(p1, p2); }

        /// Compares two instances for &lt;, ==, or &gt;.
        override int compare(void *p1, void *p2)
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
    ArrayList sort(int delegate(ref V v1, ref V v2) comp)
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

version(UnitTest)
{
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
}
