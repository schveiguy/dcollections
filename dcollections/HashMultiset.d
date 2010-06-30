/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.HashMultiset;

public import dcollections.model.Multiset;
public import dcollections.DefaultFunctions;
private import dcollections.Hash;

version(unittest)
{
    import std.traits;
    import std.array;
    import std.range;
    static import std.algorithm;
    bool rangeEqual(V)(HashMultiset!V.range r, V[] arr)
    {
        uint[V] cnt;
        foreach(v; arr)
            cnt[v]++;
        uint len = 0;
        for(; !r.empty; ++len, r.popFront())
        {
            auto x = r.front in cnt;
            if(!x)
                return false;
            if(*x == 1)
                cnt.remove(r.front);
            else
                --(*x);
        }
        return cnt.length == 0;
    }
}

/**
 * A multi-set implementation which uses a Hash to have near O(1) insertion,
 * deletion and lookup time.
 *
 * Adding an element might invalidate cursors depending on the implementation.
 *
 * Removing an element only invalidates cursors that were pointing at that
 * element.
 *
 * (non-function members can be properties unless otherwise specified):
 *
 *
 * You can replace the Hash implementation with a custom implementation, the
 * Hash must be a struct template which can be instantiated with a single
 * template argument V, and must implement the following members (non-function
 * members can be get/set properties unless otherwise specified):
 *
 *
 * parameters -> must be a struct with at least the following members:
 *   hashFunction -> the hash function to use (should be a HashFunction!(V))
 * 
 * void setup(parameters p) -> initializes the hash with the given parameters.
 *
 * uint count -> count of the elements in the hash
 *
 * position -> must be a struct/class with the following member:
 *   ptr -> must define the following member:
 *     value -> the value which is pointed to by this position (cannot be a
 *                property)
 *   position next -> next position in the hash map
 *   position prev -> previous position in the hash map
 *
 * bool add(V v) -> add the given value to the hash.  The hash of the value
 * will be given by hashFunction(v).  If the value already exists in the hash,
 * this should call updateFunction(v) and should not increment count.
 *
 * position begin -> must be a position that points to the very first valid
 * element in the hash, or end if no elements exist.
 *
 * position end -> must be a position that points to just past the very last
 * valid element.
 *
 * position find(V v) -> returns a position that points to the element that
 * contains v, or end if the element doesn't exist.
 *
 * position remove(position p) -> removes the given element from the hash,
 * returns the next valid element or end if p was last in the hash.
 *
 * void clear() -> removes all elements from the hash, sets count to 0.
 *
 * uint removeAll(V v) -> remove all instances of the given value, returning
 * how many were removed.
 *
 * uint countAll(V v) -> returns the number of instances of the given value in
 * the hash.
 *
 * void copyTo(ref Hash h) -> make a duplicate copy of this hash into the
 * target h.
 */
class HashMultiset(V, alias ImplTemp=HashDup, alias hashFunction=DefaultHash) : Multiset!(V)
{
    version(unittest)
    {
        private enum doUnittest = isIntegral!V;

        bool arrayEqual(V[] arr)
        {
            if(length == arr.length)
            {
                uint[V] cnt;
                foreach(v; arr)
                    cnt[v]++;

                foreach(v; this)
                {
                    auto x = v in cnt;
                    if(!x || *x == 0)
                        return false;
                    --(*x);
                }
                return true;
            }
            return false;
        }
    }
    else
    {
        private enum doUnittest = false;
    }

    /**
     * an alias the the implementation template instantiation.
     */
    alias ImplTemp!(V, hashFunction) Impl;

    private Impl _hash;

    /**
     * A cursor for the hash multiset.
     */
    struct cursor
    {
        private Impl.position position;
        private bool _empty = false;

        /**
         * get the value at this position
         */
        @property V front()
        {
            assert(!_empty, "Attempting to read the value of an empty cursor of " ~ HashMultiset.stringof);
            return position.ptr.value;
        }

        /**
         * Tell if this cursor is empty (doesn't point to any value)
         */
        @property bool empty() const
        {
            return _empty;
        }

        /**
         * Move to the next element.
         */
        void popFront()
        {
            assert(!_empty, "Attempting to popFront() an empty cursor of " ~ HashMultiset.stringof);
            _empty = true;
            position = position.next;
        }

        /**
         * compare two cursors for equality.  Note that only the position of
         * the cursor is checked, whether it's empty or not is not checked.
         */
        bool opEquals(ref const cursor it) const
        {
            return it.position == position;
        }

        /*
         * TODO: this should compile!  For rvalues
         *
         * compare two cursors for equality.  Note that only the position of
         * the cursor is checked, whether it's empty or not is not checked.
         */
        /*bool opEquals(const cursor it) const
        {
            return it.position == position;
        }*/
    }

    static if(doUnittest) unittest
    {
        
        auto hms = new HashMultiset;
        hms.add([1, 2, 2, 3, 3, 4, 5]);
        auto cu = hms.elemAt(3);
        assert(!cu.empty);
        assert(cu.front == 3);
        cu.popFront();
        assert(cu.empty);
        assert(hms.arrayEqual([1, 2, 2, 3, 3, 4, 5]));
    }


    /**
     * A range that can be used to iterate over the elements in the hash.
     */
    struct range
    {
        private Impl.position _begin;
        private Impl.position _end;

        /**
         * is the range empty?
         */
        @property bool empty()
        {
            return _begin is _end;
        }

        /**
         * Get a cursor to the first element in the range
         */
        @property cursor begin()
        {
            cursor c;
            c.position = _begin;
            c._empty = empty;
            return c;
        }

        /**
         * Get a cursor to the end element in the range
         */
        @property cursor end()
        {
            cursor c;
            c.position = _end;
            c._empty = true;
            return c;
        }

        /**
         * Get the first value in the range
         */
        @property V front()
        {
            assert(!empty, "Attempting to read front of an empty range of " ~ HashMultiset.stringof);
            return _begin.ptr.value;
        }

        /**
         * Get the last value in the range
         */
        @property V back()
        {
            assert(!empty, "Attempting to read back of an empty range of " ~ HashMultiset.stringof);
            return _end.prev.ptr.value;
        }

        /**
         * Move the front of the range ahead one element
         */
        void popFront()
        {
            assert(!empty, "Attempting to popFront() an empty range of " ~ HashMultiset.stringof);
            _begin = _begin.next;
        }

        /**
         * Move the back of the range to the previous element
         */
        void popBack()
        {
            assert(!empty, "Attempting to popBack() an empty range of " ~ HashMultiset.stringof);
            _end = _end.prev;
        }
    }

    static if(doUnittest) unittest
    {
        auto hms = new HashMultiset;
        hms.add([1, 2, 2, 3, 3, 4, 5]);
        auto r = hms[];
        assert(rangeEqual(r, cast(V[])[1, 2, 2, 3, 3, 4, 5]));
        assert(r.front == hms.begin.front);
        assert(r.back != r.front);
        auto oldfront = r.front;
        auto oldback = r.back;
        r.popFront();
        r.popFront();
        r.popBack();
        r.popBack();
        assert(r.front != r.back);
        assert(r.front != oldfront);
        assert(r.back != oldback);

        auto b = r.begin;
        assert(!b.empty);
        assert(b.front == r.front);
        auto e = r.end;
        assert(e.empty);
    }


    /**
     * Determine if a cursor belongs to the hashmultiset
     */
    bool belongs(cursor c)
    {
        // rely on the implementation to tell us
        return _hash.belongs(c.position);
    }

    /**
     * Determine if a range belongs to the hashmultiset
     */
    bool belongs(range r)
    {
        return _hash.belongs(r._begin) && _hash.belongs(r._end);
    }

    static if(doUnittest) unittest
    {
        auto hms = new HashMultiset;
        hms.add([1, 2, 2, 3, 3, 4, 5]);
        auto cu = hms.elemAt(3);
        assert(cu.front == 3);
        assert(hms.belongs(cu));
        auto r = hms[hms.begin..cu];
        assert(hms.belongs(r));

        auto hs2 = hms.dup;
        assert(!hs2.belongs(cu));
        assert(!hs2.belongs(r));
    }


    /**
     * Iterate through all the elements of the multiset, indicating which
     * elements should be removed
     *
     *
     * Use like this:
     * ----------
     * // remove all odd elements
     * foreach(ref doPurge, v; &hashMultiset.purge)
     * {
     *   doPurge = ((v & 1) == 1);
     * }
     * ----------
     */
    int purge(scope int delegate(ref bool doPurge, ref V v) dg)
    {
        Impl.position it = _hash.begin;
        bool doPurge;
        int dgret = 0;
        Impl.position _end = _hash.end; // cache end so it isn't always being generated
        while(!dgret && it !is _end)
        {
            //
            // don't allow user to change value
            //
            V tmpvalue = it.ptr.value;
            doPurge = false;
            if((dgret = dg(doPurge, tmpvalue)) != 0)
                break;
            if(doPurge)
                it = _hash.remove(it);
            else
                it = it.next;
        }
        return dgret;
    }

    static if(doUnittest) unittest
    {
        auto hms = new HashMultiset;
        hms.add([0, 1, 2, 2, 3, 3, 4]);
        foreach(ref p, i; &hms.purge)
        {
            p = (i & 1);
        }

        assert(hms.arrayEqual([0, 2, 2, 4]));
    }

    /**
     * iterate over the collection's values
     */
    int opApply(scope int delegate(ref V v) dg)
    {
        int _dg(ref bool doPurge, ref V v)
        {
            return dg(v);
        }
        return purge(&_dg);
    }

    static if(doUnittest) unittest
    {
        auto hms = new HashMultiset;
        hms.add([1, 2, 3, 4, 5]);
        uint[V] cnt;
        uint len = 0;
        foreach(i; hms)
        {
            assert(hms.contains(i));
            ++cnt[i];
            ++len;
        }
        assert(len == hms.length);
        foreach(k, v; cnt)
        {
            assert(hms.count(k) == v);
        }
    }

    /**
     * Instantiate the hash map using the default implementation parameters.
     */
    this()
    {
        _hash.setup();
    }

    private this(ref Impl dupFrom)
    {
        _hash.setup();
        dupFrom.copyTo(_hash);
    }

    /**
     * Clear the collection of all elements
     */
    HashMultiset clear()
    {
        _hash.clear();
        return this;
    }


    static if(doUnittest) unittest
    {
        auto hms = new HashMultiset;
        hms.add([1, 2, 2, 3, 3, 4, 5]);
        assert(hms.length == 7);
        hms.clear();
        assert(hms.length == 0);
    }

    /**
     * returns number of elements in the collection
     */
    @property uint length() const
    {
        return _hash.count;
    }

    /**
     * returns a cursor to the first element in the collection.
     */
    @property cursor begin()
    {
        cursor it;
        it.position = _hash.begin;
        return it;
    }

    /**
     * returns a cursor that points just past the last element in the
     * collection.
     */
    cursor end()
    {
        cursor it;
        it.position = _hash.end;
        it._empty = true;
        return it;
    }

    /**
     * remove the element pointed at by the given cursor, returning an
     * cursor that points to the next element in the collection.
     *
     * Runs on average in O(1) time.
     */
    cursor remove(cursor it)
    {
        it.position = _hash.remove(it.position);
        if(it.position is _hash.end)
            it._empty = true;
        return it;
    }

    static if(doUnittest) unittest
    {
        auto hms = new HashMultiset;
        hms.add([1, 2, 2, 3, 3, 4, 5]);
        hms.remove(hms.elemAt(3));
        assert(hms.arrayEqual([1, 2, 2, 3, 4, 5]));
    }

    /**
     * remove all the elements in the given range.
     */
    cursor remove(range r)
    {
        auto b = r.begin;
        auto e = r.end;
        while(b != e)
        {
            b = remove(b);
        }
        return b;
    }

    static if(doUnittest) unittest
    {
        auto hms = new HashMultiset;
        hms.add([1, 2, 2, 3, 3, 4, 5]);
        auto r = hms[hms.elemAt(3)..hms.end];
        V[7] buf;
        auto remaining = std.algorithm.copy(hms[hms.begin..hms.elemAt(3)], buf[]);
        hms.remove(r);
        assert(hms.arrayEqual(buf[0..buf.length - remaining.length]));
        assert(!hms.contains(3));
    }

    /**
     * get a slice of all the elements in this hashmap.
     */
    range opSlice()
    {
        range result;
        result._begin = _hash.begin;
        result._end = _hash.end;
        return result;
    }

    /**
     * get a slice of the elements between the two cursors.  Runs on average
     * O(1) time.
     */
    range opSlice(cursor b, cursor e)
    {
        // for hash multiset, we only support ranges that begin on the first
        // cursor, or end on the last cursor.  This is because to check that b
        // is before e for arbitrary cursors would be possibly a long
        // operation.
        // TODO: fix this when compiler is sane!
        //if((b == begin && belongs(e)) || (e == end && belongs(b)))
        if((begin == b && belongs(e)) || (end == e && belongs(b)))
        {
            range result;
            result._begin = b.position;
            result._end = e.position;
            return result;
        }
        throw new Exception("invalid slice parameters to " ~ HashMultiset.stringof);
    }

    static if (doUnittest) unittest
    {
        auto hms = new HashMultiset;
        hms.add([1, 2, 2, 3, 3, 4, 5]);
        auto fr = hms[];
        auto prev = fr.front;
        while(fr.front == prev)
            fr.popFront();
        auto cu = fr.begin;
        auto r = hms[hms.begin..cu];
        auto r2 = hms[cu..hms.end];
        foreach(x; r2)
        {
            assert(std.algorithm.find(r, x).empty);
        }
        assert(walkLength(r) + walkLength(r2) == hms.length);

        bool exceptioncaught = false;
        try
        {
            hms[cu..cu];
        }
        catch(Exception)
        {
            exceptioncaught = true;
        }
        assert(exceptioncaught);
    }

    /**
     * find the first instance of a value in the collection.  Returns end if
     * the value is not present.
     *
     * Runs in average O(1) time.
     */
    cursor elemAt(V v)
    {
        cursor it;
        it.position = _hash.find(v);
        it._empty = it.position is _hash.end;
        return it;
    }

    static if(doUnittest) unittest
    {
        auto hms = new HashMultiset;
        hms.add([1, 2, 2, 3, 3, 4, 5]);
        assert(hms.elemAt(6).empty);
    }

    /**
     * Returns true if the given value exists in the collection.
     *
     * Runs in average O(1) time.
     */
    bool contains(V v)
    {
        return !elemAt(v).empty;
    }

    /**
     * find the next cursor that points to a V value.  Note, this does *not*
     * search the cursor passed in, to make it easy to search repetitively.
     *
     * Returns end if no more instances of v exist in the collection.
     */
    cursor elemAt(cursor start, V v)
    {
        if(start.position == _hash.end)
        {
            start._empty = true;
            return start;
        }
        start.position = _hash.find(v, start.position.next);
        start._empty = start.position is _hash.end;
        return start;
    }

    static if(doUnittest) unittest
    {
        auto hms = new HashMultiset;
        hms.add([1, 2, 2, 3, 3, 4, 5]);
        auto cu = hms.elemAt(3);
        auto cu2 = hms.elemAt(cu, 3);
        auto cu3 = hms.elemAt(cu2, 3);
        assert(!cu.empty && !cu2.empty && cu3.empty);
        assert(cu.front == 3 && cu2.front == 3);
        assert(cu != cu2);
    }

    /**
     * Removes the first element that has the value v.  Returns true if the
     * value was present and was removed.
     *
     * Runs in O(n) time.
     */
    HashMultiset remove(V v)
    {
        bool ignored;
        return remove(v, ignored);
    }

    /**
     * Removes the first element that has the value v.  Returns true if the
     * value was present and was removed.
     *
     * Runs in O(n) time.
     */
    HashMultiset remove(V v, out bool wasRemoved)
    {
        cursor it = elemAt(v);
        if((wasRemoved = !it.empty) is true)
        {
            remove(it);
        }
        return this;
    }

    static if(doUnittest) unittest
    {
        auto hms = new HashMultiset;
        hms.add([1, 2, 2, 3, 3, 4, 5]);
        bool wasRemoved;
        hms.remove(1, wasRemoved);
        assert(hms.arrayEqual([2, 2, 3, 3, 4, 5]));
        assert(wasRemoved);
        hms.remove(10, wasRemoved);
        assert(hms.arrayEqual([2, 2, 3, 3, 4, 5]));
        assert(!wasRemoved);
        hms.remove(3);
        assert(hms.arrayEqual([2, 2, 3, 4, 5]));
    }

    /**
     * Adds an element to the set.
     *
     * Runs on average in O(1) time.
     */
    HashMultiset add(V v)
    {
        _hash.add(v);
        return this;
    }

    /**
     * Adds an element to the set.  Sets wasAdded to true if the element was
     * not already present.
     *
     * Runs on average in O(1) time.
     */
    HashMultiset add(V v, out bool wasAdded)
    {
        wasAdded = _hash.add(v);
        return this;
    }

    /**
     * Adds all the elements from it to the set.
     *
     * Runs on average in O(1) * O(m) time, where m is the number of elements
     * in the iterator.
     */
    HashMultiset add(Iterator!(V) it)
    {
        if(it is this)
            throw new Exception("Attempting to self add " ~ HashMultiset.stringof);
        foreach(v; it)
            _hash.add(v);
        return this;
    }

    /**
     * Adds all the elements from it to the set.  Returns the number
     * of elements added.
     *
     * Runs on average in O(1) * O(m) time, where m is the number of elements
     * in the iterator.
     */
    HashMultiset add(Iterator!(V) it, out uint numAdded)
    {
        uint origlength = length;
        add(it);
        numAdded = length - origlength;
        return this;
    }

    /**
     * Adds all the elements from the array to the set.  Returns the number of
     * elements added.
     *
     * Runs on average in O(1) * O(m) time, where m is the array length.
     */
    HashMultiset add(V[] array)
    {
        uint ignored;
        return add(array, ignored);
    }

    /**
     * Adds all the elements from the array to the set.  Returns the number of
     * elements added.
     *
     * Runs on average in O(1) * O(m) time, where m is the array length.
     */
    HashMultiset add(V[] array, out uint numAdded)
    {
        uint origlength = length;
        foreach(v; array)
            _hash.add(v);
        numAdded = length - origlength;
        return this;
    }

    static if(doUnittest) unittest
    {
        // add single element
        bool wasAdded = false;
        auto hms = new HashMultiset;
        hms.add(1);
        hms.add(2, wasAdded);
        assert(hms.length == 2);
        assert(hms.arrayEqual([1, 2]));
        assert(wasAdded);

        // add a duplicate element
        wasAdded = false;
        hms.add(2, wasAdded);
        assert(wasAdded);
        assert(hms.arrayEqual([1, 2, 2]));

        // add other collection
        uint numAdded = 0;
        // need to add duplicate, adding self is not allowed.
        auto hs2 = hms.dup;
        hs2.add(3);
        hms.add(hs2, numAdded);
        hms.add(hms.dup);
        bool caughtexception = false;
        try
        {
            hms.add(hms);
        }
        catch(Exception)
        {
            caughtexception = true;
        }
        // should not be able to add self
        assert(caughtexception);

        assert(hms.arrayEqual([1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3]));
        assert(numAdded == 4);

        // add array
        hms.clear();
        hms.add([1, 2, 3, 4, 5]);
        hms.add([3, 4, 5, 6, 7], numAdded);
        assert(hms.arrayEqual([1, 2, 3, 3, 4, 4, 5, 5, 6, 7]));
        assert(numAdded == 5);
    }

    /**
     * Returns the number of elements in the collection that are equal to v.
     *
     * Runs on average in O(m * 1) time, where m is the number of elements
     * that are v.
     */
    uint count(V v)
    {
        return _hash.countAll(v);
    }

    /**
     * Removes all the elements that are equal to v.
     *
     * Runs on average in O(m * 1) time, where m is the number of elements
     * that are v.
     */
    HashMultiset removeAll(V v)
    {
        _hash.removeAll(v);
        return this;
    }

    /**
     * Removes all the elements that are equal to v.
     *
     * Runs on average in O(m * 1) time, where m is the number of elements
     * that are v.
     */
    HashMultiset removeAll(V v, out uint numRemoved)
    {
        numRemoved = _hash.removeAll(v);
        return this;
    }

    static if(doUnittest) unittest
    {
        auto hms = new HashMultiset;
        hms.add([1, 2, 2, 3, 3, 4, 5]);
        assert(hms.count(1) == 1);
        assert(hms.count(2) == 2);
        assert(hms.count(3) == 2);
        uint numRemoved = 0;
        hms.removeAll(2, numRemoved);
        assert(numRemoved == 2);
        assert(hms.arrayEqual([1, 3, 3, 4, 5]));
        hms.removeAll(10, numRemoved);
        assert(numRemoved == 0);
        assert(hms.arrayEqual([1, 3, 3, 4, 5]));
        hms.removeAll(3);
        assert(hms.arrayEqual([1, 4, 5]));
    }

    /**
     * make a shallow copy of this hash mulitiset.
     */
    HashMultiset dup()
    {
        return new HashMultiset(_hash);
    }

    /**
     * get the most convenient element in the set.  This is the element that
     * would be iterated first.
     */
    V get()
    {
        return begin.front;
    }

    static if(doUnittest) unittest
    {
        auto hms = new HashMultiset;
        hms.add([1, 2, 2, 3, 3, 4, 5]);
        assert(!std.algorithm.find([1, 2, 3, 4, 5], hms.get()).empty);
    }

    /**
     * Remove the most convenient element from the set, and return its value.
     * This is equivalent to remove(get()), except that only one lookup is
     * performed.
     */
    V take()
    {
        auto c = begin;
        auto retval = c.front;
        remove(c);
        return retval;
    }

    static if(doUnittest) unittest
    {
        auto hms = new HashMultiset;
        V[] aa = [1, 2, 2, 3, 3, 4, 5];
        hms.add(aa);
        auto x = hms.take();
        assert(!std.algorithm.find([1, 2, 3, 4, 5], x).empty);
        // remove x from the original array, and check for equality
        std.algorithm.partition!((V a) {return a == x;})(aa);
        assert(hms.arrayEqual(aa[1..$]));
    }
}

unittest
{
    // declare the Link list types that should be unit tested.
    HashMultiset!ubyte  hms1;
    HashMultiset!byte   hms2;
    HashMultiset!ushort hms3;
    HashMultiset!short  hms4;
    HashMultiset!uint   hms5;
    HashMultiset!int    hms6;
    HashMultiset!ulong  hms7;
    HashMultiset!long   hms8;

    // ensure that reference types can be used
    HashMultiset!(uint*) al9;
    class C {}
    HashMultiset!C al10;
}
