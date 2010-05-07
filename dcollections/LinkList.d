/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.LinkList;

public import dcollections.model.List;
private import dcollections.Link;
private import dcollections.DefaultFunctions;

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
 * parameters -> data type that is passed to setup to help set up the Node.
 * There are no specific requirements for this type.
 *
 * Node -> data type that represents a Node in the list.  This should be a
 * reference type.  Each Node must define the following members:
 *   V value -> the value held at this Node.  Cannot be a property.
 *   Node prev -> (get only) the previous Node in the list
 *   Node next -> (get only) the next Node in the list
 *
 * Node end -> (get only) An invalid Node that points just past the last valid
 * Node.  end.prev should be the last valid Node.  end.next is undefined.
 *
 * Node begin -> (get only) The first valid Node.  begin.prev is undefined.
 *
 * uint count -> (get only)  The number of nodes in the list.  This can be
 * calculated in O(n) time to allow for more efficient removal of multiple
 * nodes.
 *
 * void setup(parameters p) -> set up the list.  This is like a constructor.
 *
 * Node remove(Node n) -> removes the given Node from the list.  Returns the
 * next Node in the list.
 *
 * Node remove(Node first, Node last) -> removes the nodes from first to last,
 * not including last.  Returns last.  This can run in O(n) time if count is
 * O(1), or O(1) time if count is O(n).
 *
 * Node insert(Node before, V v) -> add a new Node before the Node 'before',
 * return a pointer to the new Node.
 *
 * void clear() -> remove all nodes from the list.
 * 
 * void sort(CompareFunction!(V) comp) -> sort the list according to the
 * compare function
 *
 */
class LinkList(V, alias ImplTemp = LinkHead) : List!(V)
{
    /**
     * convenience alias
     */
    alias ImplTemp!(V) Impl;

    private Impl _link;

    /**
     * A cursor for link list
     */
    struct cursor
    {
        private Impl.Node ptr;
        private bool _empty;

        // needed to implement belongs
        private LinkList owner;

        /**
         * get the value pointed to by this cursor
         */
        @property V front()
        {
            assert(!_empty, "Attempting to read the value of an empty cursor of " ~ LinkList.stringof);
            return ptr.value;
        }

        /**
         * set the value pointed to by this cursor
         */
        @property V front(V v)
        {
            assert(!_empty, "Attempting to write the value of an empty cursor of " ~ LinkList.stringof);
            return (ptr.value = v);
        }

        /**
         * return true if the range is empty
         */
        @property bool empty()
        {
            return _empty;
        }

        /**
         * Move to the next element.
         */
        void popFront()
        {
            assert(!_empty, "Attempting to popFront() an empty cursor of " ~ LinkList.stringof);
            _empty = true;
            ptr = ptr.next;
        }

        /**
         * compare two cursors for equality.  Note that only the position of
         * the cursor is checked, whether it's empty or not is not checked.
         */
        bool opEquals(ref const cursor it) const
        {
            return ptr is it.ptr;
        }

        /*
         * TODO: uncomment this when compiler is sane!
         * compare two cursors for equality.  Note that only the position of
         * the cursor is checked, whether it's empty or not is not checked.
         */
        /*
        bool opEquals(const cursor it) const
        {
            return ptr is it.ptr;
        }*/
    }

    /**
     * A cursor for link list
     */
    struct range
    {
        private Impl.Node _begin;
        private Impl.Node _end;

        // needed to implement belongs
        private LinkList owner;

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
            c.owner = owner;
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
            c.owner = owner;
            c._empty = true;
            return c;
        }

        /**
         * Get the first value in the range
         */
        @property V front()
        {
            assert(!empty, "Attempting to read front of an empty range of " ~ LinkList.stringof);
            return _begin.value;
        }

        /**
         * Write the first value in the range.
         */
        @property V front(V v)
        {
            assert(!empty, "Attempting to write front of an empty range of " ~ LinkList.stringof);
            _begin.value = v;
            return v;
        }

        /**
         * Get the last value in the range
         */
        @property V back()
        {
            assert(!empty, "Attempting to read front of an empty range of " ~ LinkList.stringof);
            return _end.prev.value;
        }

        /**
         * Write the last value in the range.
         */
        @property V back(V v)
        {
            assert(!empty, "Attempting to write front of an empty range of " ~ LinkList.stringof);
            _end.prev.value = v;
            return v;
        }

        /**
         * Move the front of the range ahead one element
         */
        void popFront()
        {
            assert(!empty, "Attempting to popFront() an empty range of " ~ LinkList.stringof);
            _begin = _begin.next;
        }

        /**
         * Move the back of the range to the previous element
         */
        void popBack()
        {
            assert(!empty, "Attempting to popBack() an empty range of " ~ LinkList.stringof);
            _end = _end.prev;
        }
    }

    /**
     * Determine if a cursor belongs to the container
     */
    bool belongs(cursor c)
    {
        return c.owner is this;
    }

    /**
     * Determine if a range belongs to the container
     */
    bool belongs(range r)
    {
        return r.owner is this;
    }

    /**
     * Constructor
     */
    this()
    {
        _link.setup();
    }

    //
    // private constructor for dup
    //
    private this(ref Impl dupFrom, bool copyNodes)
    {
        _link.setup();
        dupFrom.copyTo(_link, copyNodes);
    }

    /**
     * Clear the collection of all elements
     */
    LinkList clear()
    {
        _link.clear();
        return this;
    }

    /**
     * returns number of elements in the collection
     */
    @property uint length() const
    {
        return _link.count;
    }

    /**
     * returns a cursor to the first element in the collection.
     */
    @property cursor begin()
    {
        cursor it;
        it.owner = this;
        it.ptr = _link.begin;
        it._empty = (_link.count == 0);
        return it;
    }

    /**
     * returns a cursor that points just past the last element in the
     * collection.
     */
    @property cursor end()
    {
        cursor it;
        it.owner = this;
        it.ptr = _link.end;
        it._empty = true;
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
        assert(belongs(it), "Attempting to remove an unowned cursor of type " ~ LinkList.stringof);
        if(!it.empty)
            it.ptr = _link.remove(it.ptr);
        it._empty = (it.ptr == _link.end);
        return it;
    }

    /**
     * remove the elements pointed at by the given range, returning
     * a cursor that points to the element just after the range removed.
     *
     * Runs in O(n) time where n is the number of elements in the range.
     */
    cursor remove(range r)
    {
        assert(belongs(r), "Attempting to remove an unowned range of type " ~ LinkList.stringof);
        cursor c;
        c.ptr = _link.remove(r._begin, r._end);
        c.owner = this;
        c._empty = (c.ptr is _link.end);
        return c;
    }

    range opSlice()
    {
        range result;
        result.owner = this;
        result._begin = _link.begin;
        result._end = _link.end;
        return result;
    }

    range opSlice(cursor b, cursor e)
    {
        // TODO: fix this when compiler is sane!
        //if((b == begin && belongs(e)) || (e == end && belongs(b)))
        if((begin == b && belongs(e)) || (end == e && belongs(b)))
        {
            range result;
            result.owner = this;
            result._begin = b.ptr;
            result._end = e.ptr;
            return result;
        }
        throw new Exception("invalid slice parameters to " ~ LinkList.stringof);
    }

    /**
     * iterate over the collection's values
     */
    int opApply(scope int delegate(ref V value) dg)
    {
        int retval = 0;
        auto last = _link.end;
        for(auto i = _link.begin; i != last; i = i.next)
            if((retval = dg(i.value)) != 0)
                break;
        return retval;
    }

    /**
     * Iterate over the collections values, specifying which ones should be
     * removed
     *
     * Use like this:
     *
     * -----------
     * // remove all odd values
     * foreach(ref doPurge, v; &list.purge)
     * {
     *   doPurge = ((v & 1) == 1);
     * }
     * -----------
     */
    final int purge(scope int delegate(ref bool doRemove, ref V value) dg)
    {
        auto i = _link.begin;
        auto last = _link.end;
        int dgret = 0;
        bool doRemove;

        while(i != last && i !is _link.end)
        {
            doRemove = false;
            if((dgret = dg(doRemove, i.value)) != 0)
                break;
            if(doRemove)
                i = _link.remove(i);
            else
                i = i.next;
        }
        return dgret;
    }

    /**
     * Adds an element to the list.  Returns true if the element was not
     * already present.
     *
     * Runs in O(1) time.
     */
    LinkList add(V v)
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
    LinkList add(V v, out bool wasAdded)
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
    LinkList add(Iterator!(V) coll)
    {
        if(coll is this)
            throw new Exception("Attempting to self concatenate " ~ LinkList.stringof);
        foreach(v; coll)
            add(v);
        return this;
    }

    /**
     * Adds all the values from the given iterator into the list.
     *
     * Returns the number of elements added.
     */
    LinkList add(Iterator!(V) coll, out uint numAdded)
    {
        if(coll is this)
            throw new Exception("Attempting to self concatenate " ~ LinkList.stringof);
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
    LinkList add(V[] array)
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
    LinkList add(V[] array, out uint numAdded)
    {
        foreach(v; array)
            add(v);
        numAdded = array.length;
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
        assert(belongs(it), "Attempting to insert a value using an invalid cursor of " ~ LinkList.stringof);
        it.ptr = _link.insert(it.ptr, v);
        it._empty = false;
        return it;
    }

    /**
     * Insert elements from an iterator.  Returns the range just inserted.
     */
    range insert(cursor it, Iterator!V r)
    {
        assert(belongs(it), "Attempting to insert range using invalid cursor for type " ~ LinkList.stringof);
        // ensure we are not inserting ourselves
        // Although this kinda sucks that we can't do this, allowing it
        // means a possible infinite loop.
        if(this is r)
        {
            throw new Exception("Attempting to self insert into " ~ LinkList.stringof);
        }
        range result;
        result.owner = this;
        result._end = it.ptr;
        foreach(v; r)
            result._begin = _link.insert(result._end, v);
        return result;
    }

    
    /**
     * Insert a range of elements.  Returns the range just inserted.
     *
     * TODO: this should just be called insert
     */
    range insertRange(R)(cursor it, R r) if (isInputRange!R && is(ElementType!R == V))
    {
        assert(belongs(it), "Attempting to insert range using invalid cursor for type " ~ LinkList);
        static if(is(R == range))
        {
            // ensure we are not inserting a range from our own elements.
            // Although this kinda sucks that we can't do this, allowing it
            // means a possible infinite loop.
            if(belongs(r))
                throw new Exception("Attempting to self insert range into " ~ LinkList);
        }
        range result;
        result.owner = this;
        result._end = it.ptr;
        foreach(v; r)
            result._begin = _link.insert(result._end, v);
        return result;
    }

    /**
     * return the last element in the list.  Undefined if the list is empty.
     *
     * TODO: should be inout
     */
    @property V back()
    {
        assert(length != 0, "Attempting to get last element of empty " ~ LinkList.stringof);
        return _link.end.prev.value;
    }
    
    /**
     * return the first element in the list.  Undefined if the list is empty.
     * TODO: should be inout
     */
    @property V front()
    {
        assert(length != 0, "Attempting to get first element of empty " ~ LinkList.stringof);
        return _link.begin.value;
    }

    /**
     * remove the first element in the list, and return its value.
     *
     * Do not call this on an empty list.
     */
    V takeFront()
    {
        assert(length != 0, "Attempting to take first element of empty " ~ LinkList.stringof);
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
        assert(length != 0, "Attempting to take last element of empty " ~ LinkList.stringof);
        auto retval = back;
        _link.remove(_link.end.prev);
        return retval;
    }

    /**
     * Take the element at the end of the list, and return its value.
     */
    V take()
    {
        return takeBack();
    }

    /**
     * Create a new list with this and the rhs concatenated together
     */
    LinkList concat(List!(V) rhs)
    {
        return dup().add(rhs);
    }

    /**
     * Create a new list with this and the array concatenated together
     */
    LinkList concat(V[] array)
    {
        return dup().add(array);
    }

    /**
     * Create a new list with the array and this list concatenated together.
     */
    LinkList concat_r(V[] array)
    {
        auto result = new LinkList(_link, false);
        return result.add(array).add(this);
    }

    /**
     * duplicate the list
     */
    LinkList dup()
    {
        return new LinkList(_link, true);
    }

    /**
     * Compare this list with another list.  Returns true if both lists have
     * the same length and all the elements are the same.
     *
     * If o is null or not a List, return 0.
     */
    bool opEquals(Object o)
    {
        if(o !is null)
        {
            auto li = cast(List!(V))o;
            if(li !is null && li.length == length)
            {
                auto c = this[];
                foreach(elem; li)
                {
                    if(elem != c.front)
                        return 0;
                    c.popFront();
                }
                return 1;
            }
        }
        return 0;
    }

    /**
     * Sort the linked list according to the given compare function.
     *
     * Runs in O(n lg(n)) time
     *
     * Returns this after sorting
     */
    LinkList sort(scope int delegate(ref V, ref V) comp)
    {
        _link.sort(comp);
        return this;
    }

    /**
     * Sort the linked list according to the given compare function.
     *
     * Runs in O(n lg(n)) time
     *
     * Returns this after sorting
     */
    LinkList sort(scope int function(ref V, ref V) comp)
    {
        _link.sort(comp);
        return this;
    }

    /**
     * Sort the linked list according to the default compare function for V.
     *
     * Runs in O(n lg(n)) time
     *
     * Returns this
     */
    LinkList sort()
    {
        return sort(&DefaultCompare!(V));
    }

    /**
     * Sort the linked list according to the given compare functor.  This is
     * a templatized version, and so can be used with functors, and might be
     * inlined.
     *
     * TODO: this should be called sort
     */
    LinkList sortX(Comparator)(Comparator comp)
    {
        _link.sort(comp);
        return this;
    }
}

version(unittest) import std.algorithm;
unittest
{

    auto ll = new LinkList!(uint);
    List!(uint) l = ll;
    bool contains(uint x)
    {
        foreach(y; l)
            if(y == x)
                return true;
        return false;
    }

    l.add([0U, 1, 2, 3, 4, 5]);
    assert(l.length == 6);
    assert(contains(5));
    foreach(ref doPurge, i; &l.purge)
        doPurge = (i % 2 == 1);
    assert(l.length == 3);
    assert(!contains(5));
}
