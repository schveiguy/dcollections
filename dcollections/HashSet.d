/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.HashSet;

public import dcollections.model.Set;
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
class HashSet(V, alias ImplTemp = Hash) : Set!(V)
{
    /**
     * an alias the the implementation template instantiation.
     */
    alias ImplTemp!(V) Impl;

    /**
     * convenience alias
     */
    alias HashSet!(V, ImplTemp) HashSetType;

    private Impl _hash;
    private Purger _purger;

    private static uint hashFunction(ref V v)
    {
        return (typeid(V).getHash(&v) & 0x7FFF_FFFF);
    }

    private static void updateFunction(ref V orig, ref V newelem)
    {
        // don't copy anything, the values already match
    }

    /**
     * A cursor for the hash set.
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

    private class Purger : PurgeIterator!(V)
    {
        int opApply(int delegate(ref bool doPurge, ref V v) dg)
        {
            return _apply(dg);
        }
    }

    private int _apply(int delegate(ref bool doPurge, ref V v) dg)
    {
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
    final int opApply(int delegate(ref V v) dg)
    {
        int _dg(ref bool doPurge, ref V v)
        {
            return dg(v);
        }
        return _apply(&_dg);
    }

    /**
     * Instantiate the hash map using the implementation parameters given.
     */
    this(Impl.parameters p)
    {
        // insert defaults for the functions if necessary.
        if(!p.updateFunction)
            p.updateFunction = &updateFunction;
        if(!p.hashFunction)
            p.hashFunction = &hashFunction;
        _hash.setup(p);
        _purger = new Purger;
    }

    /**
     * Instantiate the hash map using the default implementation parameters.
     */
    this()
    {
        Impl.parameters p;
        this(p);
    }

    //
    // private constructor for dup
    //
    private this(ref Impl dupFrom)
    {
        dupFrom.copyTo(_hash);
        _purger = new Purger;
    }

    /**
     * Clear the collection of all elements
     */
    final HashSetType clear()
    {
        _hash.clear();
        return this;
    }

    /**
     * returns true
     */
    final bool supportsLength()
    {
        return true;
    }

    /**
     * returns number of elements in the collection
     */
    final uint length()
    {
        return _hash.count;
    }

    /**
     * returns a cursor to the first element in the collection.
     */
    final cursor begin()
    {
        cursor it;
        it.position = _hash.begin();
        return it;
    }

    /**
     * returns a cursor that points just past the last element in the
     * collection.
     */
    final cursor end()
    {
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
    final cursor remove(cursor it)
    {
        it.position = _hash.remove(it.position);
        return it;
    }

    /**
     * find the instance of a value in the collection.  Returns end if the
     * value is not present.
     *
     * Runs in average O(1) time.
     */
    final cursor find(V v)
    {
        cursor it;
        it.position = _hash.find(v);
        return it;
    }

    /**
     * Returns true if the given value exists in the collection.
     *
     * Runs in average O(1) time.
     */
    final bool contains(V v)
    {
        return find(v) != end;
    }

    /**
     * Removes the first element that has the value v.  Returns true if the
     * value was present and was removed.
     *
     * Runs in O(n) time.
     */
    final HashSetType remove(V v)
    {
        cursor it = find(v);
        if(it != end)
            remove(it);
        return this;
    }

    /**
     * Removes the first element that has the value v.  Returns true if the
     * value was present and was removed.
     *
     * Runs in O(n) time.
     */
    final HashSetType remove(V v, ref bool wasRemoved)
    {
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

    final HashSetType remove(Iterator!(V) it)
    {
        
        for(cursor cu = begin; cu != end; cu++)
    }

    /**
     * Remove all the elements that appear in the iterator.  Sets numRemoved
     * to the number of elements removed.
     *
     * Returns this.
     */
    final HashSetType remove(Iterator!(V) it, ref uint numRemoved)
    {
        uint origlength = length;
        remove(it);
        numRemoved = origlength - length;
        return this;
    }

    /**
     * returns an object that can be used to purge the collection.
     */
    final PurgeIterator!(V) purger()
    {
        return _purger;
    }

    /**
     * Adds an element to the set.  Returns true if the element was not
     * already present.
     *
     * Runs on average in O(1) time.
     */
    final HashSetType add(V v)
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
    final HashSetType add(V v, ref bool wasAdded)
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
    final HashSetType add(Iterator!(V) it, ref uint numAdded)
    {
        uint origlength = length;
        foreach(v; it)
            _hash.add(v);
        numAdded length - origlength;
        return this;
    }

    /**
     * Adds all the elements from the array to the set.  Returns the number of
     * elements added.
     *
     * Runs on average in O(1) + O(m) time, where m is the array length.
     */
    final HashSetType add(V[] array, ref uint numAdded)
    {
        uint origlength = length;
        foreach(v; array)
            _hash.add(v);
        numAdded = length - origlength;
        return this;
    }

    /**
     * duplicate this hash set
     */
    final HashSetType dup()
    {
        return new HashSetType(_hash);
    }
}
