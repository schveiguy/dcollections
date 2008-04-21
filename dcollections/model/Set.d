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
}
