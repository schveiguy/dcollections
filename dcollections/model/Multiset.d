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
module dcollections.model.Multiset;
public import dcollections.model.Collection,
       dcollections.model.Addable,
       dcollections.model.Multi;

/**
 * A Multiset is a container that allows multiple instances of the same value
 * to be added.
 *
 * It is similar to a list, except there is no requirement for ordering.  That
 * is, elements may not be stored in the order added.
 *
 * Since ordering is not important, the collection can reorder elements on
 * removal or addition to optimize the operations.
 */
interface Multiset(V) : Collection!(V), Addable!(V), Multi!(V)
{
}
