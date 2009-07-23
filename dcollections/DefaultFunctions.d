/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.DefaultFunctions;

/**
 * Define the default compare
 */
int DefaultCompare(V)(ref V v1, ref V v2)
{
    return typeid(V).compare(&v1, &v2);
}

/**
 * Define the default hash function
 */
uint DefaultHash(V)(ref V v)
{
    return typeid(V).getHash(&v);
}
