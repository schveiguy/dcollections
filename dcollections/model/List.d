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
}
