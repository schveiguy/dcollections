/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.TreeMap;

public import dcollections.model.Map;
public import dcollections.DefaultFunctions;

private import dcollections.RBTree;
private import dcollections.Iterators;

/**
 * Implementation of the Map interface using Red-Black trees.  this allows for
 * O(lg(n)) insertion, removal, and lookup times.  It also creates a sorted
 * set of keys.  K must be comparable.
 *
 * Adding an element does not invalidate any cursors.
 *
 * Removing an element only invalidates the cursors that were pointing at
 * that element.
 *
 * You can replace the Tree implementation with a custom implementation, the
 * implementation must be a struct template which can be instantiated with a
 * single template argument V, and must implement the following members
 * (non-function members can be properties unless otherwise specified):
 *
 * parameters -> must be a struct with at least the following members:
 *   compareFunction -> the compare function to use (should be a
 *                      CompareFunction!(V))
 *   updateFunction -> the update function to use (should be an
 *                     UpdateFunction!(V))
 * 
 * void setup(parameters p) -> initializes the tree with the given parameters.
 *
 * uint count -> count of the elements in the tree
 *
 * node -> must be a struct/class with the following members:
 *   V value -> the value which is pointed to by this position (cannot be a
 *                property)
 *   node next -> the next node in the tree as defined by the compare
 *                function, or end if no other nodes exist.
 *   node prev -> the previous node in the tree as defined by the compare
 *                function.
 *
 * bool add(V v) -> add the given value to the tree according to the order
 * defined by the compare function.  If the element already exists in the
 * tree, the update function should be called, and the function should return
 * false.
 *
 * node begin -> must be a node that points to the very first valid
 * element in the tree, or end if no elements exist.
 *
 * node end -> must be a node that points to just past the very last
 * valid element.
 *
 * node find(V v) -> returns a node that points to the element that
 * contains v, or end if the element doesn't exist.
 *
 * node remove(node p) -> removes the given element from the tree,
 * returns the next valid element or end if p was last in the tree.
 *
 * void clear() -> removes all elements from the tree, sets count to 0.
 */
class TreeMap(K, V, alias ImplTemp=RBTree, alias compareFunc=DefaultCompare) : Map!(K, V)
{
    /**
     * the elements that are passed to the tree.  Note that if you define a
     * custom update or compare function, it should take element structs, not
     * K or V.
     */
    struct element
    {
        K key;
        V val;
    }

    private KeyIterator _keys;

    /**
     * Compare function used internally to compare two keys
     */
    static int _compareFunction(ref element e, ref element e2)
    {
        return compareFunc(e.key, e2.key);
    }

    /**
     * Update function used internally to update the value of a node
     */
    static void _updateFunction(ref element orig, ref element newv)
    {
        orig.val = newv.val;
    }

    /**
     * convenience alias to the implementation
     */
    alias ImplTemp!(element, _compareFunction, _updateFunction) Impl;

    private Impl _tree;

    /**
     * A cursor for elements in the tree
     */
    struct cursor
    {
        private Impl.Node ptr;
        private bool _empty = false;

        /**
         * get the value in this element
         */
        @property V front()
        {
            assert(!_empty, "Attempting to read the value of an empty cursor of " ~ TreeMap.stringof);
            return ptr.value.val;
        }

        /**
         * get the key in this element
         */
        @property K key()
        {
            assert(!_empty, "Attempting to read the key of an empty cursor of " ~ TreeMap.stringof);
            return ptr.value.key;
        }

        /**
         * set the value in this element
         */
        @property V front(V v)
        {
            assert(!_empty, "Attempting to write the value of an empty cursor of " ~ TreeMap.stringof);
            ptr.value.val = v;
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
            assert(!_empty, "Attempting to popFront() an empty cursor of " ~ TreeMap.stringof);
            _empty = true;
            ptr = ptr.next;
        }

        /**
         * compare two cursors for equality
         */
        bool opEquals(const cursor it) const
        {
            return it.ptr is ptr;
        }
    }

    /**
     * A range that can be used to iterate over the elements in the tree.
     */
    struct range
    {
        private Impl.Node _begin;
        private Impl.Node _end;

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
            c.ptr = _begin;
            c._empty = empty;
            return c;
        }

        /**
         * Get a cursor to the end element in the range
         */
        @property cursor end()
        {
            cursor c;
            c.ptr = _end;
            c._empty = true;
            return c;
        }

        /**
         * Get the first value in the range
         */
        @property V front()
        {
            assert(!empty, "Attempting to read front of an empty range cursor of " ~ TreeMap.stringof);
            return _begin.ptr.value.val;
        }

        /**
         * Write the first value in the range.
         */
        @property V front(V v)
        {
            assert(!empty, "Attempting to write front of an empty range cursor of " ~ TreeMap.stringof);
            _begin.ptr.value.val = v;
            return v;
        }

        /**
         * Get the key of the front element
         */
        @property K key()
        {
            assert(!empty, "Attempting to read the key of an empty range of " ~ TreeMap.stringof);
            return _begin.value.key;
        }

        /**
         * Get the last value in the range
         */
        @property V back()
        {
            assert(!empty, "Attempting to read the back of an empty range of " ~ TreeMap.stringof);
            return _end.prev.value.val;
        }

        /**
         * Write the last value in the range
         */
        @property V back(V v)
        {
            assert(!empty, "Attempting to write the back of an empty range of " ~ TreeMap.stringof);
            _end.prev.value.val = v;
            return v;
        }

        /**
         * Get the key of the last element in the range
         */
        @property K backKey()
        {
            assert(!empty, "Attempting to read the back key of an empty range of " ~ TreeMap.stringof);
            return _end.prev.value.key;
        }

        /**
         * Move the front of the range ahead one element
         */
        void popFront()
        {
            assert(!empty, "Attempting to popFront() an empty range of " ~ TreeMap.stringof);
            _begin = _begin.next;
        }

        /**
         * Move the back of the range to the previous element
         */
        void popBack()
        {
            assert(!empty, "Attempting to popBack() an empty range of " ~ TreeMap.stringof);
            _end = _end.prev;
        }
    }

    /**
     * Determine if a cursor belongs to the treemap
     */
    bool belongs(cursor c)
    {
        // rely on the implementation to tell us
        return _tree.belongs(c.ptr);
    }

    /**
     * Determine if a range belongs to the treemap
     */
    bool belongs(range r)
    {
        return _tree.belongs(r._begin) && _tree.belongs(r._end);
    }

    /**
     * Iterate over the collection, deciding which elements should be purged
     * along the way.
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
     * Purge with keys
     */
    final int keypurge(scope int delegate(ref bool doPurge, ref K k, ref V v) dg)
    {
        return _apply(dg);
    }

    private class KeyIterator : Iterator!(K)
    {
        final uint length()
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
        auto it = _tree.begin;
        bool doPurge;
        int dgret = 0;
        auto _end = _tree.end; // cache end so it isn't always being generated
        while(it !is _end)
        {
            //
            // don't allow user to change key
            //
            K tmpkey = it.value.key;
            doPurge = false;
            if((dgret = dg(doPurge, tmpkey, it.value.val)) != 0)
                break;
            if(doPurge)
                it = _tree.remove(it);
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
     * Instantiate the tree map
     */
    this()
    {
        _keys = new KeyIterator;
    }

    //
    // private constructor for dup
    //
    private this(ref Impl dupFrom)
    {
        dupFrom.copyTo(_tree);
        _keys = new KeyIterator;
    }

    /**
     * Clear the collection of all elements
     */
    TreeMap clear()
    {
        _tree.clear();
        return this;
    }

    /**
     * returns number of elements in the collection
     */
    @property uint length() const
    {
        return _tree.count;
    }

    /**
     * returns a cursor to the first element in the collection.
     */
    @property cursor begin()
    {
        cursor it;
        it.ptr = _tree.begin;
        it._empty = (_tree.count == 0);
        return it;
    }

    /**
     * returns a cursor that points just past the last element in the
     * collection.
     */
    @property cursor end()
    {
        cursor it;
        it.ptr = _tree.end;
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
     * Runs in O(lg(n)) time.
     */
    cursor remove(cursor it)
    {
        if(!it.empty)
        {
            it.ptr = _tree.remove(it.ptr);
        }
        it.empty = (it.ptr == _tree.end);
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
     * get a slice of all the elements in this collection.
     */
    range opSlice()
    {
        range result;
        range._begin = _tree.begin;
        range._end = _tree.end;
        return result;
    }

    /*
     * Create a range without checks to make sure b and e are part of the
     * collection.
     */
    private range _slice(cursor b, cursor e)
    {
        range result;
        result._begin = b.ptr;
        result._end = e.ptr;
        return result;
    }

    /**
     * get a slice of the elements between the two cursors.
     *
     * As long as b and e are members of the treemap, and b's position is
     * before e, the function takes O(lgn) time to complete.  Because the
     * treemap is sorted, we can always ensure with one function call that b is
     * before e.  Determining that b and e are part of the collection is a
     * matter of traversing the tree.
     */
    range opSlice(cursor b, cursor e)
    {
        int order;
        if(_tree.positionCompare(b, e, order) && order <= 0)
        {
            // both cursors are part of the tree map and are correctly ordered.
            return _slice(b, e);
        }
        throw new RangeError("invalid slice parameters to " ~ TreeMap.stringof);
    }

    /**
     * Create a slice based on keys instead of based on cursors.
     *
     * b must be <= e, and b and e must both match elements in the collection.
     * Note that e cannot match end, so in order to get *all* the elements, you
     * must call the opSlice(K, end) version of the function.
     *
     * Note, a valid slice is only returned if both b and e exist in the
     * collection.  For example, if you have a treemap that contains the keys
     * "a" and "b", you cannot get a slice ["aa".."b"] because "aa" is not a
     * member of the collection.  While this seems strict, it is an
     * interpretation of the rules for slicing normal arrays -- you are not
     * allowed to pass indexes that don't exist for that array.
     *
     * runs in O(lgn) time.
     */
    range opSlice(K b, K e)
    {
        if(compareFunc(b, e) <= 0)
        {
            auto belem = elemAt(b);
            auto eelem = elemAt(e);
            // note, no reason to check for whether belem and eelem are members
            // of the tree, we just verified that!
            if(!belem.empty && !eelem.empty)
            {
                return _slice(belem, eelem);
            }
        }
        throw new RangeError("invalid slice parameters to " ~ TreeMap.stringof);
    }

    /**
     * Slice between a key and a cursor.
     *
     * runs in O(lgn) time.
     */
    range opSlice(K b, cursor e)
    {
        auto belem = elemAt(b);
        if(!belem.empty)
        {
            int order;
            if(_tree.positionCompare(belem, e, order) && order <= 0)
            {
                return _slice(belem, e);
            }
        }
        throw new RangeError("invalid slice parameters to " ~ TreeMap.stringof);
    }

    /**
     * Slice between a cursor and a key
     *
     * runs in O(lgn) time.
     */
    range opSlice(cursor b, K e)
    {
        auto eelem = elemAt(e);
        if(!eelem.empty)
        {
            int order;
            if(_tree.positionCompare(b, eelem, order) && order <= 0)
            {
                return _slice(b, eelem);
            }
        }
        throw new RangeError("invalid slice parameters to " ~ TreeMap.stringof);
    }

    /**
     * find the instance of a key in the collection.  Returns end if the key
     * is not present.
     *
     * Runs in O(lg(n)) time.
     */
    cursor elemAt(K k)
    {
        cursor it;
        element tmp;
        tmp.key = k;
        it.ptr = _tree.find(tmp);
        it._empty = (it.ptr == _tree.end);
        return it;
    }

    /**
     * Removes the element that has the given key.  Returns true if the
     * element was present and was removed.
     *
     * Runs in O(lg(n)) time.
     */
    TreeMap remove(K key)
    {
        remove(elemAt(key));
        return this;
    }

    /**
     * Removes the element that has the given key.  Returns true if the
     * element was present and was removed.
     *
     * Runs in O(lg(n)) time.
     */
    TreeMap remove(K key, out bool wasRemoved)
    {
        cursor it = elemAt(key);
        wasRemoved = !it.empty;
        remove(it);
        return this;
    }

    /**
     * Removes all the elements whose keys are in the subset.
     * 
     * returns this.
     */
    TreeMap remove(Iterator!(K) subset)
    {
        foreach(k; subset)
            removeAt(k);
        return this;
    }

    /**
     * Removes all the elements whose keys are in the subset.  Sets numRemoved
     * to the number of key/value pairs removed.
     * 
     * returns this.
     */
    TreeMap remove(Iterator!(K) subset, out uint numRemoved)
    {
        uint origLength = length;
        remove(subset);
        numRemoved = origLength - length;
        return this;
    }

    /**
     * removes all elements in the map whose keys are NOT in subset.
     *
     * returns this.
     */
    TreeMap intersect(Iterator!(K) subset, out uint numRemoved)
    {
        //
        // create a wrapper iterator that generates elements from keys.  Then
        // defer the intersection operation to the implementation.
        //
        // scope allocates on the stack.
        //
        scope w = new TransformIterator!(element, K)(subset, function void(ref K k, ref element e) { e.key = k;});

        numRemoved = _tree.intersect(w);
        return this;
    }

    /**
     * removes all elements in the map whose keys are NOT in subset.  Sets
     * numRemoved to the number of elements removed.
     *
     * returns this.
     */
    TreeMap intersect(Iterator!(K) subset)
    {
        uint ignored;
        intersect(subset, ignored);
        return this;
    }

    Iterator!(K) keys()
    {
        return _keys;
    }

    /**
     * Returns the value that is stored at the element which has the given
     * key.  Throws an exception if the key is not in the collection.
     *
     * Runs in O(lg(n)) time.
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
     * Runs in O(lg(n)) time.
     */
    V opIndexAssign(V value, K key)
    {
        set(key, value);
        return value;
    }

    /**
     * set a key and value pair.  If the pair didn't already exist, add it.
     *
     * returns this.
     */
    TreeMap set(K key, V value)
    {
        bool ignored;
        return set(key, value, ignored);
    }

    /**
     * set a key and value pair.  If the pair didn't already exist, add it.
     * wasAdded is set to true if the pair was added.
     *
     * returns this.
     */
    TreeMap set(K key, V value, out bool wasAdded)
    {
        element elem;
        elem.key = key;
        elem.val = value;
        wasAdded = _tree.add(elem);
        return this;
    }

    /**
     * set all the elements from the given keyed iterator in the map.  Any key
     * that already exists will be overridden.
     *
     * Returns this.
     */
    TreeMap set(KeyedIterator!(K, V) source)
    {
        foreach(k, v; source)
            set(k, v);
        return this;
    }

    /**
     * set all the elements from the given keyed iterator in the map.  Any key
     * that already exists will be overridden.  numAdded is set to the number
     * of key/value pairs that were added.
     *
     * Returns this.
     */
    TreeMap set(KeyedIterator!(K, V) source, out uint numAdded)
    {
        uint origLength = length;
        set(source);
        numAdded = length - origLength;
        return this;
    }

    /**
     * Returns true if the given key is in the collection.
     *
     * Runs in O(lg(n)) time.
     */
    bool containsKey(K key)
    {
        return elemAt(key) != end;
    }

    /**
     * Get a duplicate of this tree map
     */
    TreeMap dup()
    {
        return new TreeMap(_tree);
    }

    /**
     * Compare this TreeMap with another Map
     *
     * Returns 0 if o is not a Map object, is null, or the TreeMap does not
     * contain the same key/value pairs as the given map.
     * Returns 1 if exactly the key/value pairs contained in the given map are
     * in this TreeMap.
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
            auto tm = cast(TreeMap)o;
            if(tm !is null)
            {
                //
                // special case, we know that a tree map is sorted.
                //
                auto c1 = begin;
                auto c2 = tm.begin;
                while(c1 != _end)
                {
                    if(c1.key != c2.key || c1++.value != c2++.value)
                        return false;
                }
            }
            else
            {
                foreach(K k, V v; m)
                {
                    auto cu = find(k);
                    if(cu is _end || cu.value != v)
                        return false;
                }
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
    TreeMap set(V[K] source)
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
    TreeMap set(V[K] source, out uint numAdded)
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
    TreeMap remove(K[] subset)
    {
        foreach(k; subset)
            removeAt(k);
        return this;
    }

    /**
     * Remove all the given keys from the map.
     *
     * return this.
     *
     * numRemoved is set to the number of elements removed.
     */
    TreeMap remove(K[] subset, out uint numRemoved)
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
    TreeMap intersect(K[] subset)
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
    TreeMap intersect(K[] subset, out uint numRemoved)
    {
        scope iter = new ArrayIterator!(K)(subset);
        return intersect(iter, numRemoved);
    }

}

unittest
{
    auto tm = new TreeMap!(uint, uint);
    Map!(uint, uint) m = tm;
    for(int i = 0; i < 10; i++)
        m[i * i + 1] = i;
    assert(m.length == 10);
    foreach(ref doPurge, k, v; &m.keypurge)
    {
        doPurge = (v % 2 == 1);
    }
    assert(m.length == 5);
    assert(m.contains(6));
    assert(m.containsKey(6 * 6 + 1));
}
