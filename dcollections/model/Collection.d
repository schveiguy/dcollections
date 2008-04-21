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
interface Collection(V) : Iterator!(V)
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
     * returns true if removed.
     */
    bool remove(V v);

    /**
     * returns true if the collection contains the value.  can be O(n).
     */
    bool contains(V v);

    /**
     * get a purger that can iterate and remove elements.  Note that the
     * collection itself cannot be a PurgeIterator because the number of
     * arguments would match a KeyedCollection's normal iterator.  This would
     * make code ambiguous:
     *
     * -------
     * foreach(k, v; keyedCollection)
     * // is k the doPurge variable or the key?
     * -------
     */
    PurgeIterator!(V) purger();
}
