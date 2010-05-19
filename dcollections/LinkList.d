/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.LinkList;

public import dcollections.model.List;
private import dcollections.Link;
private import dcollections.DefaultFunctions;
private import std.algorithm;
private import std.range;

version(unittest) private import std.traits;

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
    version(unittest) private enum doUnittest = isIntegral!V;
    else private enum doUnittest = false;

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

    static if(doUnittest) unittest
    {
        auto ll = new LinkList;
        ll.add(cast(V[])[1, 2, 3, 4, 5]);
        auto cu = std.algorithm.find(ll[], 3).begin;
        assert(!cu.empty);
        assert(cu.front == 3);
        assert((cu.front = 8)  == 8);
        assert(cu.front == 8);
        assert(ll == cast(V[])[1, 2, 8, 4, 5]);
        cu.popFront();
        assert(cu.empty);
        assert(ll == cast(V[])[1, 2, 8, 4, 5]);
    }


    /**
     * A range for link list
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
            return _begin is _end;
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

    static if(doUnittest) unittest
    {
        auto ll = new LinkList;
        ll.add(cast(V[])[1, 2, 3, 4, 5]);
        auto r = ll[];
        assert(std.algorithm.equal(r, cast(V[])[1, 2, 3, 4, 5]));
        assert(r.front == 1);
        assert(r.back == 5);
        r.popFront();
        r.popBack();
        assert(std.algorithm.equal(r, cast(V[])[2, 3, 4]));
        assert(r.front == 2);
        assert(r.back == 4);

        r.front = 10;
        r.back = 11;
        assert(std.algorithm.equal(r, cast(V[])[10, 3, 11]));
        assert(r.front == 10);
        assert(r.back == 11);

        auto b = r.begin;
        assert(!b.empty);
        assert(b.front == 10);
        auto e = r.end;
        assert(e.empty);

        assert(ll == cast(V[])[1, 10, 3, 11, 5]);
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

    static if(doUnittest) unittest
    {
        auto ll = new LinkList;
        ll.add(cast(V[])[1, 2, 3, 4, 5]);
        auto cu = std.algorithm.find(ll[], 3).begin;
        assert(cu.front == 3);
        assert(ll.belongs(cu));
        auto r = ll[ll.begin..cu];
        assert(ll.belongs(r));

        auto ll2 = ll.dup;
        assert(!ll2.belongs(cu));
        assert(!ll2.belongs(r));
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

    static if(doUnittest) unittest
    {
        auto ll = new LinkList;
        ll.add(cast(V[])[1, 2, 3, 4, 5]);
        assert(ll.length == 5);
        ll.clear();
        assert(ll.length == 0);
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

    static if(doUnittest) unittest
    {
        auto ll = new LinkList;
        ll.add(cast(V[])[1, 2, 3, 4, 5]);
        ll.remove(std.algorithm.find(ll[], 3).begin);
        assert(ll == cast(V[])[1, 2, 4, 5]);
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

    static if(doUnittest) unittest
    {
        auto ll = new LinkList;
        ll.add(cast(V[])[1, 2, 3, 4, 5]);
        auto r = std.algorithm.find(ll[], 3);
        r.popBack();
        ll.remove(r);
        assert(ll == cast(V[])[1, 2, 5]);
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

    static if (doUnittest) unittest
    {
        auto ll = new LinkList;
        ll.add(cast(V[])[1, 2, 3, 4, 5]);
        assert(std.algorithm.equal(ll[], cast(V[])[1, 2, 3, 4, 5]));
        auto cu = std.algorithm.find(ll[], 3).begin;
        assert(std.algorithm.equal(ll[ll.begin..cu], cast(V[])[1, 2]));
        assert(std.algorithm.equal(ll[cu..ll.end], cast(V[])[3, 4, 5]));
        bool exceptioncaught = false;
        try
        {
            ll[cu..cu];
        }
        catch(Exception)
        {
            exceptioncaught = true;
        }
        assert(exceptioncaught);
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

    static if(doUnittest) unittest
    {
        auto ll = new LinkList;
        ll.add(cast(V[])[1, 2, 3, 4, 5]);
        V v = 0;
        foreach(i; ll)
        {
            assert(i == ++v);
        }
        assert(v == ll.length);
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

    static if(doUnittest) unittest
    {
        auto ll = new LinkList;
        ll.add(cast(V[])[0, 1, 2, 3, 4]);
        foreach(ref p, i; &ll.purge)
        {
            p = (i & 1);
        }

        assert(ll == cast(V[])[0, 2, 4]);
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

    static if(doUnittest) unittest
    {
        // add single element
        bool wasAdded = false;
        auto ll = new LinkList;
        ll.add(1);
        ll.add(2, wasAdded);
        assert(ll.length == 2);
        assert(ll == cast(V[])[1, 2]);
        assert(wasAdded);

        // add other collection
        uint numAdded = 0;
        // need to add duplicate, adding self is not allowed.
        ll.add(ll.dup, numAdded);
        ll.add(ll.dup);
        bool caughtexception = false;
        try
        {
            ll.add(ll);
        }
        catch(Exception)
        {
            caughtexception = true;
        }
        assert(caughtexception);

        assert(ll == cast(V[])[1, 2, 1, 2, 1, 2, 1, 2]);
        assert(numAdded == 2);

        // add array
        ll.clear();
        ll.add(cast(V[])[1, 2, 3, 4, 5]);
        ll.add(cast(V[])[1, 2, 3, 4, 5], numAdded);
        assert(ll == cast(V[])[1, 2, 3, 4, 5, 1, 2, 3, 4, 5]);
        assert(numAdded == 5);
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
        result._begin = it.ptr;
        bool first = true;
        foreach(v; r)
        {
            auto tmp = _link.insert(result._end, v);
            if(first)
            {
                first = false;
                result._begin = tmp;
            }
        }
        return result;
    }

    
    /**
     * Insert a range of elements.  Returns the range just inserted.
     *
     * TODO: this should just be called insert
     */
    range insertRange(R)(cursor it, R r) if (isInputRange!R && is(ElementType!R : V))
    {
        assert(belongs(it), "Attempting to insert range using invalid cursor for type " ~ LinkList.stringof);
        static if(is(R == range))
        {
            // ensure we are not inserting a range from our own elements.
            // Although this kinda sucks that we can't do this, allowing it
            // means a possible infinite loop.
            if(belongs(r))
                throw new Exception("Attempting to self insert range into " ~ LinkList.stringof);
        }
        range result;
        result.owner = this;
        result._begin = result._end = it.ptr;
        if(!r.empty)
        {
            result._begin = _link.insert(result._end, r.front);
            r.popFront();
        }
        foreach(v; r)
        {
            _link.insert(result._end, v);
        }
        return result;
    }

    static if(doUnittest) unittest
    {
        // insert single element
        auto ll = new LinkList;
        ll.add(cast(V[])[1, 2, 3, 4, 5]);
        auto cu = std.algorithm.find(ll[], 3).begin;
        auto cu2 = ll.insert(cu, 7);
        assert(ll == cast(V[])[1, 2, 7, 3, 4, 5]);
        assert(cu.front == 3);
        assert(cu2.front == 7);
        assert(ll.belongs(cu2));

        // insert another iterator
        auto r = ll.insert(cu, ll.dup);
        assert(std.algorithm.equal(r, cast(V[])[1, 2, 7, 3, 4, 5]));
        assert(ll.belongs(r));
        assert(ll == cast(V[])[1, 2, 7, 1, 2, 7, 3, 4, 5, 3, 4, 5]);

        // insert a range
        auto r2 = ll.insertRange(cu2, cast(V[])[8, 9, 10]);
        assert(std.algorithm.equal(r2, cast(V[])[8, 9, 10]));
        assert(ll.belongs(r2));
        assert(ll == cast(V[])[1, 2, 8, 9, 10, 7, 1, 2, 7, 3, 4, 5, 3, 4, 5]);

        // test self insertion
        bool caughtexception = false;
        try
        {
            ll.insert(ll.begin, ll);
        }
        catch(Exception)
        {
            caughtexception = true;
        }
        assert(caughtexception);
        caughtexception = false;
        try
        {
            ll.insertRange(ll.begin, ll[]);
        }
        catch(Exception)
        {
            caughtexception = true;
        }
        assert(caughtexception);
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

    static if(doUnittest) unittest
    {
        auto ll = new LinkList;
        ll.add(cast(V[])[1, 2, 3, 4, 5]);
        assert(ll.takeBack() == 5);
        assert(ll == cast(V[])[1, 2, 3, 4]);
        assert(ll.takeFront() == 1);
        assert(ll == cast(V[])[2, 3, 4]);
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

    version(testcompiler)
    {
    }
    else
    {
        // workaround for compiler deficiencies
        alias concat opCat;
        alias concat_r opCat_r;
        alias add opCatAssign;
    }

    static if(doUnittest) unittest
    {
        auto ll = new LinkList;
        ll.add(cast(V[])[1, 2, 3, 4, 5]);
        auto ll2 = ll.concat(ll);
        assert(ll2 !is ll);
        assert(ll2 == cast(V[])[1, 2, 3, 4, 5, 1, 2, 3, 4, 5]);
        assert(ll == cast(V[])[1, 2, 3, 4, 5]);

        ll2 = ll.concat(cast(V[])[6, 7, 8, 9, 10]);
        assert(ll2 !is ll);
        assert(ll2 == cast(V[])[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
        assert(ll == cast(V[])[1, 2, 3, 4, 5]);

        ll2 = ll.concat_r(cast(V[])[6, 7, 8, 9, 10]);
        assert(ll2 !is ll);
        assert(ll2 == cast(V[])[6, 7, 8, 9, 10, 1, 2, 3, 4, 5]);
        assert(ll == cast(V[])[1, 2, 3, 4, 5]);

        ll2 = ll ~ ll;
        assert(ll2 !is ll);
        assert(ll2 == cast(V[])[1, 2, 3, 4, 5, 1, 2, 3, 4, 5]);
        assert(ll == cast(V[])[1, 2, 3, 4, 5]);

        ll2 = ll ~ cast(V[])[6, 7, 8, 9, 10];
        assert(ll2 !is ll);
        assert(ll2 == cast(V[])[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
        assert(ll == cast(V[])[1, 2, 3, 4, 5]);

        ll2 = cast(V[])[6, 7, 8, 9, 10] ~ ll;
        assert(ll2 !is ll);
        assert(ll2 == cast(V[])[6, 7, 8, 9, 10, 1, 2, 3, 4, 5]);
        assert(ll == cast(V[])[1, 2, 3, 4, 5]);
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
     * If o is null or not a List, return false.
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
                        return false;
                    c.popFront();
                }
                return true;
            }
        }
        return false;
    }

    static if(doUnittest) unittest
    {
        auto ll = new LinkList;
        ll.add(cast(V[])[1, 2, 3, 4, 5]);
        assert(ll == ll.dup);
    }

    /**
     * Compare this list with an array.  Returns true if both lists have
     * the same length and all the elements are the same.
     */
    bool opEquals(V[] arr)
    {
        if(arr.length == length)
        {
            return std.algorithm.equal(this[], arr);
        }
        return false;
    }

    /**
     * Sort the linked list according to the given compare function.
     *
     * Runs in O(n lg(n)) time
     *
     * Returns this after sorting
     */
    LinkList sort(scope bool delegate(ref V, ref V) less)
    {
        // TODO: fix when bug 3051 is resolved.
        // _link.sort!less();
        mergesort!(less)(_link);
        return this;
    }

    /**
     * Sort the linked list according to the given compare function.
     *
     * Runs in O(n lg(n)) time
     *
     * Returns this after sorting
     */
    LinkList sort(scope bool function(ref V, ref V) less)
    {
        // TODO: fix when bug 3051 is resolved.
        // _link.sort!less();
        mergesort!(less)(_link);
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
        _link.sort!(DefaultLess!V)();
        return this;
    }

    /**
     * Sort the linked list according to the given compare functor.  This is
     * a templatized version, and so can be used with functors, and might be
     * inlined.
     *
     * TODO: this should be called sort
     * TODO: if bug 3051 is resolved, then this can probably be
     * sortX(alias less)()
     * instead.
     */
    LinkList sortX(T)(T less)
    {
        // TODO: fix when bug 3051 is resolved.
        // _link.sort!less();
        mergesort!(less)(_link);
        return this;
    }

    static if(doUnittest) unittest
    {
        auto ll = new LinkList;
        ll.add(cast(V[])[1, 3, 5, 6, 4, 2]);
        ll.sort();
        assert(ll == cast(V[])[1, 2, 3, 4, 5, 6]);
        ll.sort(delegate bool (ref V a, ref V b) { return b < a; });
        assert(ll == cast(V[])[6, 5, 4, 3, 2, 1]);
        ll.sort(function bool (ref V a, ref V b) { if((a ^ b) & 1) return cast(bool)(a & 1); return a < b; });
        assert(ll == cast(V[])[1, 3, 5, 2, 4, 6]);

        struct X
        {
            V pivot;
            // if a and b are on both sides of pivot, sort normally, otherwise,
            // values >= pivot are treated less than values < pivot.
            bool opCall(V a, V b)
            {
                if(a < pivot)
                {
                    if(b < pivot)
                    {
                        return a < b;
                    }
                    return false;
                }
                else if(b >= pivot)
                {
                    return a < b;
                }
                return true;
            }
        }

        X x;
        x.pivot = 4;
        ll.sortX(x);
        assert(ll == cast(V[])[4, 5, 6, 1, 2, 3]);
    }
}

unittest
{
    // declare the Link list types that should be unit tested.
    LinkList!ubyte  ll1;
    LinkList!byte   ll2;
    LinkList!ushort ll3;
    LinkList!short  ll4;
    LinkList!uint   ll5;
    LinkList!int    ll6;
    LinkList!ulong  ll7;
    LinkList!long   ll8;
}
