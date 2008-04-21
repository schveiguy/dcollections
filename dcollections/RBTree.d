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
module dcollections.RBTree;

private import dcollections.Functions;
import tango.io.Stdout;

//
// this implementation assumes we have a marker node that is the parent of the
// root node.  This marker node is not a valid node, but marks the end of the
// collection.  The root is the left child of the marker node, so it is always
// iterated last.  The marker node is passed in to the setColor function, and
// the node which has this node as its parent is assumed to be the root node.
//
/**
 * Implementation for a Red Black node for use in a Red Black Tree (see below)
 */
class RBNode(V)
{
    alias RBNode!(V) Node;

    private Node _left;
    private Node _right;
    private Node _parent;

    enum Color : byte
    {
        Red,
        Black
    }

    this()
    {
    }

    this(V v)
    {
        value = v;
    }

    Color color;
    V value;

    Node left()
    {
        return _left;
    }

    Node right()
    {
        return _right;
    }

    Node parent()
    {
        return _parent;
    }

    Node left(Node newNode)
    {
        _left = newNode;
        if(newNode !is null)
            newNode._parent = this;
        return this;
    }

    Node right(Node newNode)
    {
        _right = newNode;
        if(newNode !is null)
            newNode._parent = this;
        return this;
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


    bool isLeftNode()
    in
    {
        assert(_parent !is null);
    }
    body
    {
        return _parent._left is this;
    }

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

    //
    // returns next node in the tree if it exists, or end if this was the node
    // that contained the highest key
    //
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
            // clear y out of the tree
            //
            if(isLeftNode)
                _parent.left = null;
            else
                _parent.right = null;
        }

        return ret;
    }

    Node leftmost()
    {
        Node result = this;
        while(result._left !is null)
            result = result._left;
        return result;
    }

    Node rightmost()
    {
        Node result = this;
        while(result._right !is null)
            result = result._right;
        return result;
    }

    // this works only if you never call next on the marker node
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

    // this works only if you never call prev on the leftmost node of the
    // tree.
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
}

/**
 * Implementation of a red black tree
 */
struct RBTree(V, bool allowDuplicates=false)
{
    alias RBNode!(V) node;
    uint count;

    CompareFunction!(V) compareFunc;

    static if(!allowDuplicates)
    {
        UpdateFunction!(V) updateFunc;
    }

    node end;

    struct parameters
    {
        //
        // these 2 functions must always be present with these member names.
        //
        CompareFunction!(V) compareFunction;
        static if(!allowDuplicates)
        {
            UpdateFunction!(V) updateFunction;
        }
    }

    void setup(parameters p)
    {
        compareFunc = p.compareFunction;
        static if(!allowDuplicates)
        {
            updateFunc = p.updateFunction;
        }
        end = new node();
    }

    bool add(V v)
    {
        node added;
        if(end.left is null)
            end.left = added = new node(v);
        else
        {
            node newParent = end.left;
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
                        updateFunc(newParent.value, v);
                        return false;
                    }
                }
                if(cmpvalue < 0)
                {
                    node nxt = newParent.right;
                    if(nxt is null)
                    {
                        //
                        // add to right of new parent
                        //
                        newParent.right = added = new node(v);
                        break;
                    }
                    else
                        newParent = nxt;
                }
                else
                {
                    node nxt = newParent.left;
                    if(nxt is null)
                    {
                        //
                        // add to left of new parent
                        //
                        newParent.left = added = new node(v);
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
        // did add a node
        //
        count++;
        check();
        return true;
    }

    node begin()
    {
        return end.leftmost;
    }

    node remove(node z)
    in
    {
        assert(z !is end);
    }
    body
    {
        count--;
        //printTree(end.left);
        node result = z.remove(end);
        //printTree(end.left);
        check();
        return result;
    }

    node find(V v)
    {
        static if(allowDuplicates)
        {
            //
            // find the left-most v, this allows the pointer to traverse
            // through all the v's.
            //
            node cur = end;
            node n = end.left;
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
            node n = end.left;
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

    void clear()
    {
        end.left = null;
        count = 0;
    }

    void printTree(node n, int indent = 0)
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

    void check()
    {
        version(doChecks)
        {
            //
            // check implementation of the tree
            //
            int recurse(node n, char[] path)
            {
                if(n is null)
                    return 1;
                if(n.parent.left !is n && n.parent.right !is n)
                    throw new Exception("node at path " ~ path ~ " has inconsistent pointers");
                node next = n.next;
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
                        throw new Exception("node at path " ~ path ~ " is red with a red child");
                }

                int l = recurse(n.left, path ~ "L");
                int r = recurse(n.right, path ~ "R");
                if(l != r)
                {
                    Stdout("bad tree at:").newline;
                    printTree(n);
                    throw new Exception("node at path " ~ path ~ " has different number of black nodes on left and right paths");
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
        uint countAll(V v)
        {
            node n = find(v);
            uint retval = 0;
            while(n !is end && n.value == v)
            {
                retval++;
                n = n.next;
            }
            return retval;
        }

        uint removeAll(V v)
        {
            node n = find(v);
            uint retval = 0;
            while(n !is end && n.value == v)
            {
                n = remove(n);
                retval++;
            }
            return retval;
        }
    }
}

/**
 * used to define a RB tree that takes duplicates
 */
template RBDupTree(V)
{
    alias RBTree!(V, true) RBDupTree;
}
