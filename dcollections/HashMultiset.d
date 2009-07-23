/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.HashMultiset;

public import dcollections.model.Multiset;
public import dcollections.DefaultFunctions;
private import dcollections.Hash;

    import tango.io.Stdout;
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

        /**
         * get the value at this position
         */
        V value()
        {
            return position.ptr.value;
        }

        /**
         * increment this cursor, returns what the cursor was before
         * incrementing.
         */
        cursor opPostInc()
        {
            cursor tmp = *this;
            position = position.next;
            return tmp;
        }

        /**
         * decrement this cursor, returns what the cursor was before
         * decrementing.
         */
        cursor opPostDec()
        {
            cursor tmp = *this;
            position = position.prev;
            return tmp;
        }

        /**
         * increment the cursor by the given amount.
         *
         * This is an O(inc) operation!  You should only use this operator in
         * the form:
         *
         * ++i;
         */
        cursor opAddAssign(int inc)
        {
            if(inc < 0)
                return opSubAssign(-inc);
            while(inc--)
                position = position.next;
            return *this;
        }

        /**
         * decrement the cursor by the given amount.
         *
         * This is an O(inc) operation!  You should only use this operator in
         * the form:
         *
         * --i;
         */
        cursor opSubAssign(int inc)
        {
            if(inc < 0)
                return opAddAssign(-inc);
            while(inc--)
                position = position.prev;
            return *this;
        }

        /**
         * compare two cursors for equality
         */
        bool opEquals(cursor it)
        {
            return it.position == position;
        }
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
    int purge(int delegate(ref bool doPurge, ref V v) dg)
    {
        Stdout("here", __LINE__).newline();
        return _apply(dg);
    }

    private int _apply(int delegate(ref bool doPurge, ref V v) dg)
    {
        Stdout("here", __LINE__).newline();
        cursor it = begin;
        bool doPurge;
        int dgret = 0;
        cursor _end = end; // cache end so it isn't always being generated
        while(!dgret && it != _end)
        {
            //
            // don't allow user to change value
            //
            V tmpvalue = it.value;
            doPurge = false;
            if((dgret = dg(doPurge, tmpvalue)) != 0)
                break;
            if(doPurge)
                remove(it++);
            else
                it++;
        }
        return dgret;
    }

    /**
     * iterate over the collection's values
     */
    int opApply(int delegate(ref V v) dg)
    {
        Stdout("here", __LINE__).newline();
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
        Stdout("here", __LINE__).newline();
        _hash.setup();
    }

    private this(ref Impl dupFrom)
    {
        Stdout("here", __LINE__).newline();
        dupFrom.copyTo(_hash);
    }

    /**
     * Clear the collection of all elements
     */
    HashMultiset clear()
    {
        Stdout("here", __LINE__).newline();
        _hash.clear();
        return this;
    }

    /**
     * returns number of elements in the collection
     */
    uint length()
    {
        Stdout("here", __LINE__).newline();
        return _hash.count;
    }

    /**
     * returns a cursor to the first element in the collection.
     */
    cursor begin()
    {
        Stdout("here", __LINE__).newline();
        cursor it;
        it.position = _hash.begin();
        return it;
    }

    /**
     * returns a cursor that points just past the last element in the
     * collection.
     */
    cursor end()
    {
        Stdout("here", __LINE__).newline();
        cursor it;
        it.position = _hash.end();
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
        Stdout("here", __LINE__).newline();
        it.position = _hash.remove(it.position);
        return it;
    }

    /**
     * find the first instance of a value in the collection.  Returns end if
     * the value is not present.
     *
     * Runs in average O(1) time.
     */
    cursor find(V v)
    {
        Stdout("here", __LINE__).newline();
        cursor it;
        it.position = _hash.find(v);
        return it;
    }

    /**
     * find the next cursor that points to a V value.
     *
     * Returns end if no more instances of v exist in the collection.
     */
    cursor find(cursor it, V v)
    {
        Stdout("here", __LINE__).newline();
        it.position = _hash.find(v, it.position);
        return it;
    }

    /**
     * Returns true if the given value exists in the collection.
     *
     * Runs in average O(1) time.
     */
    bool contains(V v)
    {
        Stdout("here", __LINE__).newline();
        return find(v) != end;
    }

    /**
     * Removes the first element that has the value v.  Returns true if the
     * value was present and was removed.
     *
     * Runs in O(n) time.
     */
    HashMultiset remove(V v)
    {
        Stdout("here", __LINE__).newline();
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
        Stdout("here", __LINE__).newline();
        cursor it = find(v);
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
     * Adds an element to the set.  Returns true if the element was not
     * already present.
     *
     * Runs on average in O(1) time.
     */
    HashMultiset add(V v)
    {
        Stdout("here", __LINE__).newline();
        _hash.add(v);
        return this;
    }

    /**
     * Adds an element to the set.  Returns true if the element was not
     * already present.
     *
     * Runs on average in O(1) time.
     */
    HashMultiset add(V v, ref bool wasAdded)
    {
        Stdout("here", __LINE__).newline();
        wasAdded = _hash.add(v);
        return this;
    }

    /**
     * Adds all the elements from it to the set.  Returns the number
     * of elements added.
     *
     * Runs on average in O(1) + O(m) time, where m is the number of elements
     * in the iterator.
     */
    HashMultiset add(Iterator!(V) it)
    {
        Stdout("here", __LINE__).newline();
        foreach(v; it)
            _hash.add(v);
        return this;
    }

    /**
     * Adds all the elements from it to the set.  Returns the number
     * of elements added.
     *
     * Runs on average in O(1) + O(m) time, where m is the number of elements
     * in the iterator.
     */
    HashMultiset add(Iterator!(V) it, ref uint numAdded)
    {
        Stdout("here", __LINE__).newline();
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
        Stdout("here", __LINE__).newline();
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
        Stdout("here", __LINE__).newline();
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
        Stdout("here", __LINE__).newline();
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
        Stdout("here", __LINE__).newline();
        _hash.removeAll(v);
        return this;
    }

    /**
     * Removes all the elements that are equal to v.
     *
     * Runs on average in O(m * 1) time, where m is the number of elements
     * that are v.
     */
    HashMultiset removeAll(V v, ref uint numRemoved)
    {
        Stdout("here", __LINE__).newline();
        numRemoved = _hash.removeAll(v);
        return this;
    }

    /**
     * make a shallow copy of this hash mulitiset.
     */
    HashMultiset dup()
    {
        Stdout("here", __LINE__).newline();
        return new HashMultiset(_hash);
    }

    /**
     * get the most convenient element in the set.  This is the element that
     * would be iterated first.  Therefore, calling remove(get()) is
     * guaranteed to be less than an O(n) operation.
     */
    V get()
    {
        Stdout("here", __LINE__).newline();
        return begin.value;
    }

    /**
     * Remove the most convenient element from the set, and return its value.
     * This is equivalent to remove(get()), except that only one lookup is
     * performed.
     */
    V take()
    {
        Stdout("here", __LINE__).newline();
        auto c = begin;
        auto retval = c.value;
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
        Stdout("about to do foreach").newline;
        foreach(ref doPurge, i; &ms.purge)
        {
            doPurge = (i % 2 == 1);
            Stdout.formatln("element is {}, doPurge is {}", i, doPurge);
        }
        Stdout("done foreach").newline;
        Stdout.formatln("ms.count(5U) is {}", ms.count(5U));
        assert(ms.count(5U) == 0);
        assert(ms.length == 3);
    }
}
