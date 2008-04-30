/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.model.Map;
public import dcollections.model.Collection,
       dcollections.model.Keyed,
       dcollections.model.Multi;

/**
 * A Map collection uses keys to map to values.  This can only have one
 * instance of a particular key at a time.
 */
interface Map(K, V) : Keyed!(K, V), Collection!(V), Multi!(V)
{
    //alias Keyed!(K,V).opApply opApply;
    //alias Keyed!(K,V).purger purger;

    /**
     * set all the elements from the given keyed iterator in the map.  Any key
     * that already exists will be overridden.
     *
     * Returns this.
     */
    Map!(K, V) set(KeyedIterator!(K, V) source);

    /**
     * set all the elements from the given keyed iterator in the map.  Any key
     * that already exists will be overridden.
     *
     * Returns this.
     *
     * numAdded is set to the number of elements that were added.
     */
    Map!(K, V) set(KeyedIterator!(K, V) source, ref uint numAdded);

    /**
     * Remove all the given keys from the map.
     *
     * return this.
     */
    Map!(K, V) remove(Iterator!(K) subset);

    /**
     * Remove all the given keys from the map.
     *
     * return this.
     *
     * numRemoved is set to the number of elements removed.
     */
    Map!(K, V) remove(Iterator!(K) subset, ref uint numRemoved);

    /**
     * Remove all the keys that are not in the given iterator.
     *
     * returns this.
     */
    Map!(K, V) intersect(Iterator!(K) subset);

    /**
     * Remove all the keys that are not in the given iterator.
     *
     * sets numRemoved to the number of elements removed.
     *
     * returns this.
     */
    Map!(K, V) intersect(Iterator!(K) subset, ref uint numRemoved);

    /**
     * Get a set of the keys that the map contains.  This is not a copy of the
     * keys, but an actual "window" into the keys of the map.  If you add
     * values to the map, they will show up in the keys iterator.
     *
     * This is not in Keyed, because some Keyed containers do not have user
     * defined keys, and so this would be not quite that useful there.
     */
    Iterator!(K) keys();

    /**
     * covariant clear (from Collection)
     */
    Map!(K, V) clear();

    /**
     * covariant dup (from Collection)
     */
    Map!(K, V) dup();

    /**
     * covariant remove (from Collection)
     */
    Map!(K, V) remove(V v);

    /**
     * covariant remove (from Collection)
     */
    Map!(K, V) remove(V v, ref bool wasRemoved);

    /**
     * covariant removeAll (from Multi)
     */
    Map!(K, V) removeAll(V v);

    /**
     * covariant removeAll (from Multi)
     */
    Map!(K, V) removeAll(V v, ref uint numRemoved);

    /**
     * covariant removeAt (from Keyed)
     */
    Map!(K, V) removeAt(K key);

    /**
     * covariant removeAt (from Keyed)
     */
    Map!(K, V) removeAt(K key, ref bool wasRemoved);

    /**
     * covariant set (from Keyed)
     */
    Map!(K, V) set(K key, V value);

    /**
     * covariant set (from Keyed)
     */
    Map!(K, V) set(K key, V value, ref bool wasAdded);
}
