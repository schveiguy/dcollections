/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.model.Addable;

public import dcollections.model.Iterator;

private import std.range;

/**
 *  Define an interface for collections that are able to add values.
 */
interface Addable(V)
{
    /**
     * Add an element.  Takes O(lgN) time or better.
     *
     * returns this.
     */
    Addable add(V v);

    /**
     * Same as add(v), but determines whether the element was added or not.
     * returns this.
     *
     * wasAdded is set to true if the value is added.
     */
    Addable add(V v, out bool wasAdded);

    /**
     * add all values retrieved from the collection using the iterator's
     * opApply.  Returns this.
     */
    Addable add(Iterator!(V) it);

    /**
     * add all values retrieved from the collection using the iterator's
     * opApply. numAdded is set to the number of elements added.
     */
    Addable add(Iterator!(V) it, out uint numAdded);

    /**
     * add all the values from the array.  Returns this.
     */
    Addable add(V[] array);

    /**
     * add all the values from the array.  Returns this.
     *
     * numAdded is set to the number of elements added.
     */
    Addable add(V[] array, out uint numAdded);

    /**
     * add all the values from a range.  Returns this.
     * 
     * numAdded is set to the number of elements added.
     *
     * TODO: change name to add
     */
    Addable addRange(R)(R range, out uint numAdded) if (isInputRange!R && is(ElementType!R == V))
    {
        numAdded = 0;
        bool wasAdded;
        foreach(v; range)
        {
            add(v, wasAdded);
            if(wasAdded)
                ++numAdded;
        }
        return this;
    }

    /**
     * add all the values from a range.  Returns this.
     *
     * TODO: change name to add
     */
    Addable addRange(R)(R range) if (isInputRange!R && is(ElementType!R == V))
    {
        foreach(v; range)
            add(v);
        return this;
    }
}
