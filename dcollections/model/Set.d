/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.model.Set;
public import dcollections.model.Addable;

/**
 * A set is a collection of objects where only one instance of a given item
 * is allowed to exist.  If you add 2 instances of an item, only the first
 * is added.
 */
interface Set(V) : Addable!V, Iterator!V, Purgeable!V
{
    /**
     * Remove all values that match the given iterator.
     */
    Set remove(Iterator!(V) subset);

    /**
     * Remove all values that match the given iterator.
     */
    Set remove(Iterator!(V) subset, out uint numRemoved);

    version(testcompiler)
    {

    /**
     * Remove all the values that are in the given range.
     * returns this.
     * TODO: rename to remove
     */
    auto removeRange(R)(R range) if (isInputRange!R && is(ElementType!R == V))
    {
        bool wasRemoved;
        foreach(v; range)
            remove(v, wasRemoved);
        return this;
    }

    /**
     * Remove all the values that are in the given range.  Sets numRemoved to
     * the number of elements removed.
     * returns this.
     * TODO: rename to remove
     */
    auto removeRange(R)(R range, out uint numRemoved) if (isInputRange!R && is(ElementType!R == V))
    {
        auto len = length;
        bool wasRemoved;
        foreach(v; range)
            remove(v, wasRemoved);
        numRemoved = len - length;
        return this;
    }

    }

    /**
     * Remove all value that are not in the given iterator.
     */
    Set intersect(Iterator!(V) subset);

    /// ditto
    Set intersect(Iterator!(V) subset, out uint numRemoved);

    /**
     * dup (part of collection pseudo-interface)
     */
    Set dup();

    /**
     * Returns true if the given value exists in the collection. Guaranteed to
     * be O(lgN) or better.
     */
    bool contains(V v);

    /**
     * Remove an element from the set.  Guaranteed to be O(lgN) or better.
     */
    Set remove(V v);

    /**
     * Same as remove(v), but wasRemoved is set to true if the value was
     * actually removed.
     */
    Set remove(V v, out bool wasRemoved);

    /**
     * Covariant add (from Addable)
     */
    Set add(V v);

    /**
     * Covariant add (from Addable)
     */
    Set add(V v, out bool wasAdded);

    /**
     * Covariant add (from Addable)
     */
    Set add(Iterator!(V) it);

    /**
     * Covariant add (from Addable)
     */
    Set add(Iterator!(V) it, out uint numAdded);

    /**
     * Covariant add (from Addable)
     */
    Set add(V[] array);

    /**
     * Covariant add (from Addable)
     */
    Set add(V[] array, out uint numAdded);

    /**
     * Compare two sets.  Returns true if both sets have the same number of
     * elements, and all elements in one set exist in the other set.
     *
     * if o is not a Set, return false.
     */
    bool opEquals(Object o);

    /**
     * get the most convenient element in the set.  This is the element that
     * would be iterated first.  Therefore, calling get() is
     * guaranteed to be an O(1) operation.
     */
    V get();

    /**
     * Remove the most convenient element from the set, and return its value.
     * Note that this may not be the same element as returned by get.
     * Guaranteed to be O(lgN) or better.
     */
    V take();
}
