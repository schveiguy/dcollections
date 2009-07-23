/*
 * Copyright (C) 2008 by Steven Schveighoffer
 * all rights reserved.
 *
 * Examples of how sets can be used.
 *
 * Currently only implemented for Tango.
 */
import dcollections.HashMultiset;
import dcollections.TreeMultiset;
import dcollections.ArrayMultiset;
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
    // create the array multiset with the given array
    //
    auto arrayMS = new ArrayMultiset!(int);
    arrayMS.add([0, 30, 50]);
    print(arrayMS, "filled in arrayMS");
    
    //
    // you cannot compare multisets, as there is no particular order or lookup
    // function, so the runtime could be O(n^2)
    //
    // you cannot do set operations, as the runtime could be O(n^2)
    //

    //
    // you can get the most convenient element in the multiset, and remove it
    // with a guaranteed < O(n) runtime.
    //
    Stdout("convenient element in arrayMS: ")(arrayMS.get).newline;
    Stdout("removed convenient element in arrayMS: ")(arrayMS.take).newline;
    print(arrayMS, "arrayMS after take");

    //
    // You can dup a multiset, and then add data to it.
    //
    // combine three sets and an array
    treeMS = treeMS.dup.add(hashMS).add(arrayMS).add([70, 80, 90, 100, 110]);
    print(treeMS, "dup'd, recombined treeMS, arrayMS, and hashMS, added some elements");
}
