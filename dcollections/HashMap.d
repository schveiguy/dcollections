/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.HashMap;

public import dcollections.model.Map;
private import dcollections.Hash;

/**
 * A map implementation which uses a Hash to have near O(1) insertion,
 * deletion and lookup time.
 *
 * Adding an element might invalidate cursors depending on the implementation.
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
     * convenience alias
     */
    alias ImplTemp!(element) Impl;

    /**
     * convenience alias
     */
    alias HashMap!(K, V, ImplTemp) HashMapType;

    private Impl _hash;
    private Purger _purger;
    private KeyIterator _keys;

    private static uint hashFunction(ref element e)
    {
        return (typeid(K).getHash(&e.key) & 0x7FFF_FFFF);
    }

    private static void updateFunction(ref element orig, ref element newelem)
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
        final int opApply(int delegate(ref bool doPurge, ref V v) dg)
        {
            int _dg(ref bool doPurge, ref K k, ref V v)
            {
                return dg(doPurge, v);
            }
            return _apply(&_dg);
        }

        final int opApply(int delegate(ref bool doPurge, ref K k, ref V v) dg)
        {
            return _apply(dg);
        }
    }

    private class KeyIterator : Iterator!(K)
    {
        final bool supportsLength()
        {
            return true;
        }

        final uint length()
        {
            return this.outer.length;
        }

        final int opApply(int delegate(ref K) dg)
        {
            int _dg(ref bool doPurge, ref K k, ref V v)
            {
                return dg(k);
            }
            return _apply(&_dg);
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
                it = remove(it);
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
        _keys = new KeyIterator;
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
        _keys = new KeyIterator;
    }

    /**
     * Clear the collection of all elements
     */
    HashMapType clear()
    {
        _hash.clear();
        return this;
    }

    /**
     * returns true
     */
    bool supportsLength()
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
    cursor begin()
    {
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
        it.position = _hash.remove(it.position);
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
    HashMapType remove(V v)
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
    HashMapType remove(V v, ref bool wasRemoved)
    {
        cursor it = findValue(v);
        if(it == end)
        {
            wasRemoved = false;
        }
        else
        {
            remove(it);
            wasRemoved = true;
        }
        return this;
    }

    /**
     * Removes the element that has the given key.  Returns true if the
     * element was present and was removed.
     *
     * Runs on average in O(1) time.
     */
    HashMapType removeAt(K key)
    {
        bool ignored;
        return removeAt(key, ignored);
    }

    /**
     * Removes the element that has the given key.  Returns true if the
     * element was present and was removed.
     *
     * Runs on average in O(1) time.
     */
    HashMapType removeAt(K key, ref bool wasRemoved)
    {
        cursor it = find(key);
        if(it == end)
        {
            wasRemoved = false;
        }
        else
        {
            remove(it);
            wasRemoved = true;
        }
        return this;
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
        set(key, value);
        return value;
    }

    /**
     * Set a key/value pair.  If the key/value pair doesn't already exist, it
     * is added.
     */
    HashMapType set(K key, V value)
    {
        bool ignored;
        return set(key, value, ignored);
    }

    /**
     * Set a key/value pair.  If the key/value pair doesn't already exist, it
     * is added, and the wasAdded parameter is set to true.
     */
    HashMapType set(K key, V value, ref bool wasAdded)
    {
        element elem;
        elem.key = key;
        elem.val = value;
        wasAdded = _hash.add(elem);
        return this;
    }

    /**
     * Set all the values from the iterator in the map.  If any elements did
     * not previously exist, they are added.
     */
    HashMapType set(KeyedIterator!(K, V) source)
    {
        uint ignored;
        return set(source, ignored);
    }

    /**
     * Set all the values from the iterator in the map.  If any elements did
     * not previously exist, they are added.  numAdded is set to the number of
     * elements that were added in this operation.
     */
    HashMapType set(KeyedIterator!(K, V) source, ref uint numAdded)
    {
        uint origlength = length;
        bool ignored;
        foreach(k, v; source)
        {
            set(k, v, ignored);
        }
        numAdded = length - origlength;
        return this;
    }

    /**
     * Remove all keys from the map which are in subset.
     */
    HashMapType remove(Iterator!(K) subset)
    {
        uint ignored;
        return remove(subset, ignored);
    }

    /**
     * Remove all keys from the map which are in subset.  numRemoved is set to
     * the number of keys that were actually removed.
     */
    HashMapType remove(Iterator!(K) subset, ref uint numRemoved)
    {
        uint origlength = length;
        foreach(k; subset)
            removeAt(k);
        numRemoved = origlength - length;
        return this;
    }

    HashMapType intersect(Iterator!(K) subset)
    {
        uint ignored;
        return intersect(subset, ignored);
    }

    /**
     * This function only keeps elements that are found in subset.
     */
    HashMapType intersect(Iterator!(K) subset, ref uint numRemoved)
    {
        //
        // this one is a bit trickier than removing.  We want to find each
        // Hash element, then move it to a new table.  However, we do not own
        // the implementation and cannot make assumptions about the
        // implementation.  So we defer the intersection to the hash
        // implementation.
        //
        // If we didn't care about runtime, this could be done with:
        //
        // remove((new HashSet!(K)).add(this.keys).remove(subset));
        //

        //
        // need to create a wrapper iterator to pass to the implementation,
        // one that wraps each key in the subset as an element
        //
        static class wrapper : Iterator!(element)
        {
            Iterator!(K) wrapped;
            this(Iterator!(K) wrapped)
            {
              this.wrapped = wrapped;
            }
            bool supportsLength() { return wrapped.supportsLength;}
            uint length() { return wrapped.length;}
            int opApply(int delegate(ref element e) dg)
            {
                //
                // need to wrap each key in the wrapped iterator into an
                // element.
                //
                int retval = 0;
                foreach(k; wrapped)
                {
                    element elem;
                    elem.key = k;
                    if((retval = dg(elem)) != 0)
                        break;
                }
                return retval;
            }
        }
        scope w = new wrapper(subset); // should allocate on the stack
        numRemoved = _hash.intersect(w);
        return this;
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
    HashMapType removeAll(V v)
    {
        uint ignored;
        return removeAll(v, ignored);
    }
    /**
     * Remove all the elements that contain the value v.
     *
     * Runs in O(n) time.
     */
    HashMapType removeAll(V v, ref uint numRemoved)
    {
        uint origlength = length;
        foreach(ref b, x; purger)
        {
            b = (x == v);
        }
        numRemoved = origlength - length;
        return this;
    }

    /**
     * returns an object that can be used to purge the collection using
     * key/value pairs.
     */
    PurgeKeyedIterator!(K, V) purger()
    {
        return _purger;
    }

    /**
     * return an iterator that can be used to read all the keys
     */
    Iterator!(K) keys()
    {
        return _keys;
    }

    /**
     * Make a shallow copy of the hash map.
     */
    HashMapType dup()
    {
        return new HashMapType(_hash);
    }

    /**
     * Compare this HashMap with another Map
     *
     * Returns 0 if o is not a Map object, or the HashMap does not contain the
     * same key/value pairs as the given map.
     * Returns 1 if exactly the key/value pairs contained in the given map are
     * in this HashMap.
     */
    int opEquals(Object o)
    {
        if(o is this)
            return 1;

        //
        // try casting to map, otherwise, don't compare
        //
        auto m = cast(Map!(K, V))o;
        if(m !is null)
        {
            if(m.length != length)
                return 0;
            auto _end = end;
            foreach(K k, V v; m)
            {
                auto cu = find(k);
                if(cu is _end || cu.value != v)
                    return 0;
            }
            return 1;
        }

        return 0;
    }
}

version(UnitTest)
{
    unittest
    {
        HashMap!(uint, uint) hm = new HashMap!(uint, uint);
        Map!(uint, uint) m = hm;
        for(int i = 0; i < 10; i++)
            hm[i * i + 1] = i;
        assert(hm.length == 10);
        foreach(ref doPurge, k, v; hm.purger)
        {
            doPurge = (v % 2 == 1);
        }
        assert(hm.length == 5);
        assert(hm.contains(6));
        assert(hm.containsKey(6 * 6 + 1));
    }
}
