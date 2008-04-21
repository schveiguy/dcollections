/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.TreeMap;

public import dcollections.model.Map;

private import dcollections.RBTree;

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
class TreeMap(K, V, alias ImplTemp = RBTree) : Map!(K, V)
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

    /**
     * convenience alias to the implementation
     */
    alias ImplTemp!(element) Impl;
    private Impl _tree;
    private Purger _purger;

    private static final int compareFunction(ref element e, ref element e2)
    {
        return typeid(K).compare(&e.key, &e2.key);
    }

    private static final void updateFunction(ref element orig, ref element newv)
    {
        orig.val = newv.val;
    }

    /**
     * A cursor for elements in the tree
     */
    struct cursor
    {
        private Impl.node ptr;

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
    this(Impl.parameters p)
    {
        // insert defaults for the functions if necessary.
        if(!p.updateFunction)
            p.updateFunction = &updateFunction;
        if(!p.compareFunction)
            p.compareFunction = &compareFunction;
        _tree.setup(p);
        _purger = new Purger;
    }

    /**
     * Instantiate the tree map using the default implementation parameters.
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
        _tree.clear();
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
        return _tree.count;
    }

    /**
     * returns a cursor to the first element in the collection.
     */
    final cursor begin()
    {
        cursor it;
        it.ptr = _tree.begin;
        return it;
    }

    /**
     * returns a cursor that points just past the last element in the
     * collection.
     */
    final cursor end()
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
     * Runs in O(lg(n)) time.
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
        element elem;
        elem.key = key;
        elem.val = value;
        _tree.add(elem);
        return value;
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
    uint removeAll(V v)
    {
        uint origLength = length;
        foreach(ref b, x; purger)
            if(x == v)
                b = true;
        return origLength - length;
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
