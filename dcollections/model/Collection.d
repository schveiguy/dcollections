/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.model.Collection;

public import dcollections.model.Iterator;

/**
 * The collection interface defines the basic API for all collections.
 *
 * A basic collection should be able to iterate over its elements, tell if it
 * contains an element, and remove elements.  Adding elements is not supported
 * here, because elements are not always simply addable.  For example, a map
 * needs both the element and the key to add it.
 */
interface Collection(V) : Iterator!(V), Purgeable!(V) 
{
    /**
     * clear the container of all values
     */
    Collection!(V) clear();

    /**
     * remove an element with the specific value.  This may be an O(n)
     * operation.  If the collection is keyed, the first element whose value
     * matches will be removed.
     *
     * returns this.
     */
    Collection!(V) remove(V v);

    /**
     * remove an element with the specific value.  This may be an O(n)
     * operation.  If the collection is keyed, the first element whose value
     * matches will be removed.
     *
     * returns this.
     *
     * sets wasRemoved to true if the element existed and was removed.
     */
    Collection!(V) remove(V v, ref bool wasRemoved);

    /**
     * returns true if the collection contains the value.  can be O(n).
     */
    bool contains(V v);

    /**
     * make a copy of this collection.  This does not do a deep copy of the
     * elements if they are reference or pointer types.
     */
    Collection!(V) dup();
}
