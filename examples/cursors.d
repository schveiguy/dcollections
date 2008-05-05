/*
 * Copyright (C) 2008 by Steven Schveighoffer
 * all rights reserved.
 *
 * Examples of how cursors can be used.
 *
 * Currently only implemented for Tango.
 */
import dcollections.LinkList;
import tango.io.Stdout;

void print(Iterator!(int) s, char[] message)
{
    Stdout(message ~ " [");
    foreach(i; s)
        Stdout(" ")(i);
    Stdout(" ]").newline;
}

void main()
{
    auto list = new LinkList!(int);
    list.add([1,5,6,8,9,2,3,11,2,3,5,7]);
    print(list, "filled in list");

    //
    // cursors can be used to keep references to specific elements in a linked
    // list.
    //
    auto c = list.find(9);
    Stdout.formatln("c points to {}", c.value);

    auto c2 = list.find(6);
    Stdout.formatln("c2 points to {}", c2.value);

    //
    // now, I can remove c2 without affecting c.  Note that for linked list,
    // this is O(1) removal.  Note that removal gives me the next valid
    // iterator.
    //
    c2 = list.remove(c2);
    print(list, "after removal of 6");
    Stdout.formatln("c now points to {}", c.value);
    Stdout.formatln("c2 now points to {}", c2.value);

    //
    // cursors have different behaviors for different collection and
    // implementation types.  Each collection documentation discusses what is
    // and is not allowed, and the run time of each cursor-based function.
    //
}
