/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.HashMap;

public import dcollections.model.Map;
public import dcollections.DefaultFunctions;
private import dcollections.Hash;

private import dcollections.Iterators;

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
class HashMap(K, V, alias ImplTemp=Hash, alias hashFunction=DefaultHash) : Map!(K, V)
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
        bool opEquals(ref const(element) e) const
        {
            return key == e.key;
        }
    }

    private KeyIterator _keys;

    /**
     * Function to get the hash of an element
     */
    static uint _hashFunction(ref element e)
    {
        return hashFunction(e.key);
    }

    /**
     * Function to update an element according to the new element.
     */
    static void _updateFunction(ref element orig, ref element newelem)
    {
        //
        // only copy the value, leave the key alone
        //
        orig.val = newelem.val;
    }

    /**
     * convenience alias
     */
    alias ImplTemp!(element, _hashFunction, _updateFunction) Impl;

    private Impl _hash;

    /**
     * A cursor for the hash map.
     */
    struct cursor
    {
        private Impl.position position;
        private bool _empty = false;

        /**
         * get the value at this cursor
         */
        @property V front()
        {
            assert(!_empty, "Attempting to read the value of an empty cursor of " ~ HashMap.stringof);
            return position.ptr.value.val;
        }

        /**
         * get the key at this cursor
         */
        @property K key()
        {
            assert(!_empty, "Attempting to read the key of an empty cursor of " ~ HashMap.stringof);
            return position.ptr.value.key;
        }

        /**
         * set the value at this cursor
         */
        @property V front(V v)
        {
            assert(!_empty, "Attempting to write the value of an empty cursor of " ~ HashMap.stringof);
            position.ptr.value.val = v;
            return v;
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
        bool opEquals(ref const(cursor) it) const
        {
            return it.position is position;
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
            assert(!empty, "Attempting to read front of an empty range of " ~ HashMap.stringof);
            return _begin.ptr.value.val;
        }

        /**
         * Write the first value in the range.
         */
        @property V front(V v)
        {
            assert(!empty, "Attempting to write front of an empty range of " ~ HashMap.stringof);
            _begin.ptr.value.val = v;
            return v;
        }

        /**
         * Get the key of the front element
         */
        @property K key()
        {
            assert(!empty, "Attempting to read the key of an empty range of " ~ HashMap.stringof);
            return _begin.ptr.value.key;
        }

        /**
         * Get the last value in the range
         */
        @property V back()
        {
            assert(!empty, "Attempting to read back of an empty range of " ~ HashMap.stringof);
            return _end.prev.ptr.value.val;
        }

        /**
         * Write the last value in the range.
         */
        @property V back(V v)
        {
            assert(!empty, "Attempting to write back of an empty range of " ~ HashMap.stringof);
            _end.prev.ptr.value.val = v;
            return v;
        }

        /**
         * Get the key of the last element
         */
        @property K backKey()
        {
            assert(!empty, "Attempting to read the back key of an empty range of " ~ HashMap.stringof);
            return _end.prev.ptr.value.key;
        }

        /**
         * Move the front of the range ahead one element
         */
        void popFront()
        {
            assert(!empty, "Attempting to popFront() an empty range of " ~ HashMap.stringof);
            _begin = _begin.next;
        }

        /**
         * Move the back of the range to the previous element
         */
        void popBack()
        {
            assert(!empty, "Attempting to popBack() an empty range of " ~ HashMap.stringof);
            _end = _end.prev;
        }
    }

    /**
     * Determine if a cursor belongs to the hashmap
     */
    bool belongs(cursor c)
    {
        // rely on the implementation to tell us
        return _hash.belongs(c.position);
    }

    /**
     * Determine if a range belongs to the hashmap
     */
    bool belongs(range r)
    {
        return _hash.belongs(r._begin) && _hash.belongs(r._end);
    }

    /**
     * Iterate over the values of the HashMap, telling it which ones to
     * remove.
     */
    final int purge(scope int delegate(ref bool doPurge, ref V v) dg)
    {
        int _dg(ref bool doPurge, ref K k, ref V v)
        {
            return dg(doPurge, v);
        }
        return _apply(&_dg);
    }

    /**
     * Iterate over the key/value pairs of the HashMap, telling it which ones
     * to remove.
     */
    final int keypurge(scope int delegate(ref bool doPurge, ref K k, ref V v) dg)
    {
        return _apply(dg);
    }

    private class KeyIterator : Iterator!(K)
    {
        @property final uint length() const
        {
            return this.outer.length;
        }

        final int opApply(scope int delegate(ref K) dg)
        {
            int _dg(ref bool doPurge, ref K k, ref V v)
            {
                return dg(k);
            }
            return _apply(&_dg);
        }
    }

    private int _apply(scope int delegate(ref bool doPurge, ref K k, ref V v) dg)
    {
        Impl.position it = _hash.begin;
        bool doPurge;
        int dgret = 0;
        Impl.position _end = _hash.end; // cache end so it isn't always being generated
        while(!dgret && it !is _end)
        {
            //
            // don't allow user to change key
            //
            K tmpkey = it.ptr.value.key;
            doPurge = false;
            if((dgret = dg(doPurge, tmpkey, it.ptr.value.val)) != 0)
                break;
            if(doPurge)
                it = _hash.remove(it);
            else
                it = it.next;
        }
        return dgret;
    }

    /**
     * iterate over the collection's key/value pairs
     */
    int opApply(scope int delegate(ref K k, ref V v) dg)
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
    int opApply(scope int delegate(ref V v) dg)
    {
        int _dg(ref bool doPurge, ref K k, ref V v)
        {
            return dg(v);
        }
        return _apply(&_dg);
    }

    /**
     * Instantiate the hash map
     */
    this()
    {
        // create the key iterator
        _keys = new KeyIterator;
    }

    //
    // private constructor for dup
    //
    private this(ref Impl dupFrom)
    {
        dupFrom.copyTo(_hash);
        _keys = new KeyIterator;
    }

    /**
     * Clear the collection of all elements
     */
    HashMap clear()
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
     * if the cursor is empty, it does not remove any elements, but returns a
     * cursor that points to the next element.
     *
     * Runs on average in O(1) time.
     */
    cursor remove(cursor it)
    {
        assert(belongs(it), "Error, attempting to remove invalid cursor from " ~ HashMap.stringof);
        if(!it.empty)
        {
            it.position = _hash.remove(it.position);
        }
        it._empty = (it.position == _hash.end);
        return it;
    }

    /**
     * remove all the elements in the given range.
     */
    cursor remove(range r)
    {
        assert(belongs(r), "Error, attempting to remove invalid cursor from " ~ HashMap.stringof);
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
     * get a slice of the elements between the two cursors.
     *
     * This function only works if either b is the first element in the hashmap
     * or e is the end element.  The rationale is that we want to ensure that
     * opSlice returns quickly, and not knowing the implementation, we cannot
     * know if determining the order of two cursors is an O(n) operation.
     */
    range opSlice(cursor b, cursor e)
    {
        // for hashmap, we only support ranges that begin on the first cursor,
        // or end on the last cursor.
        if((begin == b && belongs(e)) || (end == e && belongs(b)))
        {
            range result;
            result._begin = b.position;
            result._end = e.position;
            return result;
        }
        throw new RangeError("invalid slice parameters to " ~ HashMap.stringof);
    }

    /**
     * find the instance of a key in the collection.  Returns end if the key
     * is not present.
     *
     * Runs in average O(1) time.
     */
    cursor elemAt(K k)
    {
        cursor it;
        element tmp;
        tmp.key = k;
        it.position = _hash.find(tmp);
        if(it.position == _hash.end)
            it._empty = true;
        return it;
    }

    /**
     * Removes the element that has the given key.  Returns true if the
     * element was present and was removed.
     *
     * Runs on average in O(1) time.
     */
    HashMap remove(K key)
    {
        bool ignored;
        return remove(key, ignored);
    }

    /**
     * Removes the element that has the given key.  Returns true if the
     * element was present and was removed.
     *
     * Runs on average in O(1) time.
     */
    HashMap remove(K key, out bool wasRemoved)
    {
        cursor it = elemAt(key);
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
        cursor it = elemAt(key);
        if(it == end)
            throw new RangeError("Index out of range");
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
    HashMap set(K key, V value)
    {
        bool ignored;
        return set(key, value, ignored);
    }

    /**
     * Set a key/value pair.  If the key/value pair doesn't already exist, it
     * is added, and the wasAdded parameter is set to true.
     */
    HashMap set(K key, V value, out bool wasAdded)
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
    HashMap set(KeyedIterator!(K, V) source)
    {
        uint ignored;
        return set(source, ignored);
    }

    /**
     * Set all the values from the iterator in the map.  If any elements did
     * not previously exist, they are added.  numAdded is set to the number of
     * elements that were added in this operation.
     */
    HashMap set(KeyedIterator!(K, V) source, out uint numAdded)
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
    HashMap remove(Iterator!(K) subset)
    {
        foreach(k; subset)
            remove(k);
        return this;
    }

    /**
     * Remove all keys from the map which are in subset.  numRemoved is set to
     * the number of keys that were actually removed.
     */
    HashMap remove(Iterator!(K) subset, out uint numRemoved)
    {
        uint origlength = length;
        remove(subset);
        numRemoved = origlength - length;
        return this;
    }

    HashMap intersect(Iterator!(K) subset)
    {
        uint ignored;
        return intersect(subset, ignored);
    }

    /**
     * This function only keeps elements that are found in subset.
     */
    HashMap intersect(Iterator!(K) subset, out uint numRemoved)
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
        // scope allocates on the stack.
        //
        scope w = new TransformIterator!(element, K)(subset, function void(ref K k, ref element e) { e.key = k;});

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
        return elemAt(key) != end;
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
    HashMap dup()
    {
        return new HashMap(_hash);
    }

    /**
     * Compare this HashMap with another Map
     *
     * Returns 0 if o is not a Map object, is null, or the HashMap does not
     * contain the same key/value pairs as the given map.
     * Returns 1 if exactly the key/value pairs contained in the given map are
     * in this HashMap.
     */
    bool opEquals(Object o)
    {
        //
        // try casting to map, otherwise, don't compare
        //
        auto m = cast(Map!(K, V))o;
        if(m !is null && m.length == length)
        {
            auto _end = end;
            foreach(K k, V v; m)
            {
                auto cu = elemAt(k);
                if(cu.empty || cu.value != v)
                    return false;
            }
            return true;
        }

        return false;
    }

    /**
     * Set all the elements from the given associative array in the map.  Any
     * key that already exists will be overridden.
     *
     * returns this.
     */
    HashMap set(V[K] source)
    {
        foreach(K k, V v; source)
            this[k] = v;
        return this;
    }

    /**
     * Set all the elements from the given associative array in the map.  Any
     * key that already exists will be overridden.
     *
     * sets numAdded to the number of key value pairs that were added.
     *
     * returns this.
     */
    HashMap set(V[K] source, out uint numAdded)
    {
        uint origLength = length;
        set(source);
        numAdded = length - origLength;
        return this;
    }

    /**
     * Remove all the given keys from the map.
     *
     * return this.
     */
    HashMap remove(K[] subset)
    {
        foreach(k; subset)
            remove(k);
        return this;
    }

    /**
     * Remove all the given keys from the map.
     *
     * return this.
     *
     * numRemoved is set to the number of elements removed.
     */
    HashMap remove(K[] subset, out uint numRemoved)
    {
        uint origLength = length;
        remove(subset);
        numRemoved = origLength - length;
        return this;
    }

    /**
     * Remove all the keys that are not in the given array.
     *
     * returns this.
     */
    HashMap intersect(K[] subset)
    {
        scope iter = new ArrayIterator!(K)(subset);
        return intersect(iter);
    }

    /**
     * Remove all the keys that are not in the given array.
     *
     * sets numRemoved to the number of elements removed.
     *
     * returns this.
     */
    HashMap intersect(K[] subset, out uint numRemoved)
    {
        scope iter = new ArrayIterator!(K)(subset);
        return intersect(iter, numRemoved);
    }
}

unittest
{
    HashMap!(uint, uint) hm = new HashMap!(uint, uint);
    Map!(uint, uint) m = hm;
    for(int i = 0; i < 10; i++)
        hm[i * i + 1] = i;
    assert(hm.length == 10);
    foreach(ref doPurge, k, v; &hm.keypurge)
    {
        doPurge = (v % 2 == 1);
    }
    assert(hm.length == 5);
    assert(hm.containsKey(6 * 6 + 1));
}
