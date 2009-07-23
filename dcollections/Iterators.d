/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

   This is a collection of useful iterators, and iterator
   functions.
**********************************************************/
module dcollections.Iterators;

public import dcollections.model.Iterator;

/**
 * This iterator transforms every element from another iterator using a
 * transformation function.
 */
class TransformIterator(V, U=V) : Iterator!(V)
{
    private Iterator!(U) _src;
    private void delegate(ref U, ref V) _dg;
    private void function(ref U, ref V) _fn;

    /**
     * Construct a transform iterator using a transform delegate.
     *
     * The transform function transforms a type U object into a type V object.
     */
    this(Iterator!(U) source, void delegate(ref U, ref V) dg)
    {
        _src = source;
        _dg = dg;
    }

    /**
     * Construct a transform iterator using a transform function pointer.
     *
     * The transform function transforms a type U object into a type V object.
     */
    this(Iterator!(U) source, void function(ref U, ref V) fn)
    {
        _src = source;
        _fn = fn;
    }

    /**
     * Returns the length that the source provides.
     */
    uint length()
    {
        return _src.length;
    }

    /**
     * Iterate through the source iterator, working with temporary copies of a
     * transformed V element.
     */
    int opApply(int delegate(ref V v) dg)
    {
        int privateDG(ref U u)
        {
            V v;
            _dg(u, v);
            return dg(v);
        }

        int privateFN(ref U u)
        {
            V v;
            _fn(u, v);
            return dg(v);
        }

        if(_dg is null)
            return _src.opApply(&privateFN);
        else
            return _src.opApply(&privateDG);
    }
}

/**
 * Transform for a keyed iterator
 */
class TransformKeyedIterator(K, V, J=K, U=V) : KeyedIterator!(K, V)
{
    private KeyedIterator!(J, U) _src;
    private void delegate(ref J, ref U, ref K, ref V) _dg;
    private void function(ref J, ref U, ref K, ref V) _fn;

    /**
     * Construct a transform iterator using a transform delegate.
     *
     * The transform function transforms a J, U pair into a K, V pair.
     */
    this(KeyedIterator!(J, U) source, void delegate(ref J, ref U, ref K, ref V) dg)
    {
        _src = source;
        _dg = dg;
    }

    /**
     * Construct a transform iterator using a transform function pointer.
     *
     * The transform function transforms a J, U pair into a K, V pair.
     */
    this(KeyedIterator!(J, U) source, void function(ref J, ref U, ref K, ref V) fn)
    {
        _src = source;
        _fn = fn;
    }

    /**
     * Returns the length that the source provides.
     */
    uint length()
    {
        return _src.length;
    }

    /**
     * Iterate through the source iterator, working with temporary copies of a
     * transformed V element.  Note that K can be ignored if this is the only
     * use for the iterator.
     */
    int opApply(int delegate(ref V v) dg)
    {
        int privateDG(ref J j, ref U u)
        {
            K k;
            V v;
            _dg(j, u, k, v);
            return dg(v);
        }

        int privateFN(ref J j, ref U u)
        {
            K k;
            V v;
            _fn(j, u, k, v);
            return dg(v);
        }

        if(_dg is null)
            return _src.opApply(&privateFN);
        else
            return _src.opApply(&privateDG);
    }

    /**
     * Iterate through the source iterator, working with temporary copies of a
     * transformed K,V pair.
     */
    int opApply(int delegate(ref K k, ref V v) dg)
    {
        int privateDG(ref J j, ref U u)
        {
            K k;
            V v;
            _dg(j, u, k, v);
            return dg(k, v);
        }

        int privateFN(ref J j, ref U u)
        {
            K k;
            V v;
            _fn(j, u, k, v);
            return dg(k, v);
        }

        if(_dg is null)
            return _src.opApply(&privateFN);
        else
            return _src.opApply(&privateDG);
    }
}

/**
 * A Chain iterator chains several iterators together.
 */
class ChainIterator(V) : Iterator!(V)
{
    private Iterator!(V)[] _chain;
    private bool _supLength;

    /**
     * Constructor.  Pass in the iterators you wish to chain together in the
     * order you wish them to be chained.
     *
     * If all of the iterators support length, then this iterator supports
     * length.  If one doesn't, then the length is not supported.
     */
    this(Iterator!(V)[] chain ...)
    {
        _chain = chain.dup;
        _supLength = true;
        foreach(it; _chain)
            if(it.length == ~0)
            {
                _supLength = false;
                break;
            }
    }

    /**
     * Returns the sum of all the iterator lengths in the chain.
     *
     * returns NO_LENGTH_SUPPORT if a single iterator in the chain does not support
     * length
     */
    uint length()
    {
        if(_supLength)
        {
            uint result = 0;
            foreach(it; _chain)
                result += it.length;
            return result;
        }
        return NO_LENGTH_SUPPORT;
    }

    /**
     * Iterate through the chain of iterators.
     */
    int opApply(int delegate(ref V v) dg)
    {
        int result = 0;
        foreach(it; _chain)
        {
            if((result = it.opApply(dg)) != 0)
                break;
        }
        return result;
    }
}

/**
 * A Chain iterator chains several iterators together.
 */
class ChainKeyedIterator(K, V) : KeyedIterator!(K, V)
{
    private KeyedIterator!(K, V)[] _chain;
    private bool _supLength;

    /**
     * Constructor.  Pass in the iterators you wish to chain together in the
     * order you wish them to be chained.
     *
     * If all of the iterators support length, then this iterator supports
     * length.  If one doesn't, then the length is not supported.
     */
    this(KeyedIterator!(K, V)[] chain ...)
    {
        _chain = chain.dup;
        _supLength = true;
        foreach(it; _chain)
            if(it.length == NO_LENGTH_SUPPORT)
            {
                _supLength = false;
                break;
            }
    }

    /**
     * Returns the sum of all the iterator lengths in the chain.
     *
     * returns NO_LENGTH_SUPPORT if any iterators in the chain return -1 for length
     */
    uint length()
    {
        if(_supLength)
        {
            uint result = 0;
            foreach(it; _chain)
                result += it.length;
            return result;
        }
        return NO_LENGTH_SUPPORT;
    }

    /**
     * Iterate through the chain of iterators using values only.
     */
    int opApply(int delegate(ref V v) dg)
    {
        int result = 0;
        foreach(it; _chain)
        {
            if((result = it.opApply(dg)) != 0)
                break;
        }
        return result;
    }

    /**
     * Iterate through the chain of iterators using keys and values.
     */
    int opApply(int delegate(ref K, ref V) dg)
    {
        int result = 0;
        foreach(it; _chain)
        {
            if((result = it.opApply(dg)) != 0)
                break;
        }
        return result;
    }
}

/**
 * A Filter iterator filters out unwanted elements based on a function or
 * delegate.
 */
class FilterIterator(V) : Iterator!(V)
{
    private Iterator!(V) _src;
    private bool delegate(ref V) _dg;
    private bool function(ref V) _fn;

    /**
     * Construct a filter iterator with the given delegate deciding whether an
     * element will be iterated or not.
     *
     * The delegate should return true for elements that should be iterated.
     */
    this(Iterator!(V) source, bool delegate(ref V) dg)
    {
        _src = source;
        _dg = dg;
    }

    /**
     * Construct a filter iterator with the given function deciding whether an
     * element will be iterated or not.
     *
     * the function should return true for elements that should be iterated.
     */
    this(Iterator!(V) source, bool function(ref V) fn)
    {
        _src = source;
        _fn = fn;
    }

    /**
     * Returns NO_LENGTH_SUPPORT
     */
    uint length()
    {
        //
        // cannot know what the filter delegate/function will decide.
        //
        return NO_LENGTH_SUPPORT;
    }

    /**
     * Iterate through the source iterator, only accepting elements where the
     * delegate/function returns true.
     */
    int opApply(int delegate(ref V v) dg)
    {
        int privateDG(ref V v)
        {
            if(_dg(v))
                return dg(v);
            return 0;
        }

        int privateFN(ref V v)
        {
            if(_fn(v))
                return dg(v);
            return 0;
        }

        if(_dg is null)
            return _src.opApply(&privateFN);
        else
            return _src.opApply(&privateDG);
    }
}

/**
 * A Filter iterator filters out unwanted elements based on a function or
 * delegate.  This version filters on a keyed iterator.
 */
class FilterKeyedIterator(K, V) : KeyedIterator!(K, V)
{
    private KeyedIterator!(K, V) _src;
    private bool delegate(ref K, ref V) _dg;
    private bool function(ref K, ref V) _fn;

    /**
     * Construct a filter iterator with the given delegate deciding whether a
     * key/value pair will be iterated or not.
     *
     * The delegate should return true for elements that should be iterated.
     */
    this(KeyedIterator!(K, V) source, bool delegate(ref K, ref V) dg)
    {
        _src = source;
        _dg = dg;
    }

    /**
     * Construct a filter iterator with the given function deciding whether a
     * key/value pair will be iterated or not.
     *
     * the function should return true for elements that should be iterated.
     */
    this(KeyedIterator!(K, V) source, bool function(ref K, ref V) fn)
    {
        _src = source;
        _fn = fn;
    }

    /**
     * Returns NO_LENGTH_SUPPORT
     */
    uint length()
    {
        //
        // cannot know what the filter delegate/function will decide.
        //
        return NO_LENGTH_SUPPORT;
    }

    /**
     * Iterate through the source iterator, only iterating elements where the
     * delegate/function returns true.
     */
    int opApply(int delegate(ref V v) dg)
    {
        int privateDG(ref K k, ref V v)
        {
            if(_dg(k, v))
                return dg(v);
            return 0;
        }

        int privateFN(ref K k, ref V v)
        {
            if(_fn(k, v))
                return dg(v);
            return 0;
        }

        if(_dg is null)
            return _src.opApply(&privateFN);
        else
            return _src.opApply(&privateDG);
    }

    /**
     * Iterate through the source iterator, only iterating elements where the
     * delegate/function returns true.
     */
    int opApply(int delegate(ref K k, ref V v) dg)
    {
        int privateDG(ref K k, ref V v)
        {
            if(_dg(k, v))
                return dg(k, v);
            return 0;
        }

        int privateFN(ref K k, ref V v)
        {
            if(_fn(k, v))
                return dg(k, v);
            return 0;
        }

        if(_dg is null)
            return _src.opApply(&privateFN);
        else
            return _src.opApply(&privateDG);
    }
}

/**
 * Simple iterator wrapper for an array.
 */
class ArrayIterator(V) : Iterator!(V)
{
    private V[] _array;

    /**
     * Wrap a given array.  Note that this does not make a copy.
     */
    this(V[] array)
    {
        _array = array;
    }

    /**
     * Returns the array length
     */
    uint length()
    {
        return _array.length;
    }

    /**
     * Iterate over the array.
     */
    int opApply(int delegate(ref V) dg)
    {
        int retval = 0;
        foreach(ref x; _array)
            if((retval = dg(x)) != 0)
                break;
        return retval;
    }
}

/**
 * Wrapper iterator for an associative array
 */
class AAIterator(K, V) : KeyedIterator!(K, V)
{
    private V[K] _array;

    /**
     * Construct an iterator wrapper for the given array
     */
    this(V[K] array)
    {
        _array = array;
    }

    /**
     * Returns the length of the wrapped AA
     */
    uint length()
    {
        return _array.length;
    }

    /**
     * Iterate over the AA
     */
    int opApply(int delegate(ref K, ref V) dg)
    {
        int retval;
        foreach(k, ref v; _array)
            if((retval = dg(k, v)) != 0)
                break;
        return retval;
    }
}

/**
 * Function that converts an iterator to an array.
 *
 * More optimized for iterators that support a length.
 */
V[] toArray(V)(Iterator!(V) it)
{
    V[] result;
    uint len = it.length;
    if(len != NO_LENGTH_SUPPORT)
    {
        //
        // can optimize a bit
        //
        result.length = len;
        int i = 0;
        foreach(v; it)
            result[i++] = v;
    }
    else
    {
        foreach(v; it)
            result ~= v;
    }
    return result;
}

/**
 * Convert a keyed iterator to an associative array.
 */
V[K] toAA(K, V)(KeyedIterator!(K, V) it)
{
    V[K] result;
    foreach(k, v; it)
        result[k] = v;
    return result;
}
