/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.ArrayList;
public import dcollections.model.List,
       dcollections.model.Keyed;

/***
 * This class is a wrapper around an array which provides the necessary
 * implemenation to implement the List interface
 *
 * Adding or removing any element invalidates all cursors.
 */
class ArrayList(V) : List!(V), Keyed!(uint, V)
{
    private V[] _array;
    private uint _mutation;

    private class Purger : PurgeKeyedIterator!(uint, V)
    {
        int opApply(int delegate(ref bool doRemove, ref V value) dg)
        {
            return _apply(dg, begin, end);
        }

        int opApply(int delegate(ref bool doRemove, ref uint key, ref V value) dg)
        {
            return _apply(dg, begin, end);
        }
    }

    private Purger _purger;

    /***
     * The array cursor is exactly like a pointer into the array.  The only
     * difference between an ArrayList cursor and a pointer is that the
     * ArrayList cursor provides the value property which is common
     * throughout the collection package.
     *
     * All operations on the cursor are O(1)
     */
    struct cursor
    {
        private V *ptr;
        
        /**
         * get the value pointed to
         */
        V value()
        {
            return *ptr;
        }

        /**
         * set the value pointed to
         */
        V value(V v)
        {
            return (*ptr = v);
        }

        /**
         * increment this cursor, returns what the cursor was before
         * incrementing.
         */
        cursor opPostInc()
        {
            cursor tmp = *this;
            ptr++;
            return tmp;
        }

        /**
         * decrement this cursor, returns what the cursor was before
         * decrementing.
         */
        cursor opPostDec()
        {
            cursor tmp = *this;
            ptr--;
            return tmp;
        }

        /**
         * increment the cursor by the given amount.
         */
        cursor opAddAssign(int inc)
        {
            ptr += inc;
            return *this;
        }

        /**
         * decrement the cursor by the given amount.
         */
        cursor opSubAssign(int inc)
        {
            ptr -= inc;
            return *this;
        }

        /**
         * return a cursor that is inc elements beyond this cursor.
         */
        cursor opAdd(int inc)
        {
            cursor result = *this;
            result.ptr += inc;
            return result;
        }

        /**
         * return a cursor that is inc elements before this cursor.
         */
        cursor opSub(int inc)
        {
            cursor result = *this;
            result.ptr -= inc;
            return result;
        }

        /**
         * return the number of elements between this cursor and the given
         * cursor.  If it points to a later element, the result is negative.
         */
        int opSub(cursor it)
        {
            return ptr - it.ptr;
        }

        /**
         * compare two cursors.
         */
        int opCmp(cursor it)
        {
            if(ptr < it.ptr)
                return -1;
            if(ptr > it.ptr)
                return 1;
            return 0;
        }

        /**
         * compare two cursors for equality.
         */
        bool opEquals(cursor it)
        {
            return ptr is it.ptr;
        }
    }

    /**
     * create a new empty ArrayList
     */
    this()
    {
        _purger = new Purger();
    }

    private this(V[] storage)
    {
        this();
        _array = storage;
    }

    /**
     * clear the container of all values
     */
    Collection!(V) clear()
    {
        _array = null;
        _mutation++;
        return this;
    }

    /**
     * returns true because this supports length
     */
    bool supportsLength()
    {
        return true;
    }

    /**
     * return the number of elements in the collection
     */
    uint length()
    {
        return _array.length;
    }

    /**
     * return a cursor that points to the first element in the list.
     */
    cursor begin()
    {
        cursor it;
        it.ptr = _array.ptr;
        return it;
    }

    /**
     * return a cursor that points to just beyond the last element in the
     * list.
     */
    cursor end()
    {
        cursor it;
        it.ptr = _array.ptr + _array.length;
        return it;
    }

    private int _apply(int delegate(ref bool, ref uint, ref V) dg, cursor start, cursor last)
    {
        return _apply(dg, start, last, begin);
    }

    private int _apply(int delegate(ref bool, ref uint, ref V) dg, cursor start, cursor last, cursor _begin)
    {
        cursor i = start;
        cursor nextGood = start;
        cursor _end = end;

        int dgret;
        bool doRemove;

        //
        // loop before removal
        //
        for(; dgret == 0 && i < last; i++, nextGood++)
        {
            doRemove = false;
            uint key = i - _begin;
            if((dgret = dg(doRemove, key, *i.ptr)) == 0)
            {
                if(doRemove)
                {
                    //
                    // first removal
                    //
                    _mutation++;
                    i++;
                    break;
                }
            }
        }

        //
        // loop after first removal
        //
        if(nextGood != i)
        {
            for(; i < _end; i++, nextGood++)
            {
                doRemove = false;
                uint key = i - _begin;
                if(i >= last || dgret != 0 || (dgret = dg(doRemove, key, *i.ptr)) != 0)
                {
                    //
                    // not calling dg any more
                    //
                    nextGood.value = i.value;
                }
                else if(doRemove)
                {
                    //
                    // dg requested a removal
                    //
                    nextGood--;
                }
                else
                {
                    //
                    // dg did not request a removal
                    //
                    nextGood.value = i.value;
                }
            }
        }

        //
        // shorten the length
        //
        if(nextGood != _end)
        {
            _array.length = nextGood - begin;
            return _end - nextGood;
        }
        return dgret;
    }

    private int _apply(int delegate(ref bool, ref V) dg, cursor start, cursor last)
    {
        int _dg(ref bool b, ref uint k, ref V v)
        {
            return dg(b, v);
        }
        return _apply(&_dg, start, last);
    }

    /**
     * remove all the elements from start to last, not including the element
     * pointed to by last.  Returns a valid cursor that points to the
     * element last pointed to.
     *
     * Runs in O(n) time.
     */
    cursor remove(cursor start, cursor last)
    {
        int check(ref bool b, ref V)
        {
            b = true;
            return 0;
        }
        _apply(&check, start, last);
        return start;
    }

    /**
     * remove the element pointed to by elem.  Equivalent to remove(elem, elem
     * + 1).
     *
     * Runs in O(n) time
     */
    cursor remove(cursor elem)
    {
        return remove(elem, elem + 1);
    }

    /**
     * remove an element with the specific value.  This is an O(n)
     * operation.  If the collection has duplicate instances, the first
     * element that matches is removed.
     *
     * returns true if removed.
     */
    bool remove(V v)
    {
        auto it = find(v);
        if(it == end)
            return false;
        remove(it);
        return true;
    }

    /**
     * same as find(v), but start at given position.
     */
    cursor find(cursor it, V v)
    {
        return _find(it, end, v);
    }

    // same as find(v), but search only a given range at given position.
    private cursor _find(cursor it, cursor last,  V v)
    {
        while(it < last && it.value != v)
            it++;
        return it;
    }

    /**
     * find the first occurrence of an element in the list.  Runs in O(n)
     * time.
     */
    cursor find(V v)
    {
        return _find(begin, end, v);
    }

    /**
     * returns true if the collection contains the value.  Runs in O(n) time.
     */
    bool contains(V v)
    {
        return find(v) < end;
    }

    /**
     * remove the element at the given index.  Runs in O(n) time.
     */
    bool removeAt(uint key)
    {
        if(key > length)
            return false;
        remove(begin + key);
        return false;
    }

    /**
     * get the value at the given index.
     */
    V opIndex(uint key)
    {
        return (begin + key).value;
    }

    /**
     * set the value at the given index.
     */
    V opIndexAssign(V value, uint key)
    {
        return (begin + key).value = value;
    }

    private int _apply(int delegate(ref uint key, ref V value) dg, cursor start, cursor end)
    {
        int retval = 0;
        cursor _begin = begin;
        for(cursor i = start; i < end; i++)
        {
            uint key = i - _begin;
            if((retval = dg(key, *i.ptr)) != 0)
                break;
        }
        return retval;
    }

    private int _apply(int delegate(ref V value) dg, cursor start, cursor end)
    {
        int retval;
        for(cursor i = start; i < end; i++)
        {
            if((retval = dg(*i.ptr)) != 0)
                break;
        }
        return retval;
    }

    /**
     * iterate over the collection
     */
    int opApply(int delegate(ref V value) dg)
    {
        return _apply(dg, begin, end);
    }

    /**
     * iterate over the collection with key and value
     */
    int opApply(int delegate(ref uint key, ref V value) dg)
    {
        return _apply(dg, begin, end);
    }

    /**
     * Gives an object that can be use to purge the list.
     */
    PurgeIterator!(V) purger()
    {
        return _purger;
    }

    /**
     * gives an object that can be used to purge the list that provides index
     * information as well as value information.
     */
    PurgeKeyedIterator!(uint, V) keyPurger()
    {
        return _purger;
    }

    /**
     * returns true if the given index is valid
     *
     * Runs in O(1) time
     */
    bool containsKey(uint key)
    {
        return key < length;
    }

    /**
     * add the given value to the end of the list.  Always returns true.
     */
    bool add(V v)
    {
        _array ~= v;
        _mutation++;
        return true;
    }

    /**
     * adds all elements from the given collection to the end of the list.
     */
    uint addAll(Iterator!(V) coll)
    {
        ArrayList!(V) al = cast(ArrayList!(V))coll;
        if(al)
        {
            if(al is this)
                throw new Exception("Cannot add all from a collection to itself");
            //
            // optimized case
            //
            return addAll(al._array);
        }
        ArraySlice as = cast(ArraySlice)coll;
        if(as)
        {
            if(as.outer is this)
                throw new Exception("Cannot add all from a collection to itself");
            //
            // array slice, we can figure this one out too
            //
            return addAll(as._slice);
        }

        //
        // generic case
        //
        uint origlength = length;
        if(coll.supportsLength)
        {
            uint i = origlength;
            _array.length = _array.length + coll.length;
            foreach(v; coll)
                _array [i++] = v;
        }
        else
        {
            foreach(v; coll)
                _array ~= v;
        }
        if(length != origlength)
            _mutation++;
        return length - origlength;
    }

    /**
     * appends the array to the end of the list
     */
    uint addAll(V[] array)
    {
        if(array.length)
        {
            _array ~= array;
            _mutation++;
        }
        return array.length;
    }

    /**
     * returns the number of instances of the given element value
     *
     * Runs in O(n) time.
     */
    uint count(V v)
    {
        uint instances = 0;
        foreach(x; this)
            if(v == x)
                instances++;
        return instances;
    }

    /**
     * removes all the instances of the given element value
     *
     * Runs in O(n) time.
     */
    uint removeAll(V v)
    {
        auto origLength = length;
        int check(ref V x)
        {
            return x == v ? 1 : 0;
        }

        _apply(&check, begin, end);
        return origLength - length;
    }

    /**
     * Returns a slice of an array list.  A slice can be used to view
     * elements, remove elements, but cannot be used to add elements.
     *
     * The returned slice begins at index b and ends at, but does not include,
     * index e.
     */
    ArraySlice opSlice(uint b, uint e)
    {
        return opSlice(begin + b, begin + e);
    }

    /**
     * Slice an array given the cursors
     */
    ArraySlice opSlice(cursor b, cursor e)
    {
        if(e > end || b < begin)
            throw new Exception("slice values out of range");
        return new ArraySlice(b, e);
    }

    /**
     * Returns a copy of an array list
     */
    ArrayList!(V) dup()
    {
        return new ArrayList!(V)(_array.dup);
    }

    /**
     * returns a concatenation of two array lists.
     */
    ArrayList!(V) opCat(ArrayList!(V) al)
    {
        return new ArrayList!(V)(_array ~ al._array);
    }

    /**
     * returns a concatenation of an array list and a slice.  The slice can be
     * part of the array list.
     */
    ArrayList!(V) opCat(ArraySlice as)
    {
        return new ArrayList!(V)(_array ~ as._slice);
    }

    /**
     * get the array that this array represents.  This is NOT a copy of the
     * array, so modifying elements of this array will modify elements of the
     * original ArrayList.  Appending or removing elements from this array
     * will not affect the original array list just like appending to a slice
     * of an array will not affect the original array.
     */
    V[] asArray()
    {
        return _array;
    }

    /**
     * An array slice is a slice into an arraylist.  An ArraySlice is just
     * like a native array slice, except it implements the necessary
     * interfaces to be considered a Keyed Collection.
     *
     * If an underlying array list structure is changed not through this
     * slice, then the slice becomes invalid, and any usage of the slice will
     * throw an exception.
     *
     * Cursors obtained from this slice can be used on the main array list,
     * and cursors obtained from the main array list can be used on this
     * slice, as long as the cursors in question are within the bounds of
     * the array slice.
     *
     * As with ArrayList, all cursors into this slice and into the
     * underlying array list are invalidated when an element is removed.
     */
    public class ArraySlice : Collection!(V), Keyed!(uint, V), Multi!(V)
    {
        private cursor _start, _end;
        private uint _mutation;
        private Purger _purger;

        private this(cursor start, cursor end)
        {
            this._mutation = this.outer._mutation;
            this._start = start;
            this._end = end;
            _purger = new Purger;
        }

        private void checkMutation()
        {
            if(_mutation != this.outer._mutation)
                throw new Exception("underlying collection changed");
        }

        /**
         * clear the container of all values
         */
        Collection!(V) clear()
        {
            checkMutation();
            remove(_start, _end);
            _end = _start;
            _mutation = this.outer._mutation;
            return this;
        }

        /**
         * returns true
         */
        bool supportsLength()
        {
            return true;
        }

        /**
         * return the number of elements in the slice
         */
        uint length()
        {
            checkMutation();
            return _end - _start;
        }

        /**
         * return a cursor for the slice
         */
        cursor begin()
        {
            checkMutation();
            return _start;
        }

        /**
         * return a cursor that points to the end of the slice.
         */
        cursor end()
        {
            checkMutation();
            return _end;
        }

        private int _apply(int delegate(ref bool, ref uint, ref V) dg, cursor start, cursor last)
        {
            checkMutation();
            if(start < _start || last > _end)
                throw new Exception("invalid range");
            uint origLength = this.outer.length;
            uint dgret = this.outer._apply(dg, start, last, _start);
            _end -= (origLength - this.outer.length);
            _mutation = this.outer._mutation;
            return dgret;
        }

        private int _apply(int delegate(ref bool, ref V) dg, cursor start, cursor last)
        {
            int _dg(ref bool b, ref uint k, ref V v)
            {
                return dg(b, v);
            }
            return _apply(&_dg, start, last);
        }

        /**
         * remove an element with the specific value.  If there is more than
         * one instance of the element, only the first is removed.
         *
         * returns true if removed.
         */
        bool remove(V v)
        {
            checkMutation();
            auto it = _find(_start, _end, v);
            if(it >= _end)
                return false;
            remove(it);
            _mutation = this.outer._mutation;
            return true;
        }

        /**
         * Removes all the elements from start to last, not including last.
         *
         * Returns a valid cursor that points to the element last pointed
         * to.
         *
         * Runs in O(n) time
         */
        cursor remove(cursor start, cursor last)
        {
            int check(ref bool b, ref V v)
            {
                b = true;
                return 0;
            }
            _apply(&check, start, last);
            return start;
        }

        /**
         * Remove the element pointed to by elem.
         *
         * Equivalent to remove(elem, elem + 1);
         *
         * Runs in O(n) time.
         */
        cursor remove(cursor elem)
        {
            return remove(elem, elem + 1);
        }

        /**
         * iterate over the collection
         */
        int opApply(int delegate(ref V value) dg)
        {
            checkMutation();
            return this.outer._apply(dg, _start, _end);
        }

        /**
         * cursor over the collection with key and value.
         */
        int opApply(int delegate(ref uint key, ref V value) dg)
        {
            checkMutation();
            return this.outer._apply(dg, _start, _end);
        }

        private class Purger : PurgeKeyedIterator!(uint, V)
        {
            int opApply(int delegate(ref bool, ref V) dg)
            {
                return _apply(dg, _start, _end);
            }

            int opApply(int delegate(ref bool, ref uint, ref V) dg)
            {
                return _apply(dg, _start, _end);
            }
        }

        /**
         * returns an object that can be used to purge the collection.
         */
        PurgeIterator!(V) purger()
        {
            return _purger;
        }

        /**
         * returns an object that can be used to purge the collection with
         * index and value.
         */
        PurgeKeyedIterator!(uint, V) keyPurger()
        {
            return _purger;
        }

        /**
         * returns cursor to the first element in the list that matches v,
         * or end if it doesn't exist.
         *
         * Runs in O(n).
         */
        cursor find(V v)
        {
            checkMutation();
            return _find(_start, _end, v);
        }

        /**
         * returns true if the collection contains the value.
         *
         * Runs in O(n).
         */
        bool contains(V v)
        {
            checkMutation();
            return _find(_start, _end, v) < _end;
        }

        /**
         * Removes the element at the given index.  If the index isn't valid
         * for this collection, returns false.  Otherwise, removes the element
         * and returns true.
         *
         * Runs in O(n).
         */
        bool removeAt(uint key)
        {
            if(key > length)
                return false;
            remove(_start + key);
            return false;
        }

        /**
         * Returns the element at the given index.
         *
         * Runs in O(1).
         */
        V opIndex(uint key)
        {
            checkMutation();
            return (_start + key).value;
        }

        /**
         * Assigns the value to the element at the given index.
         *
         * Runs in O(1).
         */
        V opIndexAssign(V value, uint key)
        {
            checkMutation();
            return (_start + key).value = value;
        }

        /**
         * Returns true if the given index is valid
         */
        bool containsKey(uint key)
        {
            return key < length;
        }

        /**
         * Returns a new array list that has the same elements as this slice.
         */
        ArrayList!(V) dup()
        {
            return new ArrayList!(V)(_slice.dup);
        }

        /**
         * Returns a slice into this slice.  Note that this new slice is
         * independent of the original slice.  So if you remove an element
         * through the new slice, the original slice is invalidated.
         */
        ArraySlice opSlice(uint b, uint e)
        {
            return opSlice(_start + b, _start + e);
        }

        /**
         * Returns a slice into this slice, based on cursors.
         */
        ArraySlice opSlice(cursor b, cursor e)
        {
            checkMutation();
            if(e > _end || b < _start)
                throw new Exception("slice values out of range");
            return new ArraySlice(b, e);
        }


        /**
         * Return the slice as an array.  Note that this is NOT a copy, it is
         * the actual array data from the underlying array.  Modifying
         * elements of this array will modify the original slice.  Appending
         * or removing elements will not affect the original slice just like
         * appending or removing elements to a native slice would not affect
         * the original elements of an array.
         */
        V[] asArray()
        {
            uint s, e;
            s = _start - this.outer.begin;
            e = _end - this.outer.begin;
            return _array[s..e];
        }

        /**
         * Returns the number of elements that are the same as v
         */
        uint count(V v)
        {
            uint instances = 0;
            foreach(x; this)
                if(v == x)
                    instances++;
            return instances;
        }

        /**
         * Removes all elements from the slice that are the same as v.
         */
        uint removeAll(V v)
        {
            uint originalLength = length;
            foreach(ref bool b, V x; _purger)
            {
                if(x == v)
                    b = true;
            }
            return originalLength - length;
        }
    }
}
