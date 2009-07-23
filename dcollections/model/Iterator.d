/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.model.Iterator;

enum : uint
{
    /**
     * Returned from length() when length isn't supported
     */
    NO_LENGTH_SUPPORT = ~0
}

/**
 * Basic iterator.  Allows iterating over all the elements of an object.
 */
interface Iterator(V)
{
    /**
     * If supported, returns the number of elements that will be iterated.
     *
     * If not supported, returns NO_LENGTH_SUPPORT.
     */
    uint length();

    /**
     * foreach operator.
     */
    int opApply(int delegate(ref V v) dg);
}

/**
 * Iterator with keys.  This allows one to view the key of the element as well
 * as the value while iterating.
 */
interface KeyedIterator(K, V) : Iterator!(V)
{
    alias Iterator!(V).opApply opApply;

    /**
     * iterate over both keys and values
     */
    int opApply(int delegate(ref K k, ref V v) dg);
}

/**
 * A purge iterator is used to purge values from a collection.  This works by
 * telling the iterator that you want it to remove the value last iterated.
 */
interface Purgeable(V)
{
    /**
     * iterate over the values of the iterator, telling it which values to
     * remove.  To remove a value, set doPurge to true before exiting the
     * loop.
     *
     * Make sure you specify ref for the doPurge parameter:
     *
     * -----
     * foreach(ref doPurge, v; &purgeable.purge){
     * ...
     * -----
     */
    int purge(int delegate(ref bool doPurge, ref V v) dg);
}

/**
 * A purge iterator for keyed containers.
 */
interface KeyPurgeable(K, V) : Purgeable!(V)
{
    /**
     * iterate over the key/value pairs of the iterator, telling it which ones
     * to remove.
     *
     * Make sure you specify ref for the doPurge parameter:
     *
     * -----
     * foreach(ref doPurge, k, v; &purgeable.keypurge){
     * ...
     * -----
     *
     * TODO: note this should have the name purge, but because of asonine
     * lookup rules, it makes it difficult to specify this version over the
     * base version.  Once this is fixed, it's highly likely that this goes
     * back to the name purge.
     *
     * See bugzilla #2498
     */
    int keypurge(int delegate(ref bool doPurge, ref K k, ref V v) dg);
}
