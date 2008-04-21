/*********************************************************
   Copyright (C) 2008 by Steven Schveighoffer.
              All rights reserved

   Permission is hereby granted, free of charge, to any person obtaining a
   copy of this software and associated documentation files (the "Software"),
   to deal in the Software without restriction, including without limitation
   the rights to use, copy, modify, merge, publish, distribute, sublicense,
   and/or sell copies of the Software, and to permit persons to whom the
   Software is furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
   DEALINGS IN THE SOFTWARE.

**********************************************************/
module dcollections.Link;

/**
 * Linked-list node that is used in various collection classes.
 */
class Link(V)
{
    /**
     * convenience alias
     */
    alias Link!(V) Node;
    private Node _next;
    private Node _prev;

    /**
     * the value that is represented by this link node.
     */
    V value;

    /**
     * default constructor.
     */
    this()
    {
    }

    /**
     * construct a link with the given value.
     */
    this(V v)
    {
        this.value = v;
    }

    /**
     * insert the given node between this node and prev.  This updates all
     * pointers in this, n, and prev.
     *
     * returns this to allow for chaining.
     */
    Node prepend(Node n)
    {
        attach(_prev, n);
        attach(n, this);
        return this;
    }

    /**
     * insert the given node between this node and next.  This updates all
     * pointers in this, n, and next.
     *
     * returns this to allow for chaining.
     */
    Node append(Node n)
    {
        attach(n, _next);
        attach(this, n);
        return this;
    }

    /**
     * remove this node from the list.  If prev or next is non-null, their
     * pointers are updated.
     *
     * returns this to allow for chaining.
     */
    Node unlink()
    {
        attach(_prev, _next);
        _next = _prev = null;
        return this;
    }

    /**
     * return the next node in the sequence.
     */
    Node next()
    {
        return _next;
    }

    /**
     * return the previous node in the sequence.
     */
    Node prev()
    {
        return _prev;
    }

    /**
     * link two nodes together.
     */
    static void attach(Node first, Node second)
    {
        if(first)
            first._next = second;
        if(second)
            second._prev = first;
    }

    /**
     * count how many nodes until endNode.
     */
    uint count(Node endNode = null)
    {
        Node x = this;
        uint c = 0;
        while(x !is endNode)
        {
            x = x._next;
            c++;
        }
        return c;
    }
}

/**
 * This struct uses a Link(V) to keep track of a link-list of values.
 *
 * The implementation uses a dummy link node to be the head and tail of the
 * list.  Basically, the list is circular, with the dummy node marking the
 * end/beginning.
 */
struct LinkHead(V)
{
    /**
     * Convenience alias
     */
    alias Link!(V) node;

    /**
     * The node that denotes the end of the list
     */
    node end; // not a valid node

    /**
     * The number of nodes in the list
     */
    uint count;

    /**
     * we don't use parameters, so alias it to int.
     */
    alias int parameters;

    /**
     * Get the first valid node in the list
     */
    node begin()
    {
        return end.next;
    }

    /**
     * Initialize the list
     */
    setup(parameters p)
    {
        end = new node;
        node.attach(end, end);
    }

    /**
     * Remove a node from the list, returning the next node in the list, or
     * end if the node was the last one in the list. O(1) operation.
     */
    node remove(node n)
    {
        count--;
        node retval = n.next;
        n.unlink;
        return retval;
    }

    /**
     * Remove all the nodes from first to last.  This is an O(n) operation.
     */
    node remove(node first, node last)
    {
        count -= first.count(last);
        node.attach(first.prev, last);
        return last;
    }

    /**
     * Insert the given value before the given node.  Use insert(end, v) to
     * add to the end of the list, or to an empty list. O(1) operation.
     */
    node insert(node before, V v)
    {
        count++;
        return before.prepend(new node(v)).prev;
    }

    /**
     * Remove all nodes from the list
     */
    void clear()
    {
        Node.attach(end, end);
        count = 0;
    }
}
