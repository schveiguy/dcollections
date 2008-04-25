/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.model.Multi;
public import dcollections.model.Collection,
       dcollections.model.Addable;

/**
 * The Multi interface defines functions for objects that can have multiple
 * instances of the same value.
 */
interface Multi(V)
{
    /**
     * count the number of elements that match the given value
     */
    uint count(V v);

    /**
     * remove all instances of the given element
     */
    Multi!(V) removeAll(V v);

    /**
     * remove all instances of the given element.
     *
     * sets numRemoved to number of elements removed.
     */
    Multi!(V) removeAll(V v, ref uint numRemoved);
}
