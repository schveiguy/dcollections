/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.model.Map;
public import dcollections.model.Collection,
       dcollections.model.Keyed,
       dcollections.model.Multi;

/**
 * A Map collection uses keys to map to values.  This can only have one
 * instance of a particular key at a time.
 */
interface Map(K, V) : Collection!(V), Keyed!(K, V), Multi!(V)
{
}
