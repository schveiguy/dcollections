/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.model.Multiset;

public import dcollections.model.Addable;

/**
 * A Multiset is a container that allows multiple instances of the same value
 * to be added.
 *
 * It is similar to a list, except there is no requirement for ordering.  That
 * is, elements may not be stored in the order added.
 *
 * Since ordering is not important, the collection can reorder elements on
 * removal or addition to optimize the operations.  Indeed most of the
 * operations guarantee better performance than an equivalent list operation
 * would.
 */
interface Multiset(V) : Addable!(V)
{
    /**
     * clear all elements from the multiset (part of collection
     * pseudo-interface)
     */
    Multiset clear();

    /**
     * dup (part of collection pseudo-interface)
     */
    Multiset dup();

    /**
     * Remove an element from the multiset.  Guaranteed to be O(lgN) or better.
     */
    Multiset remove(V v);

    /**
     * Same as remove(v), but indicates whether the element was removed or not.
     */
    Multiset remove(V v, out bool wasRemoved);

    /**
     * Covariant add (from Addable)
     */
    Multiset add(V v);

    /**
     * Covariant add (from Addable)
     */
    Multiset add(V v, out bool wasAdded);

    /**
     * Covariant add (from Addable)
     */
    Multiset add(Iterator!(V) it);

    /**
     * Covariant add (from Addable)
     */
    Multiset add(Iterator!(V) it, out uint numAdded);

    /**
     * Covariant add (from Addable)
     */
    Multiset add(V[] array);

    /**
     * Covariant add (from Addable)
     */
    Multiset add(V[] array, out uint numAdded);

    /**
     * remove all elements with the given value from the multiset.  Guaranteed
     * to be O(lgN*M) or better, where N is the number of elements in the
     * multiset and M is the number of elements to be removed.
     */
    Multiset removeAll(V v);

    /**
     * Same as removeAll(v), but indicates number of elements removed.
     */
    Multiset removeAll(V v, out uint numRemoved);

    /**
     * gets the most convenient element in the multiset.  Note that no
     * particular order of elements is assumed, so this might be the last
     * element added, might be the first, might be one in the middle.  This
     * element would be the first iterated if the multiset is used as an
     * iterator.  This will be faster than finding a specific element because
     * it's guaranteed to be O(1), where finding a specific element is only
     * guaranteed to be O(lgN).
     * TODO: this should be inout
     */
    V get();

    /**
     * Remove the most convenient element in the multiset and return its
     * value.  This is equivalent to (v = get(), remove(v), v), but only
     * does one lookup.
     */
    V take();

    /**
     * Count all the instances of v in the multiset.  Guaranteed to run in
     * O(lgn * m) or better, where n is the number of elements in the multiset,
     * and m is the number of v elements in the multiset.
     */
    uint count(V v);
}
