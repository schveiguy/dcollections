/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.model.List;
public import dcollections.model.Collection,
       dcollections.model.Addable,
       dcollections.model.Multi;

/**
 * A List is a collection whose elements are in the order added.  These are
 * useful when you need something that keeps track of not only values, but the
 * order added.
 */
interface List(V) : Collection!(V), Addable!(V), Multi!(V)
{
    /**
     * Concatenate two lists together.  The resulting list type is of the type
     * of the left hand side.
     */
    List!(V) opCat(List!(V) rhs);

    /**
     * Concatenate this list and an array together.
     *
     * The resulting list is the same type as this list.
     */
    List!(V) opCat(V[] array);

    /**
     * Concatenate an array and this list together.
     *
     * The resulting list is the same type as this list.
     */
    List!(V) opCat_r(V[] array);

    /**
     * append the given list to this list.  Returns 'this'.
     */
    List!(V) opCatAssign(List!(V) rhs);

    /**
     * append the given array to this list.  Returns 'this'.
     */
    List!(V) opCatAssign(V[] array);

    /**
     * covariant clear (from Collection)
     */
    List!(V) clear();

    /**
     * covariant dup (from Collection)
     */
    List!(V) dup();

    /**
     * Covariant remove (from Collection)
     */
    List!(V) remove(V v);

    /**
     * Covariant remove (from Collection)
     */
    List!(V) remove(V v, ref bool wasRemoved);

    /**
     * Covariant add (from Addable)
     */
    List!(V) add(V v);

    /**
     * Covariant add (from Addable)
     */
    List!(V) add(V v, ref bool wasAdded);

    /**
     * Covariant add (from Addable)
     */
    List!(V) add(Iterator!(V) it);

    /**
     * Covariant add (from Addable)
     */
    List!(V) add(Iterator!(V) it, ref uint numAdded);

    /**
     * Covariant add (from Addable)
     */
    List!(V) add(V[] array);

    /**
     * Covariant add (from Addable)
     */
    List!(V) add(V[] array, ref uint numAdded);

    /**
     * covariant removeAll (from Multi)
     */
    List!(V) removeAll(V v);

    /**
     * covariant removeAll (from Multi)
     */
    List!(V) removeAll(V v, ref uint numRemoved);

    /**
     * sort this list according to the default compare routine for V.  Returns
     * a reference to the list after it is sorted.
     */
    List!(V) sort();

    /**
     * sort this list according to the comparison routine given.  Returns a
     * reference to the list after it is sorted.
     */
    List!(V) sort(int delegate(ref V v1, ref V v2) comp);

    /**
     * sort this list according to the comparison routine given.  Returns a
     * reference to the list after it is sorted.
     */
    List!(V) sort(int function(ref V v1, ref V v2) comp);

    /**
     * compare this list to another list.  Returns true if they have the same
     * number of elements and all the elements are equal.
     *
     * If o is not a list, then 0 is returned.
     */
    int opEquals(Object o);

    /**
     * Returns the element at the front of the list, or the oldest element
     * added.  If the list is empty, calling front is undefined.
     */
    V front();

    /**
     * Returns the element at the end of the list, or the most recent element
     * added.  If the list is empty, calling back is undefined.
     */
    V back();

    /**
     * Takes the element at the front of the list, and return its value.  This
     * operation can be as high as O(n).
     */
    V takeFront();

    /**
     * Takes the element at the end of the list, and return its value.  This
     * operation can be as high as O(n).
     */
    V takeBack();
}
