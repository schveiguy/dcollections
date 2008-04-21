/*********************************************************
   Copyright (C) 2008 by Steven Schveighoffer.
              All rights reserved

   Permission is hereby granted, free of charge, to any person obtaining a
   copy of this software and associated documentation files (the "Software"),
   to deal in the Software without restriction, including without limitation
   the rights to use, copy, modify, merge, publish, distribute, sublicense,
   and/or sell copies of the Software, and to permit persons to whom the
   Software is furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
   DEALINGS IN THE SOFTWARE.

**********************************************************/
module dcollections.model.Iterator;

/**
 * Basic iterator.  Allows iterating over all the elements of an object.
 */
interface Iterator(V)
{
    /**
     * Should return true if the length can be obtained, false if it cannot.
     */
    bool supportsLength();

    /**
     * If supported, returns the number of elements that will be iterated.
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
interface PurgeIterator(V)
{
    /**
     * iterate over the values of the iterator, telling it which values to
     * remove.  To remove a value, set doPurge to true before exiting the
     * loop.
     *
     * Make sure you specify ref for the doPurge parameter:
     *
     * -----
     * foreach(ref doPurge, v; purgeIterator){
     * ...
     * -----
     */
    int opApply(int delegate(ref bool doPurge, ref V v) dg);
}

/**
 * A purge iterator for keyed containers.
 */
interface PurgeKeyedIterator(K, V) : PurgeIterator!(V)
{
    alias PurgeIterator!(V).opApply opApply;

    /**
     * iterate over the key/value pairs of the iterator, telling it which ones
     * to remove.
     *
     * Make sure you specify ref for the doPurge parameter:
     *
     * -----
     * foreach(ref doPurge, k, v; purgeIterator){
     * ...
     * -----
     */
    int opApply(int delegate(ref bool doPurge, ref K k, ref V v) dg);
}
