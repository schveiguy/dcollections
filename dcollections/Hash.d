/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.Hash;

public import dcollections.Functions;
private import dcollections.Link;

/**
 * Default Hash implementation.  This is used in the Hash* containers by
 * default.
 *
 * The implementation consists of a table of linked lists.  The table index
 * that an element goes in is based on the hash code.
 */
struct Hash(V, bool allowDuplicates=false)
{
    /**
     * alias for Node
     */
    alias Link!(V) Node;

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
    }

    /**
     * This is like a pointer, used to point to a given element in the hash.
     */
    struct position
    {
        Hash!(V, allowDuplicates) *owner;
        Node ptr;
        int idx;

        /**
         * Returns the position that comes after p.
         */
        position next()
        {
            position p = *this;
            auto table = owner.table;
            while(p.idx < table.length && (p.ptr is null || p.ptr.next is table[p.idx]))
            {
                if(++p.idx < table.length)
                    p.ptr = table[p.idx];
                else
                    p.ptr = null;
            }
            if(p.ptr)
                p.ptr = p.ptr.next;
            return p;
        }

        /**
         * Returns the position that comes before p.
         */
        position prev()
        {
            position p = *this;
            auto table = owner.table;
            while(p.idx >= 0 && (p.ptr is null || p.ptr.prev is table[p.idx]))
            {
                if(--p.idx < 0)
                    p.ptr = table[p.idx];
                else
                    p.ptr = null;
            }
            if(p.ptr)
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
            resize(defaultTableSize);

        auto h = hashFunc(v) % table.length;
        Node tail = table[h];
        Node elem;
        if(tail is null)
        {
            //
            // initialize the table tail node
            //
            tail = table[h] = new Node();
            Node.attach(tail, tail);
            elem = tail;
        }
        else
        {
            static if(!allowDuplicates)
            {
                elem = findInBucket(tail, v);
            }
        }

        static if(allowDuplicates)
        {
            count++;
            tail.prepend(new Node(v));
            if(tail.prev !is tail.next)
            {
                // not single element, need to check load factor
                checkLoadFactor();
            }
            return true;
        }
        else
        {
            if(elem is tail)
            {
                count++;
                tail.prepend(new Node(v));
                if(tail.prev !is tail.next)
                {
                    // not single element, need to check load factor
                    checkLoadFactor();
                }
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
                    for(Node cur = head.next; cur !is head;)
                    {
                        Node next = cur.next;
                        auto h = hashFunc(cur.value) % newTable.length;
                        Node newHead = newTable[h];
                        if(newHead is null)
                        {
                            newTable[h] = newHead = new Node;
                            Node.attach(newHead, newHead);
                        }
                        newHead.prepend(cur);
                        cur = next;
                    }
                }
            }
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
        position result;
        result.ptr = table[0];
        result.owner = this;
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
    private Node findInBucket(Node bucket, V v)
    in
    {
        assert(bucket !is null);
    }
    body
    {
        Node n;
        for(n = bucket.next; n !is bucket && n.value != v; n = n.next)
        {
        }
        return n;
    }

    /**
     * Find a given value in the hash.
     */
    position find(V v)
    {
        auto h = hashFunc(v) % table.length;
        if(table[h])
        {
            position p;
            p.idx = h;
            p.owner = this;
            if((p.ptr = findInBucket(table[h], v)) !is table[h])
                return p;
        }
        return end;
    }

    /**
     * Remove a given position from the hash.
     */
    position remove(position pos)
    {
        position retval = pos.next;
        pos.ptr.unlink;
        count--;
        return retval;
    }

    /**
     * Remove all values from the hash
     */
    void clear()
    {
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
                while(p.ptr !is bucket)
                {
                    if(p.ptr.value == v)
                    {
                        result++;
                        if(remove)
                        {
                            auto orig = p.ptr;
                            p.ptr = p.ptr.next;
                            orig.unlink();
                            continue;
                        }
                    }

                    p.ptr = p.ptr.next;
                }
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
    }
}

/**
 * used to define a Hash that takes duplicates
 */
template HashDup(V)
{
    alias Hash!(V, true) HashDup;
}
