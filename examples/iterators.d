/*
 * Copyright (C) 2008 by Steven Schveighoffer
 * all rights reserved.
 *
 * Examples of how special iterators can be used.
 *
 * Currently only implemented for Tango.
 */

import dcollections.Iterators;
import dcollections.ArrayList;
import tango.io.Stdout;

void print(V)(Iterator!(V) s, char[] message)
{
    Stdout(message ~ " [");
    foreach(i; s)
        Stdout(" ")(i);
    Stdout(" ]").newline;
}

void print(K, V)(KeyedIterator!(K, V) s, char[] message)
{
    Stdout(message ~ " [");
    foreach(k, v; s)
        Stdout(" ")(k)("=>")(v);
    Stdout(" ]").newline;
}

void main()
{
    auto x = new ArrayList!(int);
    for(int i = 0; i < 10; i++)
        x.add(i + 1);

    print!(uint, int)(x, "original list");

    //
    // use a filter iterator to filter only elements you want.
    //
    // Prints only even elements
    //
    print!(int)(new FilterIterator!(int)(x, function bool(ref int i) {return i % 2 == 0;}), "only even elements");

    //
    // use a transform iterator to change elements as they are iterated.
    //
    // Changes all elements to floating point, multiplied by 1.5
    //
    print!(float)(new TransformIterator!(float, int)(x, function void(ref int i, ref float result) {result = i * 1.5;}), "multiplied by 1.5");

    //
    // use a chain iterator to chain multiple iterators together
    //
    // print x three times
    print!(int)(new ChainIterator!(int)(x, x, x), "prints elements 3 times");

    //
    // this function can convert any iterator to an array.  You can also do
    // this by adding the iterator to an ArrayList, and then calling asArray,
    // but this version does not create an extra class on the heap, and is
    // more optimized.
    //
    auto a = toArray!(int)(x);
    Stdout("converted to an array: ")(a).newline;

    //
    // one can use the keyed transform iterator to transform keyed iterators
    // to normal iterators
    //
    print!(long)(new TransformKeyedIterator!(int, long, uint, int)(x, function void(ref uint idx, ref int v, ref int ignored, ref long result){ result = 0x1_0000_0000L * idx + v;}), "indexes and values combined");

    //
    // chained keyed iterator
    //
    print!(uint, int)(new ChainKeyedIterator!(uint, int)(x, x, x),  "prints elements 3 times (keyed)");

    //
    // keyed filter iterators
    //
    print!(uint, int)(new FilterKeyedIterator!(uint, int)(x, function bool(ref uint idx, ref int v){return idx % 2 == 0;}),  "prints values at even indexes");

    //
    // add all elements to an AA
    //
    Stdout("converted to an AA: ")(toAA!(uint, int)(x)).newline;
}
