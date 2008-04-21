/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.model.Keyed;

public import dcollections.model.Iterator;

/**
 * Interface defining an object that accesses values by key.
 */
interface Keyed(K, V) : KeyedIterator!(K, V)
{
    /**
     * remove the value at the given key location
     *
     * Returns true if the element was removed, false if the element didn't
     * exist.
     */
    bool removeAt(K key);

    /**
     * access a value based on the key
     */
    V opIndex(K key);

    /**
     * assign a value based on the key
     *
     * Use this to insert a key/value pair into the collection.
     */
    V opIndexAssign(V value, K key);

    /**
     * returns true if the collection contains the key
     */
    bool containsKey(K key);

    /**
     * allows a purge operation on the collection
     */
    PurgeKeyedIterator!(K, V) keyPurger();
}
