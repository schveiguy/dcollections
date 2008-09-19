/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

**********************************************************/
module dcollections.Functions;

/**
 * Define a hash function type.
 */
template HashFunction(V)
{
    alias uint function(ref V v) HashFunction;
}

/**
 * Define an update function type.  The update function is responsible for
 * performing the operation denoted by:
 *
 * origv = newv
 *
 * This can be different for Maps for example, where V may contain the key as
 * well as the value.
 */
template UpdateFunction(V)
{
    alias void function(ref V origv, ref V newv) UpdateFunction;
}

/**
 * Define a comparison function type
 *
 * This can be different for Maps in the same way the update function is
 * different.
 */
template CompareFunction(V)
{
    alias int function(ref V v1, ref V v2) CompareFunction;
}

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
