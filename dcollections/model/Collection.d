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
module dcollections.model.Collection;

public import dcollections.model.Iterator;

interface Collection(V) : Iterator!(V)
{
    alias Iterator!(V).opApply opApply;

    /// clear the container of all values
    Collection!(V) clear();

    /**
     * remove an element with the specific value.  This may be an O(n)
     * operation.  If the collection is keyed, the first element whose value
     * matches will be removed.
     *
     * returns true if removed.
     */
    bool remove(V v);

    /// returns true if the collection contains the value.  can be slow
    bool contains(V v);

    /**
     * get a purger that can iterate and remove elements
     */
    PurgeIterator!(V) purger();
}
