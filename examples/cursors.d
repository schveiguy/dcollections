/*
 * Copyright (C) 2008-2010 by Steven Schveighoffer
 * all rights reserved.
 *
 * Examples of how cursors can be used.
 */
import dcollections.LinkList;
import std.stdio;
import std.algorithm;

void print(Iterator!(int) s, string message)
{
    write(message ~ " [");
    foreach(i; s)
        writef(" %s", i);
    writeln(" ]");
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
    auto c = find(list[], 9).begin;
    writeln("c points to ", c.front);

    auto c2 = find(list[], 6).begin;
    writeln("c2 points to ", c2.front);

    //
    // now, I can remove c2 without affecting c.  Note that for linked list,
    // this is O(1) removal.  Note that removal gives me the next valid
    // iterator.
    //
    c2 = list.remove(c2);
    print(list, "after removal of 6");
    writeln("c now points to ", c.front);
    writeln("c2 now points to ", c2.front);

    //
    // cursors have different behaviors for different collection and
    // implementation types.  Each collection documentation discusses what is
    // and is not allowed, and the run time of each cursor-based function.
    //
}
