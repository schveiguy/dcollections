/*
 * Copyright (C) 2008 by Steven Schveighoffer
 * all rights reserved.
 *
 * Examples of how lists can be used.
 *
 * Currently only implemented for Tango.
 */
import dcollections.ArrayList;
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
    auto arrayList = new ArrayList!(int);
    auto linkList = new LinkList!(int);

    for(int i = 0; i < 10; i++)
        arrayList.add(i*5);
    print(arrayList, "filled in arraylist");


    //
    // add all the elements from arraylist to linklist
    //
    linkList.add(arrayList);
    print(linkList, "filled in linkList");

    //
    // you can compare lists
    //
    if(arrayList == linkList)
        Stdout("equal!").newline;
    else
        Stdout("not equal!").newline;

    //
    // you can concatenate lists together
    //
    arrayList ~= linkList;
    print(arrayList, "appended linkList to arrayList");
    linkList = linkList ~ arrayList;
    print(linkList, "concatenated linkList and arrayList");

    //
    // you can purge elements from a list
    //
    // removes all odd elements in the list.
    foreach(ref doPurge, i; &linkList.purge)
        doPurge = (i % 2 == 1);
    print(linkList, "removed all odds from linkList");

    //
    // you can slice ArrayLists
    //
    List!(int) slice = arrayList[5..10];
    print(slice, "slice of arrayList");

    //
    // removing an element from a slice removes it from the parent
    //
    // removes all even elements from arrayList
    foreach(ref doPurge, i; &slice.purge)
        doPurge = (i % 2 == 0);
    print(slice, "removed evens from slice");
    print(arrayList, "arrayList after removal from slice");
}
