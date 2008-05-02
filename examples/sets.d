/*
 * Copyright (C) 2008 by Steven Schveighoffer
 * all rights reserved.
 *
 * Examples of how sets can be used.
 *
 * Currently only implemented for Tango.
 */
import dcollections.HashSet;
import dcollections.TreeSet;
import dcollections.ArrayList;
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
    auto treeSet = new TreeSet!(int);
    auto hashSet = new HashSet!(int);
    for(int i = 0; i < 10; i++)
        treeSet.add(i*10);
    print(treeSet, "filled in treeset");

    //
    // add all the elements from treeSet to hashSet
    //
    hashSet.add(treeSet);
    print(hashSet, "filled in hashset");

    //
    // you can compare sets
    //
    if(hashSet == treeSet)
        Stdout("equal!").newline;
    else
        Stdout("not equal!").newline;

    //
    // you can do set operations
    //
    // This removes all but the 0, 30, and 50 elements
    hashSet.intersect(new ArrayList!(int)([0, 30, 50, 900, 33]));
    print(hashSet, "intersected hashset");

    // this removes the 0, 30, and 50 elements from treeSet
    treeSet.remove(hashSet);
    print(treeSet, "removed from treeset");

    //
    // You can dup a set, and then add data to it.
    // Note that 7, 8, and 9 are already in the set, so they will only be
    // there once.
    //
    // combine two sets and an array
    treeSet = treeSet.dup.add(hashSet).add([70, 80, 90, 100, 110]);
    print(treeSet, "dup'd, recombined treeset and hashset");
}
