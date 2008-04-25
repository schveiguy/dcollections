/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.TreeMultiset;

public import dcollections.model.Multiset;

private import dcollections.RBTree;

/**
 * Implementation of the Multiset interface using Red-Black trees.  this
 * allows for O(lg(n)) insertion, removal, and lookup times.  It also creates
 * a sorted set of elements.  V must be comparable.
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
 * tree, the function should add it after all equivalent elements.
 *
 * node begin -> must be a node that points to the very first valid
 * element in the tree, or end if no elements exist.
 *
 * node end -> must be a node that points to just past the very last
 * valid element.
 *
 * node find(V v) -> returns a node that points to the first element in the
 * tree that contains v, or end if the element doesn't exist.
 *
 * node remove(node p) -> removes the given element from the tree,
 * returns the next valid element or end if p was last in the tree.
 *
 * void clear() -> removes all elements from the tree, sets count to 0.
 *
 * uint countAll(V v) -> returns the number of elements with the given value.
 *
 * node removeAll(V v) -> removes all the given values from the tree.
 */
class TreeMultiset(V, alias ImplTemp = RBDupTree) : Multiset!(V)
{
    /**
     * convenience alias
     */
    alias ImplTemp!(V) Impl;

    /**
     * convenience alias
     */
    alias TreeMultiset!(V, ImplTemp) TreeMultisetType;

    private Impl _tree;
    private Purger _purger;

    private static int compareFunction(ref V e, ref V e2)
    {
        return typeid(V).compare(&e, &e2);
    }

    /**
     * cursor for the tree multiset
     */
    struct cursor
    {
        private Impl.node ptr;

        /**
         * get the value in this element
         */
        V value()
        {
            return ptr.value;
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

    private class Purger : PurgeIterator!(V)
    {
        final int opApply(int delegate(ref bool doPurge, ref V v) dg)
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
                it = remove(it);
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
        int _dg(ref bool doPurge, ref V v)
        {
            return dg(v);
        }
        return _apply(&_dg);
    }

    /**
     * Instantiate the tree multiset using the implementation parameters
     * given.
     */
    this(Impl.parameters p)
    {
        // insert defaults
        if(!p.compareFunction)
            p.compareFunction = &compareFunction;
        _tree.setup(p);
        _purger = new Purger;
    }

    /**
     * Instantiate the tree multiset using the default implementation
     * parameters.
     */
    this()
    {
        Impl.parameters p;
        this(p);
    }

    //
    // for dup
    //
    private this(ref Impl dupFrom)
    {
        dupFrom.copyTo(_tree);
        _purger = new Purger;
    }

    /**
     * Clear the collection of all elements
     */
    TreeMultisetType clear()
    {
        _tree.clear();
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
     * find the first instance of a given value in the collection.  Returns
     * end if the value is not present.
     *
     * Runs in O(lg(n)) time.
     */
    cursor find(V v)
    {
        cursor it;
        it.ptr = _tree.find(v);
        return it;
    }

    /**
     * Returns true if the given value exists in the collection.
     *
     * Runs in O(lg(n)) time.
     */
    bool contains(V v)
    {
        return find(v) != end;
    }

    /**
     * Removes the first element that has the value v.  Returns true if the
     * value was present and was removed.
     *
     * Runs in O(lg(n)) time.
     */
    TreeMultisetType remove(V v)
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
     * Runs in O(lg(n)) time.
     */
    TreeMultisetType remove(V v, ref bool wasRemoved)
    {
        cursor it = find(v);
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
     * returns an object that can be used to purge the collection.
     */
    PurgeIterator!(V) purger()
    {
        return _purger;
    }

    /**
     * Adds a value to the collection.
     * Returns this.
     *
     * Runs in O(lg(n)) time.
     */
    TreeMultisetType add(V v)
    {
        _tree.add(v);
        return this;
    }

    /**
     * Adds a value to the collection. Sets wasAdded to true if the value was
     * added.
     *
     * Returns this.
     *
     * Runs in O(lg(n)) time.
     */
    TreeMultisetType add(V v, ref bool wasAdded)
    {
        wasAdded = _tree.add(v);
        return this;
    }

    /**
     * Adds all the values from the iterator to the collection.
     *
     * Runs in O(m lg(n)) time, where m is the number of elements in
     * the iterator.
     */
    TreeMultisetType add(Iterator!(V) it)
    {
        foreach(v; it)
            _tree.add(v);
        return this;
    }

    /**
     * Adds all the values from the iterator to the collection. Sets numAdded
     * to the number of values added from the iterator.
     *
     * Runs in O(m lg(n)) time, where m is the number of elements in
     * the iterator.
     */
    TreeMultisetType add(Iterator!(V) it, ref uint numAdded)
    {
        uint origlength = length;
        add(it);
        numAdded = length - origlength;
        return this;
    }

    /**
     * Adds all the values from array to the collection.
     *
     * Runs in O(m lg(n)) time, where m is the number of elements in
     * array.
     */
    TreeMultisetType add(V[] array)
    {
        foreach(v; array)
            _tree.add(v);
        return this;
    }

    /**
     * Adds all the values from array to the collection.  Sets numAdded to the
     * number of elements added from the array.
     *
     * Runs in O(m lg(n)) time, where m is the number of elements in
     * array.
     */
    TreeMultisetType add(V[] array, ref uint numAdded)
    {
        uint origlength = length;
        add(array);
        numAdded = length - origlength;
        return this;
    }

    /**
     * Returns the number of elements in the collection that are equal to v.
     *
     * Runs in O(m lg(n)) time, where m is the number of elements that are v.
     */
    uint count(V v)
    {
        return _tree.countAll(v);
    }

    /**
     * Removes all the elements that are equal to v.
     *
     * Runs in O(m lg(n)) time, where m is the number of elements that are v.
     */
    TreeMultiset removeAll(V v)
    {
        _tree.removeAll(v);
        return this;
    }
    
    /**
     * Removes all the elements that are equal to v.  Sets numRemoved to the
     * number of elements removed from the multiset.
     *
     * Runs in O(m lg(n)) time, where m is the number of elements that are v.
     */
    TreeMultiset removeAll(V v, ref uint numRemoved)
    {
        numRemoved = _tree.removeAll(v);
        return this;
    }

    /**
     * duplicate this tree multiset
     */
    TreeMultiset dup()
    {
        return new TreeMultiset(_tree);
    }
}
