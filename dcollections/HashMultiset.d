/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.HashMultiset;

public import dcollections.model.Multiset;
public import dcollections.DefaultFunctions;
private import dcollections.Hash;

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
            assert(!_empty, "Attempting to popFront() an empty cursor of " ~ HashMap.stringof);
            _empty = true;
            position = position.next;
        }

        /**
         * compare two cursors for equality.  Note that only the position of
         * the cursor is checked, whether it's empty or not is not checked.
         */
        bool opEquals(cursor it)
        {
            return it.position == position;
        }
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
            return _begin !is _end;
        }

        /**
         * Get a cursor to the first element in the range
         */
        @property cursor begin()
        {
            cursor c;
            c.position = _begin;
            return c;
        }

        /**
         * Get a cursor to the end element in the range
         */
        @property cursor end()
        {
            cursor c;
            c.position = _end;
            return c;
        }

        /**
         * Get the first value in the range
         */
        @property V front()
        {
            assert(!empty, "Attempting to read front of an range cursor of " ~ HashMultiset.stringof);
            return _begin.ptr.value.val;
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
     */
    int purge(scope int delegate(ref bool doPurge, ref V v) dg)
    {
        return _apply(dg);
    }

    private int _apply(scope int delegate(ref bool doPurge, ref V v) dg)
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
            V tmpvalue = it.value;
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

    /**
     * iterate over the collection's values
     */
    int opApply(scope int delegate(ref V v) dg)
    {
        int _dg(ref bool doPurge, ref V v)
        {
            return dg(v);
        }
        return _apply(&_dg);
    }

    /**
     * Instantiate the hash map using the default implementation parameters.
     */
    this()
    {
    }

    private this(ref Impl dupFrom)
    {
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

    /**
     * returns number of elements in the collection
     */
    @property uint length()
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
        if(it.position == _hash.end)
            it.empty = true;
        return it;
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

    /**
     * get a slice of all the elements in this hashmap.
     */
    range opSlice()
    {
        range result;
        range._begin = begin;
        range._end = end;
    }

    /**
     * get a slice of the elements between the two cursors.  Runs on average
     * O(1) time.
     */
    range opSlice(cursor b, cursor e)
    {
        // for hashmap, we only support ranges that begin on the first cursor,
        // or end on the last cursor.  This is because to check that b is
        // before e for arbitrary cursors would be possibly a long operation.
        if((b == begin && belongs(e)) || (e == end && belongs(b)))
        {
            range result;
            result._begin = b.position;
            result._end = e.position;
            return result;
        }
        throw new RangeError("invalid slice parameters to " ~ HashMultiset.stringof);
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
        if(it.position == _hash.end)
            it._empty = true;
        return it;
    }

    /**
     * find the next cursor that points to a V value.  Note, this does *not*
     * search the cursor passed in, to make it easy to search repetitively.
     *
     * Returns end if no more instances of v exist in the collection.
     */
    cursor elemAt(cursor start, V v)
    {
        if(it.position == _hash.end)
        {
            it._empty = true;
            return it;
        }
        it.position = _hash.find(v, it.position.next);
        if(it.position == _hash.end)
            it._empty = true;
        else
            it._empty = false;
        return it;
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
    HashMultiset remove(V v, ref bool wasRemoved)
    {
        cursor it = elemAt(v);
        if(it == end)
        {
            wasRemoved = false;
        }
        else
        {
            wasRemoved = true;
            remove(it);
        }
        return this;
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
    HashMultiset add(Iterator!(V) it, ref uint numAdded)
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
    HashMultiset add(V[] array, ref uint numAdded)
    {
        uint origlength = length;
        foreach(v; array)
            _hash.add(v);
        numAdded = length - origlength;
        return this;
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
}

version(UnitTest)
{
    unittest
    {
        auto hms = new HashMultiset!(uint);
        Multiset!(uint) ms = hms;
        hms.add([0U, 1, 2, 3, 4, 5, 5]);
        assert(hms.length == 7);
        assert(ms.count(5U) == 2);
        foreach(ref doPurge, i; &ms.purge)
        {
            doPurge = (i % 2 == 1);
        }
        assert(ms.count(5U) == 0);
        assert(ms.length == 3);
    }
}
