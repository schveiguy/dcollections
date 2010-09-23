/*********************************************************
   Copyright: (C) 2008-2010 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.Deque;

public import dcollections.model.List,
       dcollections.model.Keyed;

private import dcollections.DefaultFunctions;

/**
 * A list similar to ArrayList, but has O(1) append and prepend performance,
 * and random access.
 */
class Deque(V) : Keyed!(size_t, V), List!V
{
    private V[] _pre, _post;
    enum doUnittest = false;
    /**
     * The cursor type, used to refer to individual elements
     */
    struct cursor
    {
        private V *ptr;
        private bool _pre = false;
        private bool _empty = false;

        /**
         * get the value pointed to
         */
        @property V front()
        {
            assert(!_empty, "Attempting to read the value of an empty cursor of " ~ Deque.stringof);
            return _pre ? *(ptr-1) : *ptr;
        }
        
        /**
         * set the value pointed to
         */
        @property V front(V v)
        {
            assert(!_empty, "Attempting to write the value of an empty cursor of " ~ Deque.stringof);
            return (_pre ? *(ptr-1) : *ptr) = v;
        }

        /**
         * pop the front of the cursor.  This only is valid if the cursor is
         * not empty.  Normally you do not use this, but it allows the cursor
         * to be considered a range, convenient for passing to range-accepting
         * functions.
         */
        void popFront()
        {
            assert(!_empty, "Attempting to popFront() an empty cursor of " ~ Deque.stringof);
            if(_pre)
                --ptr;
            else
                ++ptr;
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
         * Length is trivial to add, allows cursors to be used in more
         * algorithms.
         */
        @property size_t length()
        {
            return _empty ? 0 : 1;
        }

        /**
         * opIndex costs nothing, and it allows more algorithms to accept
         * cursors.
         */
        @property V opIndex(size_t idx)
        {
            assert(idx < length, "Attempt to access invalid index on cursor of type " ~ Deque.stringof);
            return front;
        }

        /**
         * Save property needed to satisfy forwardRange requirements.
         */
        @property cursor save()
        {
            return this;
        }

        /**
         * compare two cursors for equality.  Note that only the position of
         * the cursor is checked, whether it's empty or not is not checked.
         *
         * also note that it's possible for two cursors to compare not equal
         * even though they point to the same element.  This situation is
         * caused by the fact that we have two separate arrays, and a cursor
         * pointing at the beginning of either array is pointing to the same
         * element.
         */
        bool opEquals(ref const(cursor) it) const
        {
            return it.ptr is ptr;
        }
    }

    /**
     * a random-access range for the Deque.
     */
    struct range
    {
        // a range that combines both the pre and post ranges.
        private V[] _pre, _post;

        @property ref V front()
        {
            return _pre.length ? _pre[$-1] : _post[0];
        }

        /* Note, we have disabled this and instead am using ref returns to get
         * sorting to work.  Need to work out how to use auto ref to avoid
         * this.
        @property V front(V v)
        {
            return (_pre.length ? _pre[$-1] : _post[0]) = v;
        }*/

        @property ref V back()
        {
            return _post.length ? _post[$-1] : _pre[0];
        }

        /* Note, we have disabled this and instead am using ref returns to get
         * sorting to work.  Need to work out how to use auto ref to avoid
         * this.
        @property V back(V v)
        {
            return (_post.length ? _post[$-1] : _pre[0]) = v;
        }*/

        void popFront()
        {
            if(_pre.length)
                _pre = _pre[0..$-1];
            else
                _post = _post[1..$];
        }

        void popBack()
        {
            if(_post.length)
                _post = _post[0..$-1];
            else
                _pre = _pre[1..$];
        }

        ref V opIndex(size_t key)
        {
            if(_pre.length > key)
                return _pre[$-1-key];
            else
                return _post[key - _pre.length];
        }

        /* Note, we have disabled this and instead am using ref returns to get
         * sorting to work.  Need to work out how to use auto ref to avoid
         * this.
           V opIndexAssign(V v, size_t key)
        {
            if(_pre.length > key)
                return _pre[$-1-key] = v;
            else
                return _post[key - _pre.length] = v;
        }*/

        range opSlice(size_t low, size_t hi)
        {
            assert(low <= hi, "invalid parameters used to slice " ~ Deque.stringof);
            range result;
            if(low < _pre.length)
            {
                if(hi < _pre.length)
                    result._pre = _pre[$-hi..$-low];
                else
                {
                    result._pre = _pre[0..$-low];
                    result._post = _post[0..hi-_pre.length];
                }
            }
            else
            {
                result._post = _post[low-_pre.length..hi-_pre.length];
            }
            return result;
        }

        @property size_t length()
        {
            return _pre.length + _post.length;
        } 

        @property bool empty()
        {
            return length == 0;
        }

        @property range save()
        {
            return this;
        }

        @property cursor begin()
        {
            cursor result;
            result._pre = _pre.length ? true : false;
            result.ptr = result._pre ? _pre.ptr + _pre.length : _post.ptr;
            result._empty = (length == 0);
            return result;
        }

        @property cursor end()
        {
            cursor result;
            result.ptr = _post.ptr + _post.length;
            result._empty = true;
            return result;
        }
    }

    /**
     * Use an array as the backing storage.  This does not duplicate the array.
     * Use new Deque(storage.dup) to make a distinct copy.
     */
    this(V[] storage...)
    {
        _post = storage;
    }

    /**
     * Constructor that uses the given iterator to get the initial elements.
     */
    this(Iterator!V initialElements)
    {
        add(initialElements);
    }

    static if(doUnittest) unittest
    {
        auto dq = new Deque(1, 2, 3, 4, 5);
        auto dq2 = new Deque(dq);
        assert(dq == dq2);
        dq[0] = 2;
        assert(dq != dq2);
    }

    /**
     * clear the container of all values.  Note that unlike arrays, it is no
     * longer safe to use elements that were in the array list.  This is
     * consistent with the other container types.
     */
    Deque clear()
    {
        _pre.length = _post.length = 0;
        _pre.assumeSafeAppend();
        _post.assumeSafeAppend();
        return this;
    }

    /**
     * return the number of elements in the collection
     */
    @property size_t length() const
    {
        return _pre.length + _post.length;
    }

    /**
     * return a cursor that points to the first element in the list.
     */
    @property cursor begin()
    {
        return this[].begin;
    }

    /**
     * return a cursor that points to just beyond the last element in the
     * list.  The cursor will be empty, so you cannot call front on it.
     */
    @property cursor end()
    {
        return this[].end;
    }

    private int _apply(scope int delegate(ref bool, ref size_t, ref V) dg, range r)
    {
        int dgret;

        // do the _pre array
        auto _prelength = _pre.length; // needed for _post iteration
        if(r._pre.length)
        {
            auto i = r._pre.ptr + r._pre.length - 1;
            auto nextGood = i;
            auto last = r._pre.ptr - 1;
            auto endref = _pre.ptr - 1;

            bool doRemove;

            //
            // loop before removal
            //
            for(; dgret == 0 && i != last; --i, --nextGood)
            {
                doRemove = false;
                size_t key = _pre.ptr + _pre.length - i - 1;
                if((dgret = dg(doRemove, key, *i)) == 0)
                {
                    if(doRemove)
                    {
                        //
                        // first removal
                        //
                        --i;
                        break;
                    }
                }
            }

            //
            // loop after first removal
            //
            if(nextGood != i)
            {
                for(; i != endref; --i, --nextGood)
                {
                    doRemove = false;
                    size_t key = _pre.ptr + _pre.length - i - 1;
                    if(i <= last || dgret != 0 || (dgret = dg(doRemove, key, *i)) != 0 || !doRemove)
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
                        ++nextGood;
                    }
                }
                //
                // shorten the length
                //
                // TODO: we know we are always shrinking.  So we should probably
                // set the length value directly rather than calling the runtime
                // function.
                _pre = _pre[nextGood - _pre.ptr..$];
            }

        }
        if(r._post.length)
        {
            // run the same algorithm as in ArrayList.
            auto i = r._post.ptr;
            auto nextGood = i;
            auto last = r._post.ptr + r._post.length;
            auto endref = _post.ptr + _post.length;

            bool doRemove;

            //
            // loop before removal
            //
            for(; dgret == 0 && i != last; ++i, ++nextGood)
            {
                doRemove = false;
                size_t key = i - _post.ptr + _prelength;
                if((dgret = dg(doRemove, key, *i)) == 0)
                {
                    if(doRemove)
                    {
                        //
                        // first removal
                        //
                        ++i;
                        break;
                    }
                }
            }

            //
            // loop after first removal
            //
            if(nextGood != i)
            {
                for(; i != endref; ++i, ++nextGood)
                {
                    doRemove = false;
                    size_t key = i - _post.ptr + _prelength;
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
                        --nextGood;
                    }
                }
                //
                // shorten the length
                //
                // TODO: we know we are always shrinking.  So we should probably
                // set the length value directly rather than calling the runtime
                // function.
                _post.length = nextGood - _post.ptr;
                _post.assumeSafeAppend();
            }
        }
        return dgret;
    }

    private int _apply(scope int delegate(ref bool, ref V) dg, range r)
    {
        int _dg(ref bool b, ref size_t k, ref V v)
        {
            return dg(b, v);
        }
        return _apply(&_dg, r);
    }

    /**
     * Iterate over the elements in the Deque, telling it which ones
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
    int purge(scope int delegate(ref bool doRemove, ref V value) dg)
    {
        return _apply(dg, this[]);
    }

    static if(doUnittest) unittest
    {
        auto al = new Deque;
        al.add(cast(V[])[0, 1, 2, 3, 4]);
        foreach(ref p, i; &al.purge)
        {
            p = (i & 1);
        }

        assert(al == cast(V[])[0, 2, 4]);
    }

    /**
     * Iterate over the elements in the Deque, telling it which ones
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
    int keypurge(scope int delegate(ref bool doRemove, ref size_t key, ref V value) dg)
    {
        return _apply(dg, this[]);
    }

    static if(doUnittest) unittest
    {
        auto al = new Deque;
        al.add(cast(V[])[1, 2, 3, 4, 5]);
        foreach(ref p, k, i; &al.keypurge)
        {
            p = (k & 1);
        }

        assert(al == cast(V[])[1, 3, 5]);
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
        assert(belongs(r));
    }
    body
    {
        int check(ref bool b, ref V)
        {
            b = true;
            return 0;
        }
        _apply(&check, r);
        cursor result;
        if(r._post.length)
        {
            result.ptr = r._post.ptr;
            result._empty = (_post.ptr + _post.length > result.ptr);
        }
        else if(r._pre.ptr == _pre.ptr)
        {
            result.ptr = _post.ptr;
            result._empty = (_post.length > 0);
        }
        else
        {
            // ptr will be in pre
            result.ptr = r._pre.ptr;
            result._pre = true;
        }
               
        return result;
    }

    static if(doUnittest) unittest
    {
        auto al = new Deque;
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
        if(elem._empty)
        {
            // nothing to remove, but we want to get the next element.
            if(elem._pre)
            {
                if(elem.ptr is _pre.ptr)
                {
                    elem.ptr = _post.ptr;
                    elem._empty = _post.length > 0;
                    elem._pre = false;
                }
                else
                    elem._empty = false;
            }
            else
            {
                elem._empty = (_post.ptr + _post.length == elem.ptr);
            }
            return elem;
        }
        else
        {
            range r;
            if(elem._pre)
                r._pre = (elem.ptr-1)[0..1];
            else
                r._post = elem.ptr[0..1];
            return remove(r);
        }
    }

    static if(doUnittest) unittest
    {
        auto al = new Deque;
        al.add(cast(V[])[1, 2, 3, 4, 5]);
        al.remove(al.elemAt(2));
        assert(al == cast(V[])[1, 2, 4, 5]);
    }

    /**
     * get a cursor at the given index
     */
    cursor elemAt(size_t idx)
    {
        assert(idx < length);
        cursor it;
        if(idx < _pre.length)
        {
            it._pre = true;
            it.ptr = _pre.ptr + (_pre.length - idx);
        }
        else
        {
            it.ptr = _post.ptr + (idx - _pre.length);
        }
        return it;
    }

    /**
     * get the value at the given index.
     */
    V opIndex(size_t key)
    {
        return elemAt(key).front;
    }

    /**
     * set the value at the given index.
     */
    V opIndexAssign(V value, size_t key)
    {
        return elemAt(key).front = value;
    }

    /**
     * set the value at the given index
     */
    Deque set(size_t key, V value, out bool wasAdded)
    {
        this[key] = value;
        wasAdded = false;
        return this;
    }

    /**
     * set the value at the given index
     */
    Deque set(size_t key, V value)
    {
        this[key] = value;
        return this;
    }

    static if(doUnittest) unittest
    {
        auto al = new Deque;
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
        int _dg(ref size_t, ref V value)
        {
            return dg(value);
        }
        return opApply(&_dg);
    }

    /**
     * iterate over the collection with key and value
     */
    int opApply(scope int delegate(ref size_t key, ref V value) dg)
    {
        int retval = 0;
        foreach(i; 0.._pre.length)
        {
            if((retval = dg(i, _pre[$-1-i])) != 0)
                break;
        }
        foreach(i; 0.._post.length)
        {
            size_t key = _pre.length + i;
            if((retval = dg(key, _post[i])) != 0)
                break;
        }
        return retval;
    }

    static if(doUnittest) unittest
    {
        auto al = new Deque;
        al.add(cast(V[])[1, 2, 3, 4, 5]);
        size_t idx = 0;
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
    bool containsKey(size_t key)
    {
        return key < length;
    }

    /**
     * add the given value to the end of the list.  Always returns true.
     */
    Deque add(V v, out bool wasAdded)
    {
        //
        // append to this array.
        //
        _post ~= v;
        wasAdded = true;
        return this;
    }

    /**
     * add the given value to the end of the list.
     */
    Deque add(V v)
    {
        bool ignored;
        return add(v, ignored);
    }

    /**
     * adds all elements from the given iterator to the end of the list.
     */
    Deque add(Iterator!(V) coll)
    {
        size_t ignored;
        return add(coll, ignored);
    }

    /**
     * adds all elements from the given iterator to the end of the list.
     */
    Deque add(Iterator!(V) coll, out uint numAdded)
    {
        //
        // generic case
        //
        numAdded = coll.length;
        if(numAdded != NO_LENGTH_SUPPORT)
        {
            if(numAdded > 0)
            {
                int i = _post.length;
                _post.length += numAdded;
                foreach(v; coll)
                    _post [i++] = v;
            }
        }
        else
        {
            auto origlength = _post.length;
            foreach(v; coll)
                _post ~= v;
            numAdded = _post.length - origlength;
        }
        return this;
    }


    /**
     * appends the array to the end of the list
     */
    Deque add(V[] array)
    {
        uint ignored;
        return add(array, ignored);
    }

    /**
     * appends the array to the end of the list
     */
    Deque add(V[] array, out uint numAdded)
    {
        numAdded = array.length;
        if(array.length)
        {
            _post ~= array;
        }
        return this;
    }

    static if(doUnittest) unittest
    {
        // add single element
        bool wasAdded = false;
        auto al = new Deque;
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

    // Deque specific functions
    Deque pushFront(V value, out bool wasAdded)
    {
        _pre ~= value;
        wasAdded = true;
        return this;
    }

    Deque pushFront(V value)
    {
        bool dummy;
        return pushFront(value, dummy);
    }


    /**
     * returns a concatenation of the array list and another list.
     */
    Deque concat(List!(V) rhs)
    {
        return dup().add(rhs);
    }

    /**
     * returns a concatenation of the array list and an array.
     */
    Deque concat(V[] array)
    {
        auto retval = new Deque();
        retval._pre = _pre.dup;
        retval._post = _post ~ array;
        return retval;
    }

    /**
     * returns a concatenation of the array list and an array.
     */
    Deque concat_r(V[] array)
    {
        auto retval = dup();

        if(array.length)
        {
            retval._pre ~= array; // prepending is easy, but we have to reverse
                                  // the order.
            retval._pre[_pre.length..$].reverse;
        }
        return retval;
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
        auto al = new Deque;
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
    range opSlice(size_t b, size_t e)
    {
        assert(b <= length && e <= length);
        range result;
        immutable prelen = _pre.length;
        if(b < prelen)
        {
            if(e < prelen)
            {
                result._pre = _pre[prelen-e..prelen-b];
            }
            else
            {
                result._pre = _pre[0..prelen-b];
                result._post = _post[0..e-prelen];
            }
        }
        else
        {
            result._post = _post[b-prelen..e-prelen];
        }
        return result;
    }

    /**
     * Slice an array given the cursors
     */
    range opSlice(cursor b, cursor e)
    {
        // Convert b and e to indexes, then use the index function to do the
        // hard work.
        return opSlice(indexOf(b), indexOf(e));
    }

    /**
     * get the array that this array represents.  This is NOT a copy of the
     * data, so modifying elements of this array will modify elements of the
     * original Deque.  Appending elements from this array will not affect
     * the original array list just like appending to an array will not affect
     * the original.
     */
    range opSlice()
    {
        range result;
        result._pre = _pre;
        result._post = _post;
        return result;
    }

    /**
     * Returns a copy of an array list
     */
    Deque dup()
    {
        auto result = new Deque();
        result._pre = _pre.dup;
        result._post = _post.dup;
        return result;
    }

    static if(doUnittest) unittest
    {
        auto al = new Deque;
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
     * If o is null or not an Deque, then the return value is 0.
     */
    override bool opEquals(Object o)
    {
        if(o !is null)
        {
            auto li = cast(List!(V))o;
            if(li !is null && li.length == length)
            {
                auto r = this[];
                foreach(elem; li)
                {
                    // NOTE this is a workaround for compiler bug 4088
                    static if(is(V == interface))
                    {
                        if(cast(Object)elem != cast(Object)r.front)
                            return false;
                    }
                    else
                    {
                        if(elem != r.front)
                            return false;
                    }
                    r.popFront();
                }

                //
                // equal
                //
                return true;
            }
        }
        //
        // no comparison possible.
        //
        return false;
    }

    static if(doUnittest) unittest
    {
        auto al = new Deque;
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
        // short circuit to avoid running through algorithm.equal when lengths
        // aren't equivalent.
        if(length != array.length)
            return false;
        // this is to work around compiler bug 4088 and 4589
        static if(is(V == interface))
        {
            return std.algorithm.equal!"cast(Object)a == cast(Object)b"(this[], array);
        }
        else
        {
            return std.algorithm.equal(this[], array);
        }
    }

    /**
     *  Look at the element at the front of the Deque.
     *  TODO: this should be inout
     */
    @property V front()
    {
        return _pre.length ? _pre[$-1] : _post[0];
    }

    /**
     * Look at the element at the end of the Deque.
     * TODO: this should be inout
     */
    @property V back()
    {
        return _post.length ? _post[$-1] : _pre[0];
    }

    /**
     * Remove the element at the end of the Deque and return its value.
     */
    V take()
    {
        V retval = void;
        if(_post.length)
        {
            retval = _post[$-1];
            _post = _post[0..$-1];
            _post.assumeSafeAppend();
        }
        else
        {
            retval = _pre[0];
            _pre = _pre[1..$];
        }
        return retval;
    }

    static if(doUnittest) unittest
    {
        auto al = new Deque;
        al.add(cast(V[])[1, 2, 3, 4, 5]);
        assert(al.take() == 5);
        assert(al == cast(V[])[1, 2, 3, 4]);
    }

    /**
     * Get the index of a particular cursor.
     */
    size_t indexOf(cursor c)
    {
        assert(belongs(c));
        if(c._pre)
        {
            return _pre.length - (c.ptr - _pre.ptr);
        }
        else
        {
            return _pre.length + (c.ptr - _post.ptr);
        }
    }

    /**
     * returns true if the given cursor belongs points to an element that is
     * part of the container.  If the cursor is the same as the end cursor,
     * true is also returned.
     */
    bool belongs(cursor c)
    {
        if(c._pre)
        {
            // points beyond the pre array, not a valid cursor
            if(c.ptr == _pre.ptr && !c.empty)
                return false;
            return c.ptr >= _pre.ptr && c.ptr - _pre.ptr <= _pre.length;
        }
        else
        {
            auto lastpost = _post.ptr + _post.length;
            if(c.ptr == lastpost && !c.empty)
                // points beyond the post array, not a valid cursor
                return false;
            return c.ptr >= _post.ptr && c.ptr <= lastpost;
        }
    }

    bool belongs(range r)
    {
        // ensure that r's pre and post are fully enclosed by our pre and post
        if(r._pre.length > 0)
        {
            if(r._post.length > 0)
            {
                if(r._pre.ptr != _pre.ptr || r._post.ptr != _post.ptr)
                    // strange range with more or less data in the middle
                    return false;
                return r._pre.length <= _pre.length &&
                    r._post.length <= _post.length;
            }
            else
            {
                return r._pre.ptr >= _pre.ptr && r._pre.ptr + r._pre.length <= _pre.ptr + _pre.length;
            }
        }
        return r._post.ptr >= _post.ptr && r._post.ptr + r._post.length <= _post.ptr + _post.length;
    }

    static if(doUnittest) unittest
    {
        auto al = new Deque;
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
    Deque sort(scope bool delegate(ref V v1, ref V v2) comp)
    {
        std.algorithm.sort!(comp)(this[]);
        return this;
    }

    /**
     * Sort according to a given comparison function
     */
    Deque sort(bool function(ref V v1, ref V v2) comp)
    {
        std.algorithm.sort!(comp)(this[]);
        return this;
    }

    /**
     * Sort according to the default comparison routine for V
     */
    Deque sort()
    {
        std.algorithm.sort!(DefaultLess!(V))(this[]);
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
    Deque sortX(T)(T less)
    {
        std.algorithm.sort!less(this[]);
        return this;
    }

    static if(doUnittest) unittest
    {
        auto al = new Deque;
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
