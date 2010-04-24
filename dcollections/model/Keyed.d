/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.model.Keyed;

public import dcollections.model.Iterator;

/**
 * Interface defining an object that accesses values by key.
 * All operations on the object are O(lgN) or better.
 */
interface Keyed(K, V) : KeyedIterator!(K, V), KeyPurgeable!(K, V)
{
    /**
     * access a value based on the key
     */
    V opIndex(K key);

    /**
     * assign a value based on the key
     *
     * Use this to set/insert a key/value pair into the collection.
     *
     * Note that some containers do not allow adding key/value pairs in this
     * manner.
     *
     * For those containers, the key must already exist.  If the key does not
     * already exist, a range exception is thrown.
     */
    V opIndexAssign(V value, K key);

    /**
     * set the key/value pair.  This is similar to opIndexAssign, but returns
     * 'this', so the function can be chained.
     */
    Keyed set(K key, V value);

    /**
     * Same as set, but has a wasAdded boolean to tell the caller whether the
     * value was added or not.
     */
    Keyed set(K key, V value, out bool wasAdded);

    /**
     * returns true if the collection contains the key
     */
    bool containsKey(K key);
}
