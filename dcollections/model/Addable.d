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
     * returns this.
     */
    Addable!(V) add(V v);

    /**
     * returns this.
     *
     * wasAdded is set to true if the value is added.
     */
    Addable!(V) add(V v, ref bool wasAdded);

    /**
     * add all values retrieved from the collection using the iterator's
     * opApply.  Returns this.
     */
    Addable!(V) add(Iterator!(V) it);

    /**
     * add all values retrieved from the collection using the iterator's
     * opApply. numAdded is set to the number of elements added.
     */
    Addable!(V) add(Iterator!(V) it, ref uint numAdded);

    /**
     * add all the values from the array.  Returns this.
     */
    Addable!(V) add(V[] array);

    /**
     * add all the values from the array.  Returns this.
     *
     * numAdded is set to the number of elements added.
     */
    Addable!(V) add(V[] array, ref uint numAdded);
}
