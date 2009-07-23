/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.TreeSet;

public import dcollections.model.Set;
public import dcollections.DefaultFunctions;

private import dcollections.RBTree;

/**
 * Implementation of the Set interface using Red-Black trees.  this allows for
 * O(lg(n)) insertion, removal, and lookup times.  It also creates a sorted
 * set.  V must be comparable.
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
 * tree, the 
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
class TreeSet(V, alias ImplTemp = RBNoUpdatesTree, alias compareFunction = DefaultCompare) : Set!(V)
{
    /**
     * convenience alias.
     */
    alias ImplTemp!(V, compareFunction) Impl;

    private Impl _tree;

    /**
     * Iterator for the tree set.
     */
    struct cursor
    {
        private Impl.Node ptr;

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

    /**
     * Iterate through elements of the TreeSet, specifying which ones to
     * remove.
     *
     * Use like this:
     * -------------
     * // remove all odd elements
     * foreach(ref doPurge, v; &treeSet.purge)
     * {
     *   doPurge = ((v % 1) == 1);
     * }
     * -------------
     */
    final int purge(int delegate(ref bool doPurge, ref V v) dg)
    {
        return _apply(dg);
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
     * Instantiate the tree set
     */
    this()
    {
        _tree.setup();
    }

    //
    // for dup
    //
    private this(ref Impl dupFrom)
    {
        dupFrom.copyTo(_tree);
    }

    /**
     * Clear the collection of all elements
     */
    TreeSet clear()
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
     * find the instance of a value in the collection.  Returns end if the
     * value is not present.
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
     * Removes the element that has the value v.  Returns true if the value
     * was present and was removed.
     *
     * Runs in O(lg(n)) time.
     */
    TreeSet remove(V v)
    {
        cursor it = find(v);
        if(it !is end)
            remove(it);
        return this;
    }

    /**
     * Removes the element that has the value v.  Returns true if the value
     * was present and was removed.
     *
     * Runs in O(lg(n)) time.
     */
    TreeSet remove(V v, ref bool wasRemoved)
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
     * Adds a value to the collection.
     * Returns true.
     *
     * Runs in O(lg(n)) time.
     */
    TreeSet add(V v)
    {
        _tree.add(v);
        return this;
    }

    /**
     * Adds a value to the collection.
     * Returns true.
     *
     * Runs in O(lg(n)) time.
     */
    TreeSet add(V v, ref bool wasAdded)
    {
        wasAdded = _tree.add(v);
        return this;
    }

    /**
     * Adds all the values from enumerator to the collection.
     *
     * Runs in O(m lg(n)) time, where m is the number of elements in
     * enumerator.
     */
    TreeSet add(Iterator!(V) it)
    {
        foreach(v; it)
            _tree.add(v);
        return this;
    }

    /**
     * Adds all the values from enumerator to the collection.
     *
     * Runs in O(m lg(n)) time, where m is the number of elements in
     * enumerator.
     */
    TreeSet add(Iterator!(V) it, ref uint numAdded)
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
    TreeSet add(V[] array)
    {
        foreach(v; array)
            _tree.add(v);
        return this;
    }

    /**
     * Adds all the values from array to the collection.
     *
     * Runs in O(m lg(n)) time, where m is the number of elements in
     * array.
     */
    TreeSet add(V[] array, ref uint numAdded)
    {
        uint origlength = length;
        foreach(v; array)
            _tree.add(v);
        numAdded = length - origlength;
        return this;
    }

    /**
     * Return a duplicate treeset containing all the elements in this tree
     * set.
     */
    TreeSet dup()
    {
        return new TreeSet(_tree);
    }

    /**
     * Remove all the elements that match in the subset
     */
    TreeSet remove(Iterator!(V) subset)
    {
        foreach(v; subset)
            remove(v);
        return this;
    }

    /**
     * Remove all the elements that match in the subset.  Sets numRemoved to
     * number of elements removed.
     *
     * returns this.
     */
    TreeSet remove(Iterator!(V) subset, ref uint numRemoved)
    {
        uint origLength = length;
        remove(subset);
        numRemoved = origLength - length;
        return this;
    }

    /**
     * Remove all the elements that do NOT match in the subset.
     *
     * returns this.
     */
    TreeSet intersect(Iterator!(V) subset)
    {
        _tree.intersect(subset);
        return this;
    }

    /**
     * Remove all the elements that do NOT match in the subset.  Sets
     * numRemoved to number of elements removed.
     *
     * returns this.
     */
    TreeSet intersect(Iterator!(V) subset, ref uint numRemoved)
    {
        numRemoved = _tree.intersect(subset);
        return this;
    }

    /**
     * Compare this set with another set.  Returns true if both sets have the
     * same length and every element in one set exists in the other set.
     *
     * If o is null or not a Set, return 0.
     */
    int opEquals(Object o)
    {
        if(o !is null)
        {
            auto s = cast(Set!(V))o;
            if(s !is null && s.length == length)
            {
                auto ts = cast(TreeSet)o;
                auto _end = end;
                if(ts !is null)
                {
                    if(length != ts.length)
                        return 0;

                    //
                    // since we know treesets are sorted, compare elements
                    // using cursors.  This makes opEquals O(n) operation,
                    // versus O(n lg(n)) for other set types.
                    //
                    auto c1 = begin;
                    auto c2 = ts.begin;
                    while(c1 != _end)
                    {
                        if(c1++.value != c2++.value)
                            return 0;
                    }
                    return 1;
                }
                else
                {
                    foreach(elem; s)
                    {
                        //
                        // less work then calling contains(), which builds end
                        // each time
                        //
                        if(find(elem) == _end)
                            return 0;
                    }

                    //
                    // equal
                    //
                    return 1;
                }
            }
        }
        //
        // no comparison possible.
        //
        return 0;
    }

    /**
     * get the most convenient element in the set.  This is the element that
     * would be iterated first.  Therefore, calling remove(get()) is
     * guaranteed to be less than an O(n) operation.
     */
    V get()
    {
        return begin.value;
    }

    /**
     * Remove the most convenient element from the set, and return its value.
     * This is equivalent to remove(get()), except that only one lookup is
     * performed.
     */
    V take()
    {
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
        auto ts = new TreeSet!(uint);
        Set!(uint) s = ts;
        s.add([0U, 1, 2, 3, 4, 5, 5]);
        assert(s.length == 6);
        foreach(ref doPurge, i; &s.purge)
            doPurge = (i % 2 == 1);
        assert(s.length == 3);
        assert(s.contains(4));
    }
}
