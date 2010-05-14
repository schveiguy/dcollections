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
 * Define the default less function
 */
bool DefaultLess(V)(ref V v1, ref V v2)
{
    // see if we can simply use D's operator overloading
    static if(is(typeof(v1 < v2) == bool))
        return v1 < v2;
    else
        // use runtime function
        return typeid(V).compare(&v1, &v2) < 0;
}

/**
 * Define the default hash function
 */
uint DefaultHash(V)(ref V v)
{
    return typeid(V).getHash(&v);
}
