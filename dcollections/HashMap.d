/*********************************************************
   Copyright (C) 2008 by Steven Schveighoffer.
              All rights reserved

   Permission is hereby granted, free of charge, to any person obtaining a
   copy of this software and associated documentation files (the "Software"),
   to deal in the Software without restriction, including without limitation
   the rights to use, copy, modify, merge, publish, distribute, sublicense,
   and/or sell copies of the Software, and to permit persons to whom the
   Software is furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
   DEALINGS IN THE SOFTWARE.

**********************************************************/
module dcollections.HashMap;

public import dcollections.model.Map;
private import dcollections.Hash;

/**
 * A map implementation which uses a Hash to have near O(1) insertion,
 * deletion and lookup time.
 *
 * Adding an element does not invalidate any cursors.
 *
 * Removing an element only invalidates cursors that were pointing at that
 * element.
 *
 * You can replace the Hash implementation with a custom implementation, the
 * Hash must be a struct template which can be instantiated with a single
 * template argument V, and must implement the following members (non-function
 * members can be get/set properties unless otherwise specified):
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
 */
class HashMap(K, V, alias ImplTemp = Hash) : Map!(K, V)
{
    /**
     * used to implement the key/value pair stored in the hash implementation
     */
    struct element
    {
        K key;
        V val;

        /**
         * compare 2 elements for equality.  Only compares the keys.
         */
        int opEquals(element e)
        {
            return key == e.key;
        }
    }

    /**
     * an alias the the implementation template instantiation.
     */
    alias ImplTemp!(element) Impl;

    private Impl _hash;
    private Purger _purger;

    private static final uint hashFunction(ref element e)
    {
        return (typeid(K).getHash(&e.key) & 0x7FFF_FFFF);
    }

    private static final void updateFunction(ref element orig, ref element newelem)
    {
        //
        // only copy the value, leave the key alone
        //
        orig.val = newelem.val;
    }

    /**
     * A cursor for the hash map.
     */
    struct cursor
    {
        private Impl.position position;

        /**
         * get the value at this cursor
         */
        V value()
        {
            return position.ptr.value.val;
        }

        /**
         * get the key at this cursor
         */
        K key()
        {
            return position.ptr.value.key;
        }

        /**
         * set the value at this cursor
         */
        V value(V v)
        {
            position.ptr.value.val = v;
            return v;
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
            return it.position is position;
        }
    }

    private class Purger : PurgeKeyedIterator!(K, V)
    {
        int opApply(int delegate(ref bool doPurge, ref V v) dg)
        {
            int _dg(ref bool doPurge, ref K k, ref V v)
            {
                return dg(doPurge, v);
            }
            return _apply(&_dg);
        }

        int opApply(int delegate(ref bool doPurge, ref K k, ref V v) dg)
        {
            return _apply(dg);
        }
    }

    private int _apply(int delegate(ref bool doPurge, ref K k, ref V v) dg)
    {
        cursor it = begin;
        bool doPurge;
        int dgret = 0;
        cursor _end = end; // cache end so it isn't always being generated
        while(!dgret && it != _end)
        {
            //
            // don't allow user to change key
            //
            K tmpkey = it.key;
            doPurge = false;
            if((dgret = dg(doPurge, tmpkey, it.position.ptr.value.val)) != 0)
                break;
            if(doPurge)
                remove(it++);
            else
                it++;
        }
        return dgret;
    }

    /**
     * iterate over the collection's key/value pairs
     */
    int opApply(int delegate(ref K k, ref V v) dg)
    {
        int _dg(ref bool doPurge, ref K k, ref V v)
        {
            return dg(k, v);
        }

        return _apply(&_dg);
    }

    /**
     * iterate over the collection's values
     */
    int opApply(int delegate(ref V v) dg)
    {
        int _dg(ref bool doPurge, ref K k, ref V v)
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

    /**
     * Clear the collection of all elements
     */
    Collection!(V) clear()
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
    uint length()
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
    cursor remove(cursor it)
    {
        _hash.remove((it++).position);
        return it;
    }

    /**
     * find a given value in the collection starting at a given cursor.
     * This is useful to iterate over all elements that have the same value.
     *
     * Runs in O(n) time.
     */
    cursor findValue(cursor it, V v)
    {
        return _findValue(it, end, v);
    }

    /**
     * find an instance of a value in the collection.  Equivalent to
     * findValue(begin, v);
     *
     * Runs in O(n) time.
     */
    cursor findValue(V v)
    {
        return _findValue(begin, end, v);
    }

    private cursor _findValue(cursor it, cursor last, V v)
    {
        while(it != last && it.value != v)
            it++;
        return it;
    }

    /**
     * find the instance of a key in the collection.  Returns end if the key
     * is not present.
     *
     * Runs in average O(1) time.
     */
    cursor find(K k)
    {
        cursor it;
        element tmp;
        tmp.key = k;
        it.position = _hash.find(tmp);
        return it;
    }

    /**
     * Returns true if the given value exists in the collection.
     *
     * Runs in O(n) time.
     */
    bool contains(V v)
    {
        return findValue(v) != end;
    }

    /**
     * Removes the first element that has the value v.  Returns true if the
     * value was present and was removed.
     *
     * Runs in O(n) time.
     */
    bool remove(V v)
    {
        cursor it = findValue(v);
        if(it == end)
            return false;
        remove(it);
        return true;
    }

    /**
     * Removes the element that has the given key.  Returns true if the
     * element was present and was removed.
     *
     * Runs on average in O(1) time.
     */
    bool removeAt(K key)
    {
        cursor it = find(key);
        if(it == end)
            return false;
        remove(it);
        return true;
    }

    /**
     * Returns the value that is stored at the element which has the given
     * key.  Throws an exception if the key is not in the collection.
     *
     * Runs on average in O(1) time.
     */
    V opIndex(K key)
    {
        cursor it = find(key);
        if(it == end)
            throw new Exception("Index out of range");
        return it.value;
    }

    /**
     * assign the given value to the element with the given key.  If the key
     * does not exist, adds the key and value to the collection.
     *
     * Runs on average in O(1) time.
     */
    V opIndexAssign(V value, K key)
    {
        element elem;
        elem.key = key;
        elem.val = value;
        _hash.add(elem);
        return value;
    }

    /**
     * Returns true if the given key is in the collection.
     *
     * Runs on average in O(1) time.
     */
    bool containsKey(K key)
    {
        return find(key) != end;
    }

    /**
     * Returns the number of elements that contain the value v
     *
     * Runs in O(n) time.
     */
    uint count(V v)
    {
        uint instances = 0;
        foreach(x; this)
        {
            if(x == v)
                instances++;
        }
        return instances;
    }

    /**
     * Remove all the elements that contain the value v.
     *
     * Runs in O(n) time.
     */
    uint removeAll(V v)
    {
        uint origlength = length;
        foreach(ref b, x; purger)
        {
            if(x == v)
                b = true;
        }
        return origlength - length;
    }

    /**
     * returns an object that can be used to purge the collection.
     */
    PurgeIterator!(V) purger()
    {
        return _purger;
    }

    /**
     * returns an object that can be used to purge the collection using
     * key/value pairs.
     */
    PurgeKeyedIterator!(K, V) keyPurger()
    {
        return _purger;
    }
}
