/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.model.Set;
public import dcollections.model.Collection,
       dcollections.model.Addable;

/**
 * A set is a collection of objects where only one instance of a given object
 * is allowed to exist.  If you add 2 instances of an object, only the first
 * is added.
 */
interface Set(V) : Collection!(V), Addable!(V)
{
    /**
     * Remove all values that match the given iterator.
     */
    Set!(V) remove(Iterator!(V) subset);

    /**
     * Remove all values that match the given iterator.
     */
    Set!(V) remove(Iterator!(V) subset, ref uint numRemoved);

    /**
     * Remove all value that are not in the given iterator.
     */
    Set!(V) intersect(Iterator!(V) subset);

    /**
     * Remove all value that are not in the given iterator.
     */
    Set!(V) intersect(Iterator!(V) subset, ref uint numRemoved);

    /**
     * Covariant dup (from Collection)
     */
    Set!(V) dup();

    /**
     * Covariant remove (from Collection)
     */
    Set!(V) remove(V v);

    /**
     * Covariant remove (from Collection)
     */
    Set!(V) remove(V v, ref bool wasRemoved);

    /**
     * Covariant add (from Addable)
     */
    Set!(V) add(V v);

    /**
     * Covariant add (from Addable)
     */
    Set!(V) add(V v, ref bool wasAdded);

    /**
     * Covariant add (from Addable)
     */
    Set!(V) add(Iterator!(V) it);

    /**
     * Covariant add (from Addable)
     */
    Set!(V) add(Iterator!(V) it, ref uint numAdded);

    /**
     * Covariant add (from Addable)
     */
    Set!(V) add(V[] array);

    /**
     * Covariant add (from Addable)
     */
    Set!(V) add(V[] array, ref uint numAdded);

    /**
     * Compare two sets.  Returns true if both sets have the same number of
     * elements, and all elements in one set exist in the other set.
     *
     * if o is not a Set, return false.
     */
    int opEquals(Object o);

    /**
     * get the most convenient element in the set.  This is the element that
     * would be iterated first.  Therefore, calling remove(get()) is
     * guaranteed to be less than an O(n) operation.
     */
    V get();

    /**
     * Remove the most convenient element from the set, and return its value.
     * This is equivalent to remove(get()), except that only one lookup is
     * performed.
     */
    V take();
}
