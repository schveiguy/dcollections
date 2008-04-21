/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.model.Addable;

public import dcollections.model.Collection;

/**
 *  Define an interface for collections that are able to add values.
 */
interface Addable(V)
{
    /**
     * returns true if the value was added
     */
    bool add(V v);

    /**
     * add all values retrieved from the collection using the iterator's
     * opApply.
     */
    uint addAll(Iterator!(V) it);

    /**
     * add all the values from the array
     */
    uint addAll(V[] array);
}
