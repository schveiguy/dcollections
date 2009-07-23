/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.ArrayMultiset;

public import dcollections.model.Multiset;

private import dcollections.Link;
private import dcollections.DefaultAllocator;

/**
 * This class implements the multiset interface by keeping a linked list of
 * arrays to store the elements.  Because the set does not need to maintain a
 * specific order, removal and addition is an O(1) operation.
 *
 * Removing an element invalidates all cursors.
 *
 * Adding an element does not invalidate any cursors.
 */
class ArrayMultiset(V, alias Allocator=DefaultAllocator) : Multiset!(V)
{
    private alias Link!(V[]).Node node;
    private alias Allocator!(Link!(V[])) allocator;
    private allocator alloc;
    private node _head;
    private uint _count;

    private uint _growSize;

    private node allocate()
    {
        return alloc.allocate;
    }

    private node allocate(V[] v)
    {
        auto n = allocate;
        n.value = v;
        return n;
    }

    alias ArrayMultiset!(V, Allocator) ArrayMultisetType;

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

    /**
     * Iterate over the items in the ArrayMultiset, specifying which elements
     * should be removed.
     *
     * Use like this:
     * ----------
     * // remove all odd elements
     * foreach(ref doPurge, elem; &arrayMultiset.purge)
     * {
     *    doPurge = ((elem & 1) == 1)
     * }
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
        _head = alloc.allocate();
        node.attach(_head, _head);
        _count = 0;
    }

    /**
     * Clear the collection of all values
     */
    ArrayMultisetType clear()
    {
        static if(allocator.freeNeeded)
        {
            alloc.freeAll();
            _head = allocate;
        }
        node.attach(_head, _head);
        return this;
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
        {
            last.unlink;
            static if(allocator.freeNeeded)
                alloc.free(last);
        }
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
    ArrayMultisetType remove(V v)
    {
        bool ignored;
        return remove(v, ignored);
    }

    /**
     * remove the given element from the set.  This removes the first
     * occurrence only.
     *
     * Returns true if the element was found and removed.
     *
     * Runs in O(n) time.
     */
    ArrayMultisetType remove(V v, ref bool wasRemoved)
    {
        cursor it = find(v);
        if(it == end)
            wasRemoved = false;
        else
        {
            remove(it);
            wasRemoved = true;
        }
        return this;
    }

    /**
     * Adds the given element to the set.
     *
     * Returns true.
     *
     * Runs in O(1) time.
     */
    ArrayMultisetType add(V v)
    {
        bool ignored;
        return add(v, ignored);
    }
    /**
     * Adds the given element to the set.
     *
     * Returns true.
     *
     * Runs in O(1) time.
     */
    ArrayMultisetType add(V v, ref bool wasAdded)
    {
        node last = _head.prev;
        if(last is _head || last.value.length == _growSize)
        {
            //
            // pre-allocate array length, then set the length to 0
            //
            auto array = new V[_growSize];
            array.length = 0;
            _head.prepend(allocate(array));
            last = _head.prev;
        }

        last.value ~= v;
        wasAdded = true;
        _count++;
        return this;
    }

    //
    // these can probably be optimized more
    //

    /**
     * Adds all the values from the given iterator into the set.
     *
     * Returns the number of elements added.
     */
    ArrayMultisetType add(Iterator!(V) it)
    {
        uint ignored;
        return add(it, ignored);
    }

    /**
     * Adds all the values from the given iterator into the set.
     *
     * Returns the number of elements added.
     */
    ArrayMultisetType add(Iterator!(V) it, ref uint numAdded)
    {
        uint origlength = length;
        foreach(v; it)
            add(v);
        numAdded = length - origlength;
        return this;
    }

    /**
     * Adds all the values from the given array into the set.
     *
     * Returns the number of elements added.
     */
    ArrayMultisetType add(V[] array)
    {
        uint ignored;
        return add(array, ignored);
    }

    /**
     * Adds all the values from the given array into the set.
     *
     * Returns the number of elements added.
     */
    ArrayMultisetType add(V[] array, ref uint numAdded)
    {
        uint origlength = length;
        foreach(v; array)
            add(v);
        numAdded = length - origlength;
        return this;
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
    ArrayMultisetType removeAll(V v)
    {
        uint ignored;
        return removeAll(v, ignored);
    }
    /**
     * Remove all the occurrences of v.  Returns the number of instances that
     * were removed.
     *
     * Runs in O(n) time.
     */
    ArrayMultisetType removeAll(V v, ref uint numRemoved)
    {
        uint origlength = length;
        foreach(ref dp, x; &purge)
        {
            dp = cast(bool)(v == x);
        }
        numRemoved = origlength - length;
        return this;
    }

    /**
     * duplicate this container.  This does not do a 'deep' copy of the
     * elements.
     */
    ArrayMultisetType dup()
    {
        auto retval = new ArrayMultisetType(_growSize);
        node n = _head.next;
        while(n !is _head)
        {
            node x;
            if(n.value.length == _growSize)
                x = retval.allocate(n.value.dup);
            else
            {
                auto array = new V[_growSize];
                array.length = n.value.length;
                array[0..$] = n.value[];
                x = retval.allocate(array);
            }
            retval._head.prepend(x);
        }
        retval._count = _count;
        return retval;
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
        auto ms = new ArrayMultiset!(uint);
        ms.add([0U, 1, 2, 3, 4, 5]);
        assert(ms.length == 6);
        ms.remove(1);
        assert(ms.length == 5);
        assert(ms._head.next.value == [0U, 5, 2, 3, 4]);
        foreach(ref dopurge, v; &ms.purge)
            dopurge = (v % 2 == 1);
        assert(ms.length == 3);
        assert(ms._head.next.value == [0U, 4, 2]);
    }
}
