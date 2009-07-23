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
interface Keyed(K, V) : KeyedIterator!(K, V), KeyPurgeable!(K, V)
{
    /**
     * remove the value at the given key location
     *
     * Returns this.
     */
    Keyed!(K, V) removeAt(K key);

    /**
     * remove the value at the given key location
     *
     * Returns this.
     *
     * wasRemoved is set to true if the element existed and was removed.
     */
    Keyed!(K, V) removeAt(K key, ref bool wasRemoved);

    /**
     * access a value based on the key
     */
    V opIndex(K key);

    /**
     * assign a value based on the key
     *
     * Use this to insert a key/value pair into the collection.
     *
     * Note that some containers do not use user-specified keys.  For those
     * containers, the key must already have existed before setting.
     */
    V opIndexAssign(V value, K key);

    /**
     * set the key/value pair.  This is similar to opIndexAssign, but returns
     * this, so the function can be chained.
     */
    Keyed!(K, V) set(K key, V value);

    /**
     * Same as set, but has a wasAdded boolean to tell the caller whether the
     * value was added or not.
     */
    Keyed!(K, V) set(K key, V value, ref bool wasAdded);

    /**
     * returns true if the collection contains the key
     */
    bool containsKey(K key);
}
