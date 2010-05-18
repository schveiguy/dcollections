/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.model.Map;

public import dcollections.model.Keyed;

/**
 * A Map collection uses keys to map to values.  This can only have one
 * instance of a particular key at a time.
 */
interface Map(K, V) : Keyed!(K, V)
{
    /**
     * set all the elements from the given keyed iterator in the map.  Any key
     * that already exists will be overridden.
     *
     * Returns this.
     */
    Map set(KeyedIterator!(K, V) source);

    /**
     * set all the elements from the given keyed iterator in the map.  Any key
     * that already exists will be overridden.  numAdded is set to the number
     * of elements actually added.
     *
     * Returns this.
     */
    Map set(KeyedIterator!(K, V) source, out uint numAdded);

    /**
     * set all the elements from the given associative array in the map.  Any
     * key that already exists wil be overridden.
     *
     * Returns this.
     */
    Map set(V[K] source);

    /**
     * set all the elements from the given associative array in the map.  Any
     * key that already exists wil be overridden.  numAdded is set to the
     * number of elements actually added.
     *
     * Returns this.
     */
    Map set(V[K] source, out uint numAdded);

    /**
     * Remove all the given keys from the map.
     *
     * return this.
     */
    Map remove(Iterator!(K) subset);

    /**
     * Remove all the given keys from the map.
     *
     * return this.
     *
     * numRemoved is set to the number of elements removed.
     */
    Map remove(Iterator!(K) subset, out uint numRemoved);

    /**
     * Remove all the given keys from the map.
     *
     * return this.
     */
    Map remove(K[] subset);

    /**
     * Remove all the given keys from the map.
     *
     * return this.
     *
     * numRemoved is set to the number of elements removed.
     */
    Map remove(K[] subset, out uint numRemoved);

    version(testcompiler)
    {

    /**
     * Remove a range of keys from the map.
     *
     * return this.
     *
     * TODO: rename to removeKeys
     */
    auto removeRange(R)(R range) if (isInputRange!R && is(isElementType!R == K))
    {
        foreach(k; range)
            removeAt(k);
        return this;
    }

    /**
     * Remove a range of keys from the map, getting how many were removed.
     *
     * return this.
     * numRemoved is set to the number of elements removed from the map.
     * TODO: rename to removeKeys
     */
    auto removeRange(R)(R range, out uint numRemoved) if (isInputRange!R && is(isElementType!R == K))
    {
        foreach(k; range)
            removeAt(k);
    }

    }

    /**
     * Remove all the keys that are not in the given iterator.
     *
     * returns this.
     */
    Map intersect(Iterator!(K) subset);

    /**
     * Remove all the keys that are not in the given iterator.
     *
     * sets numRemoved to the number of elements removed.
     *
     * returns this.
     */
    Map intersect(Iterator!(K) subset, out uint numRemoved);

    /**
     * Remove all the keys that are not in the given array.
     *
     * returns this.
     */
    Map intersect(K[] subset);

    /**
     * Remove all the keys that are not in the given array.
     *
     * sets numRemoved to the number of elements removed.
     *
     * returns this.
     */
    Map intersect(K[] subset, out uint numRemoved);

    /**
     * Get a set of the keys that the map contains.  This is not a copy of the
     * keys, but an actual "window" into the keys of the map.  If you add
     * values to the map, they will show up in the keys iterator.
     *
     * This is not in Keyed, because some Keyed containers have simple index
     * keys, and so this would be not quite that useful there.
     */
    Iterator!(K) keys();

    /**
     * clear all elements in the collection (part of collection
     * pseudo-interface)
     */
    Map clear();

    /**
     * dup the collection (part of collection pseudo-interface)
     */
    Map dup();

    /**
     * remove element that has the given key
     */
    Map remove(K key);

    /**
     * remove element that has the given key, setting wasRemoved to true if the
     * key was removed.
     */
    Map remove(K key, out bool wasRemoved);

    /**
     * covariant set (from Keyed)
     */
    Map set(K key, V value);

    /**
     * covariant set (from Keyed)
     */
    Map set(K key, V value, out bool wasAdded);

    /**
     * compare two maps.  Returns true if both maps have the same number of
     * elements, and both maps have elements whose keys and values are equal.
     *
     * If o is not a map, then 0 is returned.
     */
    bool opEquals(Object o);

    /**
     * compare map to an AA
     */
    bool opEquals(V[K] other);
}
