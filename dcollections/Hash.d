/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.Hash;

public import dcollections.Functions;
private import dcollections.Link;
private import dcollections.model.Iterator;
private import dcollections.DefaultAllocator;

/**
 * Default Hash implementation.  This is used in the Hash* containers by
 * default.
 *
 * The implementation consists of a table of linked lists.  The table index
 * that an element goes in is based on the hash code.
 */
struct Hash(V, alias Allocator=DefaultAllocator, bool allowDuplicates=false)
{
    /**
     * alias for this type
     */
    alias Hash!(V, Allocator, allowDuplicates) HashType;

    /**
     * alias for Node
     */
    alias Link!(V).Node Node;

    /**
     * alias for the allocator
     */
    alias Allocator!(Link!(V)) allocator;

    /**
     * The allocator for the hash
     */
    allocator alloc;

    /**
     * the table of buckets
     */
    Node[] table;

    /**
     * count of elements in the table
     */
    uint count;

    /**
     * used to determine when to rehash
     */
    float loadFactor;

    /**
     * used to determine starting table size
     */
    uint startingTableSize;

    static const float defaultLoadFactor = .75;
    static const uint defaultTableSize = 31;

    /**
     * Function used to calculate hashes
     */
    HashFunction!(V) hashFunc;

    static if(!allowDuplicates)
    {
        /**
         * Function used to update values that are determined to be equal
         */
        UpdateFunction!(V) updateFunc;
    }

    /**
     * Used to change one of the parameters of the implementation.
     */
    struct parameters
    {
        /**
         * hash function parameter
         */
        HashFunction!(V) hashFunction;
        static if(!allowDuplicates)
        {
            /**
             * update function parameter
             */
            UpdateFunction!(V) updateFunction;
        }

        /**
         * load factor parameter, this is optional.
         */
        float loadFactor;

        /**
         * initial table size, this is optional.
         */
        uint startingTableSize;
    }

    /**
     * This is like a pointer, used to point to a given element in the hash.
     */
    struct position
    {
        HashType *owner;
        Node ptr;
        int idx;

        /**
         * Returns the position that comes after p.
         */
        position next()
        {
            position p = *this;
            auto table = owner.table;

            if(p.ptr !is null)
            {
                if(p.ptr.next is table[p.idx])
                    //
                    // special case, at the end of a bucket, go to the next
                    // bucket.
                    //
                    p.ptr = null;
                else
                {
                    //
                    // still in the bucket
                    //
                    p.ptr = p.ptr.next;
                    return p;
                }
            }

            //
            // iterated past the bucket, go to the next valid bucket
            //
            while(p.idx < cast(int)table.length && p.ptr is null)
            {
                if(++p.idx < table.length)
                    p.ptr = table[p.idx];
                else
                    p.ptr = null;
            }
            return p;
        }

        /**
         * Returns the position that comes before p.
         */
        position prev()
        {
            position p = *this;
            auto table = owner.table;
            if(p.ptr !is null)
            {
                if(p.ptr is table[p.idx])
                    p.ptr = null;
                else
                {
                    p.ptr = p.ptr.prev;
                    return p;
                }
            }

            while(p.idx > 0 && p.ptr is null)
                p.ptr = table[--p.idx];
            if(p.ptr)
                //
                // go to the end of the new bucket
                //
                p.ptr = p.ptr.prev;
            return p;
        }
    }

    /**
     * Add a value to the hash.  Returns true if the value was not present,
     * false if it was updated.
     */
    bool add(V v)
    {
        if(table is null)
            resize(startingTableSize);

        auto h = hashFunc(v) % table.length;
        Node tail = table[h];
        if(tail is null)
        {
            //
            // no node yet, add the new node here
            //
            tail = table[h] = allocate(v);
            Node.attach(tail, tail);
            count++;
            return true;
        }
        else
        {
            static if(!allowDuplicates)
            {
                Node elem = findInBucket(tail, v, tail);
                if(elem is null)
                {
                    count++;
                    tail.prepend(allocate(v));
                    // not single element, need to check load factor
                    checkLoadFactor();
                    return true;
                }
                else
                {
                    //
                    // found the node, set the value instead
                    //
                    updateFunc(elem.value, v);
                    return false;
                }
            }
            else
            {
                //
                // always add, even if the node already exists.
                //
                count++;
                tail.prepend(allocate(v));
                // not single element, need to check load factor
                checkLoadFactor();
                return true;
            }
        }
    }

    /**
     * Resize the hash table to the given capacity.  Normally only called
     * privately.
     */
    void resize(uint capacity)
    {
        if(capacity > table.length)
        {
            auto newTable = new Node[capacity];

            foreach(head; table)
            {
                if(head)
                {
                    //
                    // make the last node point to null, to mark the end of
                    // the bucket
                    //
                    Node.attach(head.prev, null);
                    for(Node cur = head, next = head.next; cur !is null;
                            cur = next)
                    {
                        next = cur.next;
                        auto h = hashFunc(cur.value) % newTable.length;
                        Node newHead = newTable[h];
                        if(newHead is null)
                        {
                            newTable[h] = cur;
                            Node.attach(cur, cur);
                        }
                        else
                            newHead.prepend(cur);
                    }
                }
            }
            delete table;
            table = newTable;
        }
    }

    /**
     * Check to see whether the load factor dictates a resize is in order.
     */
    void checkLoadFactor()
    {
        if(table !is null)
        {
            float fc = cast(float) count;
            float ft = table.length;

            if(fc / ft > loadFactor)
                resize(2 * cast(uint)(fc / loadFactor) + 1);
        }
    }

    /**
     * Returns a position that points to the first element in the hash.
     */
    position begin()
    {
        if(count == 0)
            return end;
        position result;
        result.ptr = null;
        result.owner = this;
        result.idx = -1;
        //
        // this finds the first valid node
        //
        return result.next;
    }

    /**
     * Returns a position that points past the last element of the hash.
     */
    position end()
    {
        position result;
        result.idx = table.length;
        result.owner = this;
        return result;
    }

    // private function used to implement common pieces
    private Node findInBucket(Node bucket, V v, Node startFrom)
    in
    {
        assert(bucket !is null);
    }
    body
    {
        if(startFrom.value == v)
            return startFrom;
        Node n;
        for(n = startFrom.next; n !is bucket && n.value != v; n = n.next)
        {
        }
        return (n is bucket ? null : n);
    }

    /**
     * Find the first instance of a value
     */
    position find(V v)
    {
        if(count == 0)
            return end;
        auto h = hashFunc(v) % table.length;
        // if bucket is empty, or doesn't contain v, return end
        Node ptr;
        if(table[h] is null || (ptr = findInBucket(table[h], v, table[h])) is null)
            return end;
        position p;
        p.owner = this;
        p.idx = h;
        p.ptr = ptr;
        return p;
    }

    /**
     * Remove a given position from the hash.
     */
    position remove(position pos)
    {
        position retval = pos.next;
        if(pos.ptr is table[pos.idx])
        {
            if(pos.ptr.next is pos.ptr)
                table[pos.idx] = null;
            else
                table[pos.idx] = pos.ptr.next;
        }
        pos.ptr.unlink;
        static if(allocator.freeNeeded)
            alloc.free(pos.ptr);
        count--;
        return retval;
    }

    /**
     * Remove all values from the hash
     */
    void clear()
    {
        static if(allocator.freeNeeded)
            alloc.freeAll();
        delete table;
        table = null;
        count = 0;
    }

    /**
     * initialize the hash with the given parameters.  Like a constructor.
     */
    void setup(parameters p)
    {
        //
        // these parameters are always set
        //
        hashFunc = p.hashFunction;
        static if(!allowDuplicates)
        {
            updateFunc = p.updateFunction;
        }

        if(p.loadFactor != p.loadFactor)
            loadFactor = defaultLoadFactor;
        if(p.startingTableSize != 0)
            startingTableSize = p.startingTableSize;
        else
            startingTableSize = defaultTableSize;
    }

    /**
     * keep only elements that appear in subset
     *
     * returns the number of elements removed
     */
    uint intersect(Iterator!(V) subset)
    {
        if(count == 0)
            return 0;
        //
        // start out removing all nodes, then filter out ones that are in the
        // set.
        //
        uint result = count;
        auto tmp = new Node[table.length];

        foreach(ref v; subset)
        {
            position p = find(v);
            if(p.idx != table.length)
            {
                //
                // found the node in the current table, add it to the new
                // table.
                //
                Node head = tmp[p.idx];
                if(head is null)
                {
                    tmp[p.idx] = p.ptr.unlink;
                    Node.attach(p.ptr, p.ptr);
                }
                else
                    head.prepend(p.ptr.unlink);
                result--;
            }
        }

        static if(allocator.freeNeeded)
        {
            //
            // now, we must free all the unused nodes
            //
            foreach(head; table)
            {
                if(head !is null)
                {
                    //
                    // since we will free head, mark the end of the list with
                    // a null pointer
                    //
                    Node.attach(head.prev, null);
                    while(head !is null)
                    {
                        auto newhead = head.next;
                        alloc.free(head);
                        head = newhead;
                    }
                }
            }
        }
        table = tmp;
        count -= result;
        return result;
    }

    static if(allowDuplicates)
    {
        // private function to do the dirty work of countAll and removeAll
        private uint _applyAll(V v, bool remove)
        {
            position p = find(v);
            uint result = 0;
            if(p.idx != table.length)
            {
                auto bucket = table[p.idx];
                do
                {
                    if(p.ptr.value == v)
                    {
                        result++;
                        if(remove)
                        {
                            auto orig = p.ptr;
                            p.ptr = p.ptr.next;
                            orig.unlink();
                            static if(allocator.freeNeeded)
                            {
                                alloc.free(orig);
                            }
                            continue;
                        }
                    }

                    p.ptr = p.ptr.next;
                }
                while(p.ptr !is bucket)
            }
            return result;
        }

        /**
         * count the number of times a given value appears in the hash
         */
        uint countAll(V v)
        {
            return _applyAll(v, false);
        }

        /**
         * remove all the instances of v that appear in the hash
         */
        uint removeAll(V v)
        {
            return _applyAll(v, true);
        }

        /**
         * Find a given value in the hash, starting from the given position.
         * If the position is beyond the last instance of v (which can be
         * determined if the position's bucket is beyond the bucket where v
         * should go).
         */
        position find(V v, position startFrom)
        {
            if(count == 0)
                return end;
            auto h = hashFunc(v) % table.length;
            if(startFrom.idx < h)
            {
                // if bucket is empty, return end
                if(table[h] is null)
                    return end;

                // start from the bucket that the value would live in
                startFrom.idx = h;
                startFrom.ptr = table[h];
            }
            else if(startFrom.idx > h)
                // beyond the bucket, return end
                return end;

            if((startFrom.ptr = findInBucket(table[h], v, startFrom.ptr)) !is
                    null)
                return startFrom;
            return end;
        }
    }

    /**
     * copy all the elements from this hash to target.
     */
    void copyTo(ref HashType target)
    {
        //
        // copy all local values
        //
        target = *this;

        //
        // reallocate all the nodes in the table
        //
        target.table = new Node[table.length];
        foreach(i, n; table)
        {
            if(n !is null)
                target.table[i] = n.dup(&target.allocate);
        }
    }

    Node allocate()
    {
        return alloc.allocate();
    }

    Node allocate(V v)
    {
        auto result = allocate();
        result.value = v;
        return result;
    }
}

/**
 * used to define a Hash that takes duplicates
 */
template HashDup(V, alias Allocator=DefaultAllocator)
{
    alias Hash!(V, Allocator, true) HashDup;
}
