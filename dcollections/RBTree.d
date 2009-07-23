/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.RBTree;

private import dcollections.model.Iterator;
private import dcollections.DefaultAllocator;

version(RBDoChecks)
{
    import tango.io.Stdout;
}

/**
 * Implementation for a Red Black node for use in a Red Black Tree (see below)
 *
 * this implementation assumes we have a marker Node that is the parent of the
 * root Node.  This marker Node is not a valid Node, but marks the end of the
 * collection.  The root is the left child of the marker Node, so it is always
 * last in the collection.  The marker Node is passed in to the setColor
 * function, and the Node which has this Node as its parent is assumed to be
 * the root Node.
 *
 * A Red Black tree should have O(lg(n)) insertion, removal, and search time.
 */
struct RBNode(V)
{
    /**
     * Convenience alias
     */
    alias RBNode!(V)* Node;

    private Node _left;
    private Node _right;
    private Node _parent;

    /**
     * The value held by this node
     */
    V value;

    /**
     * Enumeration determining what color the node is.  Null nodes are assumed
     * to be black.
     */
    enum Color : byte
    {
        Red,
        Black
    }

    /**
     * The color of the node.
     */
    Color color;

    /**
     * Get the left child
     */
    Node left()
    {
        return _left;
    }

    /**
     * Get the right child
     */
    Node right()
    {
        return _right;
    }

    /**
     * Get the parent
     */
    Node parent()
    {
        return _parent;
    }

    /**
     * Set the left child.  Also updates the new child's parent node.  This
     * does not update the previous child.
     *
     * Returns newNode
     */
    Node left(Node newNode)
    {
        _left = newNode;
        if(newNode !is null)
            newNode._parent = this;
        return newNode;
    }

    /**
     * Set the right child.  Also updates the new child's parent node.  This
     * does not update the previous child.
     *
     * Returns newNode
     */
    Node right(Node newNode)
    {
        _right = newNode;
        if(newNode !is null)
            newNode._parent = this;
        return newNode;
    }

    // assume _left is not null
    //
    // performs rotate-right operation, where this is T, _right is R, _left is
    // L, _parent is P:
    //
    //      P         P
    //      |   ->    |
    //      T         L
    //     / \       / \
    //    L   R     a   T
    //   / \           / \ 
    //  a   b         b   R 
    //
    /**
     * Rotate right.  This performs the following operations:
     *  - The left child becomes the parent of this node.
     *  - This node becomes the new parent's right child.
     *  - The old right child of the new parent becomes the left child of this
     *    node.
     */
    Node rotateR()
    in
    {
        assert(_left !is null);
    }
    body
    {
        // sets _left._parent also
        if(isLeftNode)
            parent.left = _left;
        else
            parent.right = _left;
        Node tmp = _left._right;

        // sets _parent also
        _left.right = this;

        // sets tmp._parent also
        left = tmp;

        return this;
    }

    // assumes _right is non null
    //
    // performs rotate-left operation, where this is T, _right is R, _left is
    // L, _parent is P:
    //
    //      P           P
    //      |    ->     |
    //      T           R
    //     / \         / \
    //    L   R       T   b
    //       / \     / \ 
    //      a   b   L   a 
    //
    /**
     * Rotate left.  This performs the following operations:
     *  - The right child becomes the parent of this node.
     *  - This node becomes the new parent's left child.
     *  - The old left child of the new parent becomes the right child of this
     *    node.
     */
    Node rotateL()
    in
    {
        assert(_right !is null);
    }
    body
    {
        // sets _right._parent also
        if(isLeftNode)
            parent.left = _right;
        else
            parent.right = _right;
        Node tmp = _right._left;

        // sets _parent also
        _right.left = this;

        // sets tmp._parent also
        right = tmp;
        return this;
    }


    /**
     * Returns true if this node is a left child.
     *
     * Note that this should always return a value because the root has a
     * parent which is the marker node.
     */
    bool isLeftNode()
    in
    {
        assert(_parent !is null);
    }
    body
    {
        return _parent._left is this;
    }

    /**
     * Set the color of the node after it is inserted.  This performs an
     * update to the whole tree, possibly rotating nodes to keep the Red-Black
     * properties correct.  This is an O(lg(n)) operation, where n is the
     * number of nodes in the tree.
     */
    void setColor(Node end)
    {
        // test against the marker node
        if(_parent !is end)
        {
            if(_parent.color == Color.Red)
            {
                Node cur = this;
                while(true)
                {
                    // because root is always black, _parent._parent always exists
                    if(cur._parent.isLeftNode)
                    {
                        // parent is left node, y is 'uncle', could be null
                        Node y = cur._parent._parent._right;
                        if(y !is null && y.color == Color.Red)
                        {
                            cur._parent.color = Color.Black;
                            y.color = Color.Black;
                            cur = cur._parent._parent;
                            if(cur._parent is end)
                            {
                                // root node
                                cur.color = Color.Black;
                                break;
                            }
                            else
                            {
                                // not root node
                                cur.color = Color.Red;
                                if(cur._parent.color == Color.Black)
                                    // satisfied, exit the loop
                                    break;
                            }
                        }
                        else
                        {
                            if(!cur.isLeftNode)
                                cur = cur._parent.rotateL();
                            cur._parent.color = Color.Black;
                            cur = cur._parent._parent.rotateR();
                            cur.color = Color.Red;
                            // tree should be satisfied now
                            break;
                        }
                    }
                    else
                    {
                        // parent is right node, y is 'uncle'
                        Node y = cur._parent._parent._left;
                        if(y !is null && y.color == Color.Red)
                        {
                            cur._parent.color = Color.Black;
                            y.color = Color.Black;
                            cur = cur._parent._parent;
                            if(cur._parent is end)
                            {
                                // root node
                                cur.color = Color.Black;
                                break;
                            }
                            else
                            {
                                // not root node
                                cur.color = Color.Red;
                                if(cur._parent.color == Color.Black)
                                    // satisfied, exit the loop
                                    break;
                            }
                        }
                        else
                        {
                            if(cur.isLeftNode)
                                cur = cur._parent.rotateR();
                            cur._parent.color = Color.Black;
                            cur = cur._parent._parent.rotateL();
                            cur.color = Color.Red;
                            // tree should be satisfied now
                            break;
                        }
                    }
                }

            }
        }
        else
        {
            //
            // this is the root node, color it black
            //
            color = Color.Black;
        }
    }

    /**
     * Remove this node from the tree.  The 'end' node is used as the marker
     * which is root's parent.  Note that this cannot be null!
     *
     * Returns the next highest valued node in the tree after this one, or end
     * if this was the highest-valued node.
     */
    Node remove(Node end)
    {
        //
        // remove this node from the tree, fixing the color if necessary.
        //
        Node x;
        Node ret;
        if(_left is null || _right is null)
        {
            ret = next;
        }
        else
        {
            //
            // normally, we can just swap this node's and y's value, but
            // because an iterator could be pointing to y and we don't want to
            // disturb it, we swap this node and y's structure instead.  This
            // can also be a benefit if the value of the tree is a large
            // struct, which takes a long time to copy.
            //
            Node yp, yl, yr;
            Node y = next;
            yp = y._parent;
            yl = y._left;
            yr = y._right;
            auto yc = y.color;
            auto isyleft = y.isLeftNode;

            //
            // replace y's structure with structure of this node.
            //
            if(isLeftNode)
                _parent.left = y;
            else
                _parent.right = y;
            //
            // need special case so y doesn't point back to itself
            //
            y.left = _left;
            if(_right is y)
                y.right = this;
            else
                y.right = _right;
            y.color = color;

            //
            // replace this node's structure with structure of y.
            //
            left = yl;
            right = yr;
            if(_parent !is y)
            {
                if(isyleft)
                    yp.left = this;
                else
                    yp.right = this;
            }
            color = yc;

            //
            // set return value
            //
            ret = y;
        }

        // if this has less than 2 children, remove it
        if(_left !is null)
            x = _left;
        else
            x = _right;

        // remove this from the tree at the end of the procedure
        bool removeThis = false;
        if(x is null)
        {
            // pretend this is a null node, remove this on finishing
            x = this;
            removeThis = true;
        }
        else if(isLeftNode)
            _parent.left = x;
        else
            _parent.right = x;

        // if the color of this is black, then it needs to be fixed
        if(color == color.Black)
        {
            // need to recolor the tree.
            while(x._parent !is end && x.color == Node.Color.Black)
            {
                if(x.isLeftNode)
                {
                    // left node
                    Node w = x._parent._right;
                    if(w.color == Node.Color.Red)
                    {
                        w.color = Node.Color.Black;
                        x._parent.color = Node.Color.Red;
                        x._parent.rotateL();
                        w = x._parent._right;
                    }
                    Node wl = w.left;
                    Node wr = w.right;
                    if((wl is null || wl.color == Node.Color.Black) &&
                            (wr is null || wr.color == Node.Color.Black))
                    {
                        w.color = Node.Color.Red;
                        x = x._parent;
                    }
                    else
                    {
                        if(wr is null || wr.color == Node.Color.Black)
                        {
                            // wl cannot be null here
                            wl.color = Node.Color.Black;
                            w.color = Node.Color.Red;
                            w.rotateR();
                            w = x._parent._right;
                        }

                        w.color = x._parent.color;
                        x._parent.color = Node.Color.Black;
                        w._right.color = Node.Color.Black;
                        x._parent.rotateL();
                        x = end.left; // x = root
                    }
                }
                else
                {
                    // right node
                    Node w = x._parent._left;
                    if(w.color == Node.Color.Red)
                    {
                        w.color = Node.Color.Black;
                        x._parent.color = Node.Color.Red;
                        x._parent.rotateR();
                        w = x._parent._left;
                    }
                    Node wl = w.left;
                    Node wr = w.right;
                    if((wl is null || wl.color == Node.Color.Black) &&
                            (wr is null || wr.color == Node.Color.Black))
                    {
                        w.color = Node.Color.Red;
                        x = x._parent;
                    }
                    else
                    {
                        if(wl is null || wl.color == Node.Color.Black)
                        {
                            // wr cannot be null here
                            wr.color = Node.Color.Black;
                            w.color = Node.Color.Red;
                            w.rotateL();
                            w = x._parent._left;
                        }

                        w.color = x._parent.color;
                        x._parent.color = Node.Color.Black;
                        w._left.color = Node.Color.Black;
                        x._parent.rotateR();
                        x = end.left; // x = root
                    }
                }
            }
            x.color = Node.Color.Black;
        }

        if(removeThis)
        {
            //
            // clear this node out of the tree
            //
            if(isLeftNode)
                _parent.left = null;
            else
                _parent.right = null;
        }

        return ret;
    }

    /**
     * Return the leftmost descendant of this node.
     */
    Node leftmost()
    {
        Node result = this;
        while(result._left !is null)
            result = result._left;
        return result;
    }

    /**
     * Return the rightmost descendant of this node
     */
    Node rightmost()
    {
        Node result = this;
        while(result._right !is null)
            result = result._right;
        return result;
    }

    /**
     * Returns the next valued node in the tree.
     *
     * You should never call this on the marker node, as it is assumed that
     * there is a valid next node.
     */
    Node next()
    {
        Node n = this;
        if(n.right is null)
        {
            while(!n.isLeftNode)
                n = n._parent;
            return n._parent;
        }
        else
            return n.right.leftmost;
    }

    /**
     * Returns the previous valued node in the tree.
     *
     * You should never call this on the leftmost node of the tree as it is
     * assumed that there is a valid previous node.
     */
    Node prev()
    {
        Node n = this;
        if(n.left is null)
        {
            while(n.isLeftNode)
                n = n._parent;
            return n._parent;
        }
        else
            return n.left.rightmost;
    }

    Node dup(Node delegate(V v) alloc)
    {
        //
        // duplicate this and all child nodes
        //
        // The recursion should be lg(n), so we shouldn't have to worry about
        // stack size.
        //
        Node copy = alloc(value);
        copy.color = color;
        if(_left !is null)
            copy.left = _left.dup(alloc);
        if(_right !is null)
            copy.right = _right.dup(alloc);
        return copy;
    }

    Node dup()
    {
        Node _dg(V v)
        {
            auto result = new RBNode!(V);
            result.value = v;
            return result;
        }
        return dup(&_dg);
    }
}

/**
 * Implementation of a red black tree.
 *
 * This uses RBNode to implement the tree.
 *
 * Set allowDuplicates to true to allow duplicate values to be inserted.
 */
struct RBTree(V, alias compareFunc, alias updateFunction, alias Allocator=DefaultAllocator, bool allowDuplicates=false, bool doUpdates=true)
{
    /**
     * Convenience alias
     */
    alias RBNode!(V).Node Node;

    /**
     * alias for the allocator
     */
    alias Allocator!(RBNode!(V)) allocator;

    /**
     * The allocator
     */
    allocator alloc;

    /**
     * The number of nodes in the tree
     */
    uint count;

    /**
     * The marker Node.  This is the parent of the root Node.
     */
    Node end;

    /**
     * Setup this RBTree.
     */
    void setup()
    {
        end = allocate();
    }

    /**
     * Add a Node to the RBTree.  Runs in O(lg(n)) time.
     *
     * Returns true if a new Node was added, false if it was not.
     *
     * This can also be used to update a value if it is already in the tree.
     */
    bool add(V v)
    {
        Node added;
        if(end.left is null)
            end.left = added = allocate(v);
        else
        {
            Node newParent = end.left;
            while(true)
            {
                int cmpvalue = compareFunc(newParent.value, v);
                if(cmpvalue == 0)
                {
                    //
                    // found the value already in the tree.  If duplicates are
                    // allowed, pretend the new value is greater than this value.
                    //
                    static if(allowDuplicates)
                    {
                        cmpvalue = -1;
                    }
                    else
                    {
                        static if(doUpdates)
                            updateFunction(newParent.value, v);
                        return false;
                    }
                }
                if(cmpvalue < 0)
                {
                    Node nxt = newParent.right;
                    if(nxt is null)
                    {
                        //
                        // add to right of new parent
                        //
                        newParent.right = added = allocate(v);
                        break;
                    }
                    else
                        newParent = nxt;
                }
                else
                {
                    Node nxt = newParent.left;
                    if(nxt is null)
                    {
                        //
                        // add to left of new parent
                        //
                        newParent.left = added = allocate(v);
                        break;
                    }
                    else
                        newParent = nxt;
                }
            }
        }

        //
        // update the tree colors
        //
        added.setColor(end);

        //
        // did add a Node
        //
        count++;
        version(RBDoChecks)
            check();
        return true;
    }

    /**
     * Return the lowest-valued Node in the tree
     */
    Node begin()
    {
        return end.leftmost;
    }

    /**
     * Remove the Node from the tree.  Returns the next Node in the tree.
     *
     * Do not call this with the marker (end) Node.
     */
    Node remove(Node z)
    in
    {
        assert(z !is end);
    }
    body
    {
        count--;
        //printTree(end.left);
        Node result = z.remove(end);
        static if(allocator.freeNeeded)
            alloc.free(z);
        //printTree(end.left);
        version(RBDoChecks)
            check();
        return result;
    }

    /**
     * Find a Node in the tree with a given value.  Returns end if no such
     * Node exists.
     */
    Node find(V v)
    {
        static if(allowDuplicates)
        {
            //
            // find the left-most v, this allows the pointer to traverse
            // through all the v's.
            //
            Node cur = end;
            Node n = end.left;
            while(n !is null)
            {
                int cmpresult = compareFunc(n.value, v);
                if(cmpresult < 0)
                {
                    n = n.right;
                }
                else
                {
                    if(cmpresult == 0)
                        cur = n;
                    n = n.left;
                }
            }
            return cur;
        }
        else
        {
            Node n = end.left;
            int cmpresult;
            while(n !is null && (cmpresult = compareFunc(n.value, v)) != 0)
            {
                if(cmpresult < 0)
                    n = n.right;
                else
                    n = n.left;
            }
            if(n is null)
                return end;
            return n;
        }
    }

    /**
     * clear all the nodes from the tree.
     */
    void clear()
    {
        static if(allocator.freeNeeded)
        {
            alloc.freeAll();
            end = allocate();
        }
        else
            end.left = null;
        count = 0;
    }

    version(RBDoChecks)
    {
        /**
         * Print the tree.  This prints a sideways view of the tree in ASCII form,
         * with the number of indentations representing the level of the nodes.
         * It does not print values, only the tree structure and color of nodes.
         */
        void printTree(Node n, int indent = 0)
        {
            if(n !is null)
            {
                printTree(n.right, indent + 2);
                for(int i = 0; i < indent; i++)
                    Stdout(".");
                Stdout(n.color == n.color.Black ? "B" : "R").newline;
                printTree(n.left, indent + 2);
            }
            else
            {
                for(int i = 0; i < indent; i++)
                    Stdout(".");
                Stdout("N").newline;
            }
            if(indent is 0)
                Stdout.newline();
        }

        /**
         * Check the tree for validity.  This is called after every add or remove.
         * This should only be enabled to debug the implementation of the RB Tree.
         */
        void check()
        {
            //
            // check implementation of the tree
            //
            int recurse(Node n, char[] path)
            {
                if(n is null)
                    return 1;
                if(n.parent.left !is n && n.parent.right !is n)
                    throw new Exception("Node at path " ~ path ~ " has inconsistent pointers");
                Node next = n.next;
                static if(allowDuplicates)
                {
                    if(next !is end && compareFunc(n.value, next.value) > 0)
                        throw new Exception("ordering invalid at path " ~ path);
                }
                else
                {
                    if(next !is end && compareFunc(n.value, next.value) >= 0)
                        throw new Exception("ordering invalid at path " ~ path);
                }
                if(n.color == n.color.Red)
                {
                    if((n.left !is null && n.left.color == n.color.Red) ||
                            (n.right !is null && n.right.color == n.color.Red))
                        throw new Exception("Node at path " ~ path ~ " is red with a red child");
                }

                int l = recurse(n.left, path ~ "L");
                int r = recurse(n.right, path ~ "R");
                if(l != r)
                {
                    Stdout("bad tree at:").newline;
                    printTree(n);
                    throw new Exception("Node at path " ~ path ~ " has different number of black nodes on left and right paths");
                }
                return l + (n.color == n.color.Black ? 1 : 0);
            }

            try
            {
                recurse(end.left, "");
            }
            catch(Exception e)
            {
                printTree(end.left, 0);
                throw e;
            }
        }
    }

    static if(allowDuplicates)
    {
        /**
         * count all the times v appears in the collection.
         *
         * Runs in O(m * lg(n)) where m is the number of v instances in the
         * collection, and n is the count of the collection.
         */
        uint countAll(V v)
        {
            Node n = find(v);
            uint retval = 0;
            while(n !is end && compareFunc(n.value, v) == 0)
            {
                retval++;
                n = n.next;
            }
            return retval;
        }

        /**
         * remove all the nodes that match v
         *
         * Runs in O(m * lg(n)) where m is the number of v instances in the
         * collection, and n is the count of the collection.
         */
        uint removeAll(V v)
        {
            Node n = find(v);
            uint retval = 0;
            while(n !is end && compareFunc(n.value, v) == 0)
            {
                n = remove(n);
                retval++;
            }
            return retval;
        }
    }

    
    uint intersect(Iterator!(V) subset)
    {
        // build a new RBTree, only inserting nodes that we already have.
        RBNode!(V) newend;
        auto origcount = count;
        count = 0;
        foreach(v; subset)
        {
            //
            // find if the Node is in the current tree
            //
            auto z = find(v);
            if(z !is end)
            {
                //
                // remove the element from the tree, but don't worry about satisfing
                // the Red-black rules.  we don't care because this tree is
                // going away.
                //
                if(z.left is null)
                {
                    //
                    // no left Node, so this is a single parentage line,
                    // move the right Node to be where we are
                    //
                    if(z.isLeftNode)
                        z.parent.left = z.right;
                    else
                        z.parent.right = z.right;
                }
                else if(z.right is null)
                {
                    //
                    // no right Node, single parentage line.
                    //
                    if(z.isLeftNode)
                        z.parent.left = z.left;
                    else
                        z.parent.right = z.left;
                }
                else
                {
                    //
                    // z has both left and right nodes, swap it with the next
                    // Node.  Next Node's left is guaranteed to be null
                    // because it must be a right child of z, and if it had a
                    // left Node, then it would not be the next Node.
                    //
                    Node n = z.next;
                    if(n.parent !is z)
                    {
                        //
                        // n is a descendant of z, but not the immediate
                        // child, we need to link n's parent to n's right
                        // child.  Note that n must be a left child or else
                        // n's parent would have been the next Node.
                        //
                        n.parent.left = n.right;
                        n.right = z.right;
                    }
                    // else, n is the direct child of z, which means there is
                    // no need to update n's parent, or n's right Node (as n
                    // is the right Node of z).

                    if(z.isLeftNode)
                        z.parent.left = n;
                    else
                        z.parent.right = n;
                    n.left = z.left;
                }
                //
                // reinitialize z
                //
                z.color = z.color.init;
                z.left = z.right = null;

                //
                // put it into the new tree.
                //
                if(newend.left is null)
                    newend.left = z;
                else
                {
                    //
                    // got to find the right place for z
                    //
                    Node newParent = newend.left;
                    while(true)
                    {
                        auto cmpvalue = compareFunc(newParent.value, z.value);

                        // <= handles all cases, including when
                        // allowDuplicates is true.
                        if(cmpvalue <= 0)
                        {
                            Node nxt = newParent.right;
                            if(nxt is null)
                            {
                                newParent.right = z;
                                break;
                            }
                            else
                                newParent = nxt;
                        }
                        else
                        {
                            Node nxt = newParent.left;
                            if(nxt is null)
                            {
                                newParent.left = z;
                                break;
                            }
                            else
                                newParent = nxt;
                        }
                    }
                }

                z.setColor(&newend);
                count++;
            }
        }
        static if(allocator.freeNeeded)
        {
            //
            // need to free all the nodes we are no longer using
            //
            freeNode(end.left);
        }
        //
        // replace newend with end.  If we don't do this, cursors pointing
        // to end will be invalidated.
        //
        end.left = newend.left;
        return origcount - count;
    }

    static if(allocator.freeNeeded)
    {
        private void freeNode(Node n)
        {
            if(n !is null)
            {
                freeNode(n.left);
                freeNode(n.right);
                alloc.free(n);
            }
        }
    }

    void copyTo(ref RBTree target)
    {
        target = *this;

        // make shallow copy of RBNodes
        target.end = end.dup(&target.allocate);
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
 * used to define a RB tree that does not require updates.
 */
template RBNoUpdatesTree(V, alias compareFunc, alias Allocator=DefaultAllocator)
{
    alias RBTree!(V, compareFunc, compareFunc, Allocator, false, false) RBNoUpdatesTree;
}
/**
 * used to define a RB tree that takes duplicates
 */
template RBDupTree(V, alias compareFunc, alias Allocator=DefaultAllocator)
{
    alias RBTree!(V, compareFunc, compareFunc, Allocator, true, false) RBDupTree;
}
