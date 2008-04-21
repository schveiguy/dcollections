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
                ptr = ptr.next();
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

    /**
     * Clear the collection of all elements
     */
    Collection!(V) clear()
    {
        _link.clear();
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
        return _link.count;
    }

    /**
     * returns a cursor to the first element in the collection.
     */
    final cursor begin()
    {
        cursor it;
        it.ptr = _link.begin;
        return it;
    }

    /**
     * returns a cursor that points just past the last element in the
     * collection.
     */
    final cursor end()
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
    bool remove(V v)
    {
        auto it = find(v);
        if(it == end)
            return false;
        remove(it);
        return true;
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
     * Adds an element to the set.  Returns true if the element was not
     * already present.
     *
     * Runs in O(1) time.
     */
    bool add(V v)
    {
        _link.insert(_link.end, v);
        return true;
    }

    /**
     * Adds all the values from the given iterator into the list.
     *
     * Returns the number of elements added.
     */
    uint addAll(Iterator!(V) coll)
    {
        uint retval = 0;
        foreach(v; coll)
        {
            add(v);
            retval++;
        }
        return retval;
    }

    /**
     * Adds all the values from the given array into the list.
     *
     * Returns the number of elements added.
     */
    uint addAll(V[] array)
    {
        foreach(v; array)
            add(v);
        return array.length;
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
    uint removeAll(V v)
    {
        uint result;
        foreach(ref dp, x; purger)
        {
            if(x == v)
            {
                dp = true;
                result++;
            }
        }
        return result;
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
}
