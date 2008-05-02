/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

   This is a collection of useful iterators.
**********************************************************/
module dcollections.Iterators;

/**
 * This iterator transforms every element from another iterator using a
 * transformation function.
 */
class TransformIterator(V, U=V) : Iterator!(V)
{
    private Iterator!(U) _src;
    private V delegate(ref U) _dg;
    private V function(ref U) _fn;

    this(Iterator!(U) source, V delegate(ref U) dg)
    {
        _src = source;
        _dg = dg;
    }

    this(Iterator!(U) source, V function(ref U) fn)
    {
        _src = source;
        _fn = fn;
    }

    bool supportsLength()
    {
        return _src.supportsLength;
    }

    uint length()
    {
        return _src.length;
    }

    int opApply(int delegate(ref V v) dg)
    {
        int privateDG(ref U u)
        {
            auto v = _dg(u);
            return dg(v);
        }

        int privateFN(ref U u)
        {
            auto v = _fn(u);
            return dg(v);
        }

        if(_dg is null)
            return _src.opApply(&privateFN);
        else
            return _src.opApply(&privateDG);
    }
}

/**
 * A Chain iterator iterates through a chain of iterators.
 */
class ChainIterator(V) : Iterator!(V)
{
    private Iterator!(V)[] _chain;
    private bool _supLength;
    this(Iterator!(V)[] chain ...)
    {
        _chain = chain.dup;
        _supLength = true;
        foreach(it; _chain)
            if(!it.supportsLength)
            {
                _supLength = false;
                break;
            }
    }

    bool supportsLength
    {
        return _supLength;
    }

    uint length()
    {
        uint result = 0;
        foreach(it; _chain)
            result += it.length;
        return result;
    }

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
 * A Filter iterator filters out unwanted elements based on a function or
 * delegate.
 */
class FilterIterator(V) : Iterator!(V)
{
    private Iterator!(V) _src;
    private bool delegate(ref V) _dg;
    private bool function(ref V) _fn;

    this(Iterator!(V) source, bool delegate(ref V) dg)
    {
        _src = source;
        _dg = dg;
    }

    this(Iterator!(V) source, bool function(ref V) fn)
    {
        _src = source;
        _fn = fn;
    }

    bool supportsLength()
    {
        //
        // cannot know what the filter delegate/function will decide.
        //
        return false;
    }

    uint length()
    {
        //
        // cannot know what the filter delegate/function will decide.
        //
        return 0;
    }

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
 * Convert an iterator to an array
 */
V[] toArray(V)(Iterator!(V) it)
{
    V[] result;
    if(it.supportsLength)
    {
        //
        // can optimize a bit
        //
        result.length = it.length;
        int i = 0;
        foreach(v; it)
            result[i++] = v;
    }
    else
    {
        foreach(v; it)
            result ~= v;
    }
}

/**
 * Convert a keyed iterator to an associative array
 */
V[K] toAA(K, V)(KeyedIterator!(K, V) it)
{
    V[K] result;
    foreach(k, v; it)
        result[k] = v;
    return result;
}
