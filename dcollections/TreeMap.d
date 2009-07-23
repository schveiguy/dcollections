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

        /**
         * get the value in this element
         */
        V value()
        {
            return ptr.value.val;
        }

        /**
         * get the key in this element
         */
        K key()
        {
            return ptr.value.key;
        }

        /**
         * set the value in this element
         */
        V value(V v)
        {
            ptr.value.val = v;
            return v;
        }

        /**
         * increment this cursor, returns what the cursor was before
         * incrementing.
         */
        cursor opPostInc()
        {
            cursor tmp = *this;
            ptr = ptr.next;
            return tmp;
        }

        /**
         * decrement this cursor, returns what the cursor was before
         * decrementing.
         */
        cursor opPostDec()
        {
            cursor tmp = *this;
            ptr = ptr.prev;
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
                ptr = ptr.next;
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
                ptr = ptr.prev;
            return *this;
        }

        /**
         * compare two cursors for equality
         */
        bool opEquals(cursor it)
        {
            return it.ptr is ptr;
        }
    }

    final int purge(int delegate(ref bool doPurge, ref V v) dg)
    {
        int _dg(ref bool doPurge, ref K k, ref V v)
        {
            return dg(doPurge, v);
        }
        return _apply(&_dg);
    }

    final int keypurge(int delegate(ref bool doPurge, ref K k, ref V v) dg)
    {
        return _apply(dg);
    }

    private class KeyIterator : Iterator!(K)
    {
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
            if((dgret = dg(doPurge, tmpkey, it.ptr.value.val)) != 0)
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
     * Instantiate the tree map using the implementation parameters given.
     *
     * Set members of p to their initializer values in order to use the
     * default values defined by TreeMap.
     *
     * The default compare function performs K's compare.
     *
     * The default update function sets only the V part of the element, and
     * leaves the K part alone.
     */
    this()
    {
        _tree.setup();
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
    uint length()
    {
        return _tree.count;
    }

    /**
     * returns a cursor to the first element in the collection.
     */
    cursor begin()
    {
        cursor it;
        it.ptr = _tree.begin;
        return it;
    }

    /**
     * returns a cursor that points just past the last element in the
     * collection.
     */
    cursor end()
    {
        cursor it;
        it.ptr = _tree.end;
        return it;
    }

    /**
     * remove the element pointed at by the given cursor, returning an
     * cursor that points to the next element in the collection.
     *
     * Runs in O(lg(n)) time.
     */
    cursor remove(cursor it)
    {
        it.ptr = _tree.remove(it.ptr);
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
     * Runs in O(lg(n)) time.
     */
    cursor find(K k)
    {
        cursor it;
        element tmp;
        tmp.key = k;
        it.ptr = _tree.find(tmp);
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
    TreeMap remove(V v)
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
    TreeMap remove(V v, ref bool wasRemoved)
    {
        cursor it = findValue(v);
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
     * Removes the element that has the given key.  Returns true if the
     * element was present and was removed.
     *
     * Runs in O(lg(n)) time.
     */
    TreeMap removeAt(K key)
    {
        cursor it = find(key);
        if(it != end)
            remove(it);
        return this;
    }

    /**
     * Removes the element that has the given key.  Returns true if the
     * element was present and was removed.
     *
     * Runs in O(lg(n)) time.
     */
    TreeMap removeAt(K key, ref bool wasRemoved)
    {
        cursor it = find(key);
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
    TreeMap remove(Iterator!(K) subset, ref uint numRemoved)
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
    TreeMap intersect(Iterator!(K) subset, ref uint numRemoved)
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
        cursor it = find(key);
        if(it == end)
            throw new Exception("Index out of range");
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
    TreeMap set(K key, V value, ref bool wasAdded)
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
    TreeMap set(KeyedIterator!(K, V) source, ref uint numAdded)
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
            if(x == v)
                instances++;
        return instances;
    }

    /**
     * Remove all the elements that contain the value v.
     *
     * Runs in O(n + m lg(n)) time, where m is the number of elements removed.
     */
    TreeMap removeAll(V v)
    {
        foreach(ref b, x; &purge)
            b = cast(bool)(x == v);
        return this;
    }

    /**
     * Remove all the elements that contain the value v.
     *
     * Runs in O(n + m lg(n)) time, where m is the number of elements removed.
     */
    TreeMap removeAll(V v, ref uint numRemoved)
    {
        uint origLength = length;
        removeAll(v);
        numRemoved = origLength - length;
        return this;
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
    int opEquals(Object o)
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
                        return 0;
                }
            }
            else
            {
                foreach(K k, V v; m)
                {
                    auto cu = find(k);
                    if(cu is _end || cu.value != v)
                        return 0;
                }
            }
            return 1;
        }

        return 0;
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
    TreeMap set(V[K] source, ref uint numAdded)
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
    TreeMap remove(K[] subset, ref uint numRemoved)
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
    TreeMap intersect(K[] subset, ref uint numRemoved)
    {
        scope iter = new ArrayIterator!(K)(subset);
        return intersect(iter, numRemoved);
    }

}

version(UnitTest)
{
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
}
