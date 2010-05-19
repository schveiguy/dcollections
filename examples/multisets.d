/*
 * Copyright (C) 2008 by Steven Schveighoffer
 * all rights reserved.
 *
 * Examples of how sets can be used.
 */
import dcollections.HashMultiset;
import dcollections.TreeMultiset;
import std.stdio;

void print(Iterator!(int) s, string message)
{
    write(message ~ " [");
    foreach(i; s)
        write(" ", i);
    writeln(" ]");
}

void main()
{
    auto treeMS = new TreeMultiset!(int);
    auto hashMS = new HashMultiset!(int);
    //
    // multisets can have multiple instances of the same element
    //
    for(int i = 0; i < 10; i++)
        treeMS.add(i*10 % 30);
    print(treeMS, "filled in treeMS");

    //
    // add all the elements from treeMS to hashMS
    //
    hashMS.add(treeMS);
    print(hashMS, "filled in hashMS");

    //
    // you can get the most convenient element in the multiset, and remove it
    // with a guaranteed < O(n) runtime.
    //
    writeln("convenient element in hashMS: ", hashMS.get());
    writeln("removed convenient element in hashMS: ", hashMS.take());
    print(hashMS, "hashMS after take");

    //
    // You can dup a multiset, and then add data to it.
    //
    // combine three sets and an array
    treeMS = treeMS.dup.add(hashMS).add([70, 80, 90, 100, 110]);
    print(treeMS, "dup'd, recombined treeMS and hashMS, added some elements");
}
