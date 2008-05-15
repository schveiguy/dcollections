/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.LinkList;

public import dcollections.model.List;
private import dcollections.Link;

/**
 * This class implements the list interface by using Link nodes.  This gives
 * the advantage of O(1) add and removal, but no random access.
 *
 * Adding elements does not affect any cursor.
 *
 * Removing elements does not affect any cursor unless the cursor points
 * to a removed element, in which case it is invalidated.
 *
 * The implementation can be swapped out for another implementation of
 * a doubly linked list.  The implementation must be a struct which uses one
 * template argument V with the following members (unless specified, members
 * can be implemented as properties):
 *
 * parameters -> data type that is passed to setup to help set up the node.
 * There are no specific requirements for this type.
 *
 * node -> data type that represents a node in the list.  This should be a
 * reference type.  Each node must define the following members:
 *   V value -> the value held at this node.  Cannot be a property.
 *   node prev -> (get only) the previous node in the list
 *   node next -> (get only) the next node in the list
 *
 * node end -> (get only) An invalid node that points just past the last valid
 * node.  end.prev should be the last valid node.  end.next is undefined.
 *
 * node begin -> (get only) The first valid node.  begin.prev is undefined.
 *
 * uint count -> (get only)  The number of nodes in the list.  This can be
 * calculated in O(n) time to allow for more efficient removal of multiple
 * nodes.
 *
 * void setup(parameters p) -> set up the list.  This is like a constructor.
 *
 * node remove(node n) -> removes the given node from the list.  Returns the
 * next node in the list.
 *
 * node remove(node first, node last) -> removes the nodes from first to last,
 * not including last.  Returns last.  This can run in O(n) time if count is
 * O(1), or O(1) time if count is O(n).
 *
 * node insert(node before, V v) -> add a new node before the node 'before',
 * return a pointer to the new node.
 *
 * void clear() -> remove all nodes from the list.
 *
 */
class LinkList(V, alias ImplTemp = LinkHead) : List!(V)
{
    /**
     * convenience alias
     */
    alias LinkHead!(V) Impl;

    /**
     * convenience alias
     */
    alias LinkList!(V, ImplTemp) LinkListType;

    private Impl _link;
    private Purger _purger;

    /**
     * A cursor for link list
     */
    struct cursor
    {
        private Impl.node ptr;

        /**
         * get the value pointed to by this cursor
         */
        V value()
        {
            return ptr.value;
        }

        /**
         * set the value pointed to by this cursor
         */
        V value(V v)
        {
            return (ptr.value = v);
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
                ptr = ptr.next();
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
                ptr = ptr.prev();
            return *this;
        }

        /**
         * compare two cursors for equality
         */
        bool opEquals(cursor it)
        {
            return ptr is it.ptr;
        }
    }

    /**
     * Constructor
     */
    this(Impl.parameters p)
    {
        _link.setup(p);
        _purger = new Purger;
    }

    /**
     * Constructor
     */
    this()
    {
        Impl.parameters p;
        this(p);
    }

    //
    // private constructor for dup
    //
    private this(ref Impl dupFrom, bool copyNodes)
    {
      dupFrom.copyTo(_link, copyNodes);
      _purger = new Purger;
    }

    /**
     * Clear the collection of all elements
     */
    LinkListType clear()
    {
        _link.clear();
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
        return _link.count;
    }

    /**
     * returns a cursor to the first element in the collection.
     */
    cursor begin()
    {
        cursor it;
        it.ptr = _link.begin;
        return it;
    }

    /**
     * returns a cursor that points just past the last element in the
     * collection.
     */
    cursor end()
    {
        cursor it;
        it.ptr = _link.end;
        return it;
    }

    /**
     * remove the element pointed at by the given cursor, returning an
     * cursor that points to the next element in the collection.
     *
     * Runs in O(1) time.
     */
    cursor remove(cursor it)
    {
        it.ptr = _link.remove(it.ptr);
        return it;
    }

    /**
     * remove the elements pointed at by the given cursor range, returning
     * a cursor that points to the element that last pointed to.
     *
     * Runs in O(last-first) time.
     */
    cursor remove(cursor first, cursor last)
    {
        last.ptr = _link.remove(first.ptr, last.ptr);
        return last;
    }

    /**
     * Removes the first element that has the value v.  Returns true if the
     * value was present and was removed.
     *
     * Runs in O(n) time.
     */
    LinkListType remove(V v)
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
    LinkListType remove(V v, ref bool wasRemoved)
    {
        auto it = find(v);
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
     * find a given value in the collection starting at a given cursor.
     * This is useful to iterate over all elements that have the same value.
     *
     * Runs in O(n) time.
     */
    cursor find(cursor it, V v)
    {
        return _find(it, end, v);
    }

    /**
     * find an instance of a value in the collection.  Equivalent to
     * find(begin, v);
     *
     * Runs in O(n) time.
     */
    cursor find(V v)
    {
        return _find(begin, end, v);
    }

    private cursor _find(cursor it, cursor last, V v)
    {
        while(it != last && it.value != v)
            it++;
        return it;
    }

    /**
     * Returns true if the given value exists in the collection.
     *
     * Runs in O(n) time.
     */
    bool contains(V v)
    {
        return find(v) != end;
    }

    private int _apply(int delegate(ref bool, ref V) dg, cursor start, cursor last)
    {
        cursor i = start;
        int dgret = 0;
        bool doRemove;

        while(i != last && i.ptr !is _link.end)
        {
            doRemove = false;
            if((dgret = dg(doRemove, i.ptr.value)) != 0)
                break;
            if(doRemove)
                remove(i++);
            else
                i++;
        }
        return dgret;
    }

    private int _apply(int delegate(ref V value) dg, cursor first, cursor last)
    {
        int retval = 0;
        for(cursor i = first; i != last; i++)
            if((retval = dg(i.ptr.value)) != 0)
                break;
        return retval;
    }

    /**
     * iterate over the collection's values
     */
    int opApply(int delegate(ref V value) dg)
    {
        return _apply(dg, begin, end);
    }

    private class Purger : PurgeIterator!(V)
    {
        int opApply(int delegate(ref bool doRemove, ref V value) dg)
        {
            return _apply(dg, begin, end);
        }
    }

    /**
     * returns an object that can be used to purge the collection.
     */
    PurgeIterator!(V) purger()
    {
        return _purger;
    }

    /**
     * Adds an element to the list.  Returns true if the element was not
     * already present.
     *
     * Runs in O(1) time.
     */
    LinkListType add(V v)
    {
        _link.insert(_link.end, v);
        return this;
    }

    /**
     * Adds an element to the list.  Returns true if the element was not
     * already present.
     *
     * Runs in O(1) time.
     */
    LinkListType add(V v, ref bool wasAdded)
    {
        _link.insert(_link.end, v);
        wasAdded = true;
        return this;
    }

    /**
     * Adds all the values from the given iterator into the list.
     *
     * Returns this.
     */
    LinkListType add(Iterator!(V) coll)
    {
        foreach(v; coll)
            add(v);
        return this;
    }

    /**
     * Adds all the values from the given iterator into the list.
     *
     * Returns the number of elements added.
     */
    LinkListType add(Iterator!(V) coll, ref uint numAdded)
    {
        uint origLength = length;
        add(coll);
        numAdded = length - origLength;
        return this;
    }

    /**
     * Adds all the values from the given array into the list.
     *
     * Returns the number of elements added.
     */
    LinkListType add(V[] array)
    {
        foreach(v; array)
            add(v);
        return this;
    }

    /**
     * Adds all the values from the given array into the list.
     *
     * Returns the number of elements added.
     */
    LinkListType add(V[] array, ref uint numAdded)
    {
        foreach(v; array)
            add(v);
        numAdded = array.length;
        return this;
    }

    /**
     * Count the number of occurrences of v
     *
     * Runs in O(n) time.
     */
    uint count(V v)
    {
        uint instances = 0;
        foreach(x; this)
            if(v == x)
                instances++;
        return instances;
    }

    /**
     * Remove all the occurrences of v.  Returns the number of instances that
     * were removed.
     *
     * Runs in O(n) time.
     */
    LinkListType removeAll(V v)
    {
        foreach(ref dp, x; purger)
        {
            dp = cast(bool)(x == v);
        }
        return this;
    }

    /**
     * Remove all the occurrences of v.  Returns the number of instances that
     * were removed.
     *
     * Runs in O(n) time.
     */
    LinkListType removeAll(V v, ref uint numRemoved)
    {
        uint origLength;
        removeAll(v);
        numRemoved = origLength - length;
        return this;
    }

    //
    // handy link-list only functions
    //
    /**
     * insert an element at the given position.  Returns a cursor to the
     * newly inserted element.
     */
    cursor insert(cursor it, V v)
    {
        it.ptr = _link.insert(it.ptr, v);
        return it;
    }

    /**
     * prepend an element to the first element in the list.  Returns an
     * cursor to the newly prepended element.
     */
    cursor prepend(V v)
    {
        return insert(begin, v);
    }

    /**
     * append an element to the last element in the list.  Returns a cursor
     * to the newly appended element.
     */
    cursor append(V v)
    {
        return insert(end, v);
    }

    /**
     * return the last element in the list.  Undefined if the list is empty.
     */
    V back()
    {
        return _link.end.prev.value;
    }
    
    /**
     * return the first element in the list.  Undefined if the list is empty.
     */
    V front()
    {
        return _link.begin.value;
    }

    /**
     * remove the first element in the list, and return its value.
     *
     * Do not call this on an empty list.
     */
    V takeFront()
    {
        auto retval = front;
        _link.remove(_link.begin);
        return retval;
    }

    /**
     * remove the last element in the list, and return its value
     * Do not call this on an empty list.
     */
    V takeBack()
    {
        auto retval = back;
        _link.remove(_link.end.prev);
        return retval;
    }

    /**
     * Create a new list with this and the rhs concatenated together
     */
    LinkListType opCat(List!(V) rhs)
    {
        return dup.add(rhs);
    }

    /**
     * Create a new list with this and the array concatenated together
     */
    LinkListType opCat(V[] array)
    {
        return dup.add(array);
    }

    /**
     * Create a new list with the array and this list concatenated together.
     */
    LinkListType opCat_r(V[] array)
    {
        auto result = new LinkListType(_link, false);
        return result.add(array).add(this);
    }

    /**
     * Append the given list to the end of this list.
     */
    LinkListType opCatAssign(List!(V) rhs)
    {
        return add(rhs);
    }

    /**
     * Append the given array to the end of this list.
     */
    LinkListType opCatAssign(V[] array)
    {
        return add(array);
    }

    /**
     * duplicate the list
     */
    LinkListType dup()
    {
        return new LinkListType(_link, true);
    }

    /**
     * Compare this list with another list.  Returns true if both lists have
     * the same length and all the elements are the same.
     *
     * If o is null or not a List, return 0.
     */
    int opEquals(Object o)
    {
        if(o !is null)
        {
            auto li = cast(List!(V))o;
            if(li !is null && li.length == length)
            {
                auto c = begin;
                foreach(elem; li)
                {
                    if(elem != c++.value)
                        return 0;
                }
                return 1;
            }
        }
        return 0;
    }
}

version(UnitTest)
{
    unittest
    {
        auto ll = new LinkList!(uint);
        List!(uint) l = ll;
        l.add([0U, 1, 2, 3, 4, 5]);
        assert(l.length == 6);
        assert(l.contains(5));
        foreach(ref doPurge, i; l.purger)
            doPurge = (i % 2 == 1);
        assert(l.length == 3);
        assert(!l.contains(5));
    }
}
