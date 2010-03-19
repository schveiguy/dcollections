/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.model.List;
public import dcollections.model.Addable;

/**
 * A List is a collection whose elements are in the order added.  These are
 * useful when you need something that keeps track of not only values, but the
 * order added.
 */
interface List(V) : Iterator!(V), Addable!(V)
{
    /**
     * Concatenate two lists together.  The resulting list type is of the type
     * of the left hand side.  The returned list is a new object, different
     * from this and rhs.
     */
    List concat(List rhs);

    /**
     * Concatenate this list and an array together.
     *
     * The resulting list is the same type as this list.
     */
    List concat(V[] array);

    /**
     * Concatenate an array and this list together.
     *
     * The resulting list is the same type as this list.
     */
    List concat_r(V[] array);

    /**
     * operator overload for concatenation.
     */
    auto opBinary(string op, T)(T rhs) if (op == "~" && (is(T == V[]) || is(T == List)))
    {
        return concat(rhs);
    }

    /**
     * operator overload for concatenation of an array with this object.
     */
    auto opBinaryRight(string op, T)(T rhs) if (op == "~" && is(T == V[]))
    {
        return concat_r(rhs);
    }

    /**
     * Append the given elements in the range to the end of the list.  Returns
     * 'this'
     */
    auto opOpAssign(string op, R)(R range) if (op == "~=" && !is(R == V[]) && isInputRange!R && is(ElementType!R == V))
    {
        addRange(range);
        return this;
    }

    /**
     * Append the given item to the 
     */
    auto opOpAssign(string op, T)(T other) if (op == "~=" && (is(T == V[]) || !isInputRange!R))
    {
        return add(other);
    }

    /**
     * clear all elements from the list. (Part of the collection
     * pseudo-interface)
     */
    List clear();

    /**
     * Create a clone of this list. (Part of the collection pseudo-interface)
     */
    List dup();

    /**
     * Covariant add (from Addable)
     */
    List add(V v);

    /**
     * Covariant add (from Addable)
     */
    List add(V v, ref bool wasAdded);

    /**
     * Covariant add (from Addable)
     */
    List add(Iterator!(V) it);

    /**
     * Covariant add (from Addable)
     */
    List add(Iterator!(V) it, ref uint numAdded);

    /**
     * Covariant add (from Addable)
     */
    List add(V[] array);

    /**
     * Covariant add (from Addable)
     */
    List add(V[] array, ref uint numAdded);

    /**
     * sort this list according to the default compare routine for V.  Returns
     * a reference to the list after it is sorted.  O(NlgN) runtime or better.
     */
    List sort();

    /**
     * sort this list according to the comparison routine given.  Returns a
     * reference to the list after it is sorted.  O(NlgN) runtime or better.
     */
    List sort(int delegate(ref V v1, ref V v2) comp);

    /**
     * sort this list according to the comparison routine given.  Returns a
     * reference to the list after it is sorted.  O(NlgN) runtime or better.
     */
    List sort(int function(ref V v1, ref V v2) comp);

    /**
     * compare this list to another list.  Returns true if they have the same
     * number of elements and all the elements are equal.
     *
     * If o is not a list, then 0 is returned.
     */
    bool opEquals(const Object o) const;

    /**
     * Returns the element at the front of the list, or the oldest element
     * added.  If the list is empty, calling front is undefined.
     *
     * TODO: should be inout
     */
    V front();

    /**
     * Returns the element at the end of the list, or the most recent element
     * added.  If the list is empty, calling back is undefined.
     *
     * TODO: should be inout
     */
    V back();

    /**
     * Takes the element at the end of the list, and return its value.  This
     * operation is guaranteed to be O(lgN).  It should always be implementable
     * as O(lgN) because it is O(lgN) to add an element to the end.
     */
    V take();
}
