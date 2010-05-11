/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.HashSet;

public import dcollections.model.Set;
public import dcollections.DefaultFunctions;
private import dcollections.Hash;

/**
 * A set implementation which uses a Hash to have near O(1) insertion,
 * deletion and lookup time.
 *
 * Adding an element can invalidate cursors depending on the implementation.
 *
 * Removing an element only invalidates cursors that were pointing at that
 * element.
 *
 * You can replace the Hash implementation with a custom implementation, the
 * Hash must be a struct template which can be instantiated with a single
 * template argument V, and must implement the following members (non-function
 * members can be properties unless otherwise specified):
 *
 *
 * parameters -> must be a struct with at least the following members:
 *   hashFunction -> the hash function to use (should be a HashFunction!(V))
 *   updateFunction -> the update function to use (should be an
 *                     UpdateFunction!(V))
 * 
 * void setup(parameters p) -> initializes the hash with the given parameters.
 *
 * uint count -> count of the elements in the hash
 *
 * position -> must be a struct with the following member:
 *   ptr -> must define the following member:
 *     V value -> the value which is pointed to by this position (cannot be a
 *                property)
 *   position next -> must be the next value in the hash
 *   position prev -> must be the previous value in the hash
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
 */
class HashSet(V, alias ImplTemp=HashNoUpdate, alias hashFunction=DefaultHash) : Set!(V)
{
    /**
     * an alias the the implementation template instantiation.
     */
    alias ImplTemp!(V, hashFunction) Impl;

    private Impl _hash;

    /**
     * A cursor for the hash set.
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
            assert(!_empty, "Attempting to read the value of an empty cursor of " ~ HashSet.stringof);
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
            assert(!_empty, "Attempting to popFront() an empty cursor of " ~ HashSet.stringof);
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
         * TODO: uncomment this when compiler is sane!
         * 
         * compare two cursors for equality.  Note that only the position of
         * the cursor is checked, whether it's empty or not is not checked.
         */
        /*
        bool opEquals(const cursor it) const
        {
            return it.position == position;
        }*/
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
            assert(!empty, "Attempting to read front of an empty range of " ~ HashSet.stringof);
            return _begin.ptr.value;
        }

        /**
         * Get the last value in the range
         */
        @property V back()
        {
            assert(!empty, "Attempting to read back of an empty range of " ~ HashSet.stringof);
            return _end.prev.ptr.value;
        }

        /**
         * Move the front of the range ahead one element
         */
        void popFront()
        {
            assert(!empty, "Attempting to popFront() an empty range of " ~ HashSet.stringof);
            _begin = _begin.next;
        }

        /**
         * Move the back of the range to the previous element
         */
        void popBack()
        {
            assert(!empty, "Attempting to popBack() an empty range of " ~ HashSet.stringof);
            _end = _end.prev;
        }
    }

    /**
     * Determine if a cursor belongs to the hashset
     */
    bool belongs(cursor c)
    {
        // rely on the implementation to tell us
        return _hash.belongs(c.position);
    }

    /**
     * Determine if a range belongs to the hashset
     */
    bool belongs(range r)
    {
        return _hash.belongs(r._begin) && _hash.belongs(r._end);
    }

    /**
     * Iterate over the elements in the set, specifying which ones to remove.
     *
     * Use like this:
     *
     * ---------------
     * // remove all odd elements
     * foreach(ref doPurge, v; &hashSet.purge)
     * {
     *   doPurge = ((v & 1) == 1);
     * }
     */
    final int purge(scope int delegate(ref bool doPurge, ref V v) dg)
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

    /**
     * Instantiate the hash set using the implementation parameters given.
     */
    this()
    {
        _hash.setup();
    }

    //
    // private constructor for dup
    //
    private this(ref Impl dupFrom)
    {
        _hash.setup();
        dupFrom.copyTo(_hash);
    }

    /**
     * Clear the collection of all elements
     */
    HashSet clear()
    {
        _hash.clear();
        return this;
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
    @property cursor end()
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
        // for hash set, we only support ranges that begin on the first cursor,
        // or end on the last cursor.  This is because to check that b is
        // before e for arbitrary cursors would be possibly a long operation.
        // TODO: fix this when compiler is sane
        //if((b == begin && belongs(e)) || (e == end && belongs(b)))
        if((begin == b && belongs(e)) || (end == e && belongs(b)))
        {
            range result;
            result._begin = b.position;
            result._end = e.position;
            return result;
        }
        throw new Exception("invalid slice parameters to " ~ HashSet.stringof);
    }

    /**
     * find the instance of a value in the collection.  Returns end if the
     * value is not present.
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
     * Returns true if the given value exists in the collection.
     *
     * Runs in average O(1) time.
     */
    bool contains(V v)
    {
        return !elemAt(v).empty;
    }

    /**
     * Removes the first element that has the value v.  Returns true if the
     * value was present and was removed.
     *
     * Runs in O(n) time.
     */
    HashSet remove(V v)
    {
        cursor it = elemAt(v);
        if(!it.empty)
            remove(it);
        return this;
    }

    /**
     * Removes the first element that has the value v.  Returns true if the
     * value was present and was removed.
     *
     * Runs in O(n) time.
     */
    HashSet remove(V v, out bool wasRemoved)
    {
        cursor it = elemAt(v);
        if((wasRemoved = !it.empty) is true)
        {
            remove(it);
        }
        return this;
    }

    /**
     * Remove all values that match the given iterator.
     */
    HashSet remove(Iterator!(V) it)
    {
        foreach(v; it)
            remove(v);
        return this;
    }

    /**
     * Remove all the elements that appear in the iterator.  Sets numRemoved
     * to the number of elements removed.
     *
     * Returns this.
     */
    HashSet remove(Iterator!(V) it, out uint numRemoved)
    {
        uint origlength = length;
        remove(it);
        numRemoved = origlength - length;
        return this;
    }

    /**
     * Adds an element to the set.  Returns true if the element was not
     * already present.
     *
     * Runs on average in O(1) time.
     */
    HashSet add(V v)
    {
        _hash.add(v);
        return this;
    }

    /**
     * Adds an element to the set.  Returns true if the element was not
     * already present.
     *
     * Runs on average in O(1) time.
     */
    HashSet add(V v, out bool wasAdded)
    {
        wasAdded = _hash.add(v);
        return this;
    }

    /**
     * Adds all the elements from the iterator to the set.  Returns the number
     * of elements added.
     *
     * Runs on average in O(1) + O(m) time, where m is the number of elements
     * in the iterator.
     */
    HashSet add(Iterator!(V) it)
    {
        foreach(v; it)
            _hash.add(v);
        return this;
    }

    /**
     * Adds all the elements from the iterator to the set.  Returns the number
     * of elements added.
     *
     * Runs on average in O(1) + O(m) time, where m is the number of elements
     * in the iterator.
     */
    HashSet add(Iterator!(V) it, out uint numAdded)
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
     * Runs on average in O(1) + O(m) time, where m is the array length.
     */
    HashSet add(V[] array)
    {
        foreach(v; array)
            _hash.add(v);
        return this;
    }

    /**
     * Adds all the elements from the array to the set.  Returns the number of
     * elements added.
     *
     * Runs on average in O(m) time, where m is the array length.
     */
    HashSet add(V[] array, out uint numAdded)
    {
        uint origlength = length;
        add(array);
        numAdded = length - origlength;
        return this;
    }

    /**
     * Remove all the values from the set that are not in the given subset
     *
     * returns this.
     */
    HashSet intersect(Iterator!(V) subset)
    {
        //
        // intersection is more difficult than removal, because we do not have
        // insight into the implementation details.  Therefore, make the
        // implementation do it.
        //
        _hash.intersect(subset);
        return this;
    }

    /**
     * Remove all the values from the set that are not in the given subset.
     * Sets numRemoved to the number of elements removed.
     *
     * returns this.
     */
    HashSet intersect(Iterator!(V) subset, out uint numRemoved)
    {
        //
        // intersection is more difficult than removal, because we do not have
        // insight into the implementation details.  Therefore, make the
        // implementation do it.
        //
        numRemoved = _hash.intersect(subset);
        return this;
    }

    /**
     * duplicate this hash set
     */
    HashSet dup()
    {
        return new HashSet(_hash);
    }

    /**
     * compare two sets for equality
     */
    bool opEquals(Object o)
    {
        if(o !is null)
        {
            auto s = cast(Set!(V))o;
            if(s !is null && s.length == length)
            {
                foreach(elem; s)
                {
                    if(!contains(elem))
                        return false;
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

    /**
     * get the most convenient element in the set.  This is the element that
     * would be iterated first.  Therefore, calling remove(get()) is
     * guaranteed to be less than an O(n) operation.
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

unittest
{
    auto hs = new HashSet!(uint);
    Set!(uint) s = hs;
    s.add([0U, 1, 2, 3, 4, 5, 5]);
    assert(s.length == 6);
    foreach(ref doPurge, i; &s.purge)
        doPurge = (i % 2 == 1);
    assert(s.length == 3);
    assert(s.contains(4));
}
