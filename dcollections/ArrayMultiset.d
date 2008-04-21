/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.ArrayMultiset;

public import dcollections.model.Multiset;

private import dcollections.Link;

/**
 * This class implements the multiset interface by keeping a linked list of
 * arrays to store the elements.  Because the set does not need to maintain a
 * specific order, removal and addition is an O(1) operation.
 *
 * Removing an element invalidates all cursors.
 *
 * Adding an element does not invalidate any cursors.
 */
class ArrayMultiset(V) : Multiset!(V)
{
    private alias Link!(V[]) node;
    private node _head;
    private uint _count;

    private Purger _purger;

    private uint _growSize;

    /**
     * A cursor is like a pointer into the ArrayMultiset collection.
     */
    struct cursor
    {
        private node ptr;
        private uint idx;

        /**
         * returns the value pointed at by the cursor
         */
        V value()
        {
            return ptr.value[idx];
        }

        /**
         * Sets the value pointed at by the cursor.
         */
        V value(V v)
        {
            return (ptr.value[idx] = v);
        }

        /**
         * increment the cursor, returns what the cursor was before
         * incrementing
         */
        cursor opPostInc()
        {
            cursor tmp = *this;
            idx++;
            if(idx >= ptr.value.length)
            {
                idx = 0;
                ptr = ptr.next;
            }
            return tmp;
        }

        /**
         * decrement the cursor, returns what the cursor was before
         * decrementing
         */
        cursor opPostDec()
        {
            cursor tmp = *this;
            if(idx == 0)
            {
                ptr = ptr.prev;
                idx = ptr.value.length - 1;
            }
            else
                idx--;
            return tmp;
        }

        /**
         * add a given value to the cursor.
         *
         * Runs in O(n) time, but the constant is < 1
         */
        cursor opAddAssign(int inc)
        {
            if(inc < 0)
                return opSubAssign(-inc);
            while(inc >= ptr.value.length - idx)
            {
                inc -= (ptr.value.length - idx);
                ptr = ptr.next;
                idx = 0;
            }
            idx += inc;
            return *this;
        }

        /**
         * subtract a given value from the cursor.
         *
         * Runs in O(n) time, but the constant is < 1
         */
        cursor opSubAssign(int inc)
        {
            if(inc < 0)
                return opAddAssign(-inc);
            while(inc > idx)
            {
                inc -= idx;
                ptr = ptr.prev;
                idx = ptr.value.length;
            }
            idx -= inc;
            return *this;
        }

        /**
         * compare two cursors for equality
         */
        bool opEquals(cursor it)
        {
            return it.ptr is ptr && it.idx is idx;
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
            doPurge = false;
            if((dgret = dg(doPurge, it.ptr.value[it.idx])) != 0)
                break;
            if(doPurge)
                it = remove(it);
            else
                it++;
        }
        return dgret;
    }

    /**
     * Iterate over the collection
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
     * Create an ArrayMultiset with the given grow size.  The grow size is
     * used to allocate new arrays to append to the linked list.
     */
    this(uint gs = 31)
    {
        _growSize = gs;
        _purger = new Purger();
        _head = new node;
        node.attach(_head, _head);
        _count = 0;
    }

    /**
     * Clear the collection of all values
     */
    Collection!(V) clear()
    {
        node.attach(_head, _head);
        return this;
    }

    /**
     * Returns true
     */
    bool supportsLength()
    {
        return true;
    }

    /**
     * Returns the number of elements in the collection
     */
    uint length()
    {
        return _count;
    }

    /**
     * Returns a cursor that points to the first element of the collection.
     */
    cursor begin()
    {
        cursor it;
        it.ptr = _head.next;
        it.idx = 0;
        return it;
    }

    /**
     * Returns a cursor that points just past the last element of the
     * collection.
     */
    cursor end()
    {
        cursor it;
        it.ptr = _head;
        it.idx = 0;
        return it;
    }

    /**
     * Removes the element pointed at by the cursor.  Returns a valid
     * cursor that points to another element or end if the element removed
     * was the last element.
     *
     * Runs in O(1) time.
     */
    cursor remove(cursor it)
    {
        node last = _head.prev;
        if(it.ptr is last && it.idx is last.value.length - 1)
        {
            it = end;
        }
        else
        {
            it.value = last.value[$-1];
        }
        last.value.length = last.value.length - 1;
        if(last.value.length == 0)
            last.unlink;
        _count--;
        return it;
    }

    /**
     * Returns a cursor that points to the first occurrence of v
     *
     * Runs in O(n) time.
     */
    cursor find(V v)
    {
        cursor it = begin;
        cursor _end = end;
        while(it != _end && it.value != v)
            it++;
        return it;
    }

    /**
     * Returns true if v is an element in the set
     *
     * Runs in O(n) time.
     */
    bool contains(V v)
    {
        return find(v) != end;
    }

    /**
     * remove the given element from the set.  This removes the first
     * occurrence only.
     *
     * Returns true if the element was found and removed.
     *
     * Runs in O(n) time.
     */
    bool remove(V v)
    {
        cursor it = find(v);
        if(it == end)
            return false;
        remove(it);
        return true;
    }

    /**
     * Returns an object that can be used to purge the collection.
     */
    PurgeIterator!(V) purger()
    {
        return _purger;
    }

    /**
     * Adds the given element to the set.
     *
     * Returns true.
     *
     * Runs in O(1) time.
     */
    bool add(V v)
    {
        node last = _head.prev;
        if(last is _head || last.value.length == _growSize)
        {
            //
            // pre-allocate array length, then set the length to 0
            //
            auto array = new V[_growSize];
            array.length = 0;
            _head.prepend(new node(array));
            last = _head.prev;
        }

        last.value ~= v;
        _count++;
        return true;
    }

    //
    // these can probably be optimized more
    //

    /**
     * Adds all the values from the given enumerator into the set.
     *
     * Returns the number of elements added.
     */
    uint addAll(Iterator!(V) enumerator)
    {
        uint origlength = length;
        foreach(v; enumerator)
            add(v);
        return length - origlength;
    }

    /**
     * Adds all the values from the given array into the set.
     *
     * Returns the number of elements added.
     */
    uint addAll(V[] array)
    {
        uint origlength = length;
        foreach(v; array)
            add(v);
        return length - origlength;
    }

    /**
     * Count the number of occurrences of v
     *
     * Runs in O(n) time.
     */
    uint count(V v)
    {
        uint retval = 0;
        foreach(x; this)
            if(v == x)
                retval++;
        return retval;
    }

    /**
     * Remove all the occurrences of v.  Returns the number of instances that
     * were removed.
     *
     * Runs in O(n) time.
     */
    uint removeAll(V v)
    {
        uint origlength = length;
        foreach(ref dp, x; _purger)
        {
            if(v == x)
                dp = true;
        }
        return origlength - length;
    }
}
