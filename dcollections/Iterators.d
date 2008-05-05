/*********************************************************
   Copyright: (C) 2008 by Steven Schveighoffer.
              All rights reserved

   License: $(LICENSE)

   This is a collection of useful iterators, and iterator
   functions.
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

    /**
     * Construct a transform iterator using a transform delegate.
     *
     * The transform function transforms a type U object into a type V object.
     */
    this(Iterator!(U) source, V delegate(ref U) dg)
    {
        _src = source;
        _dg = dg;
    }

    /**
     * Construct a transform iterator using a transform function pointer.
     *
     * The transform function transforms a type U object into a type V object.
     */
    this(Iterator!(U) source, V function(ref U) fn)
    {
        _src = source;
        _fn = fn;
    }

    /**
     * Returns true if the source iterator suports length.
     */
    bool supportsLength()
    {
        return _src.supportsLength;
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
            if(!it.supportsLength)
            {
                _supLength = false;
                break;
            }
    }

    /**
     * Returns true if all the iterators in the chain support length.
     */
    bool supportsLength()
    {
        return _supLength;
    }

    /**
     * Returns the sum of all the iterator lengths in the chain.
     *
     * returns 0 if supportsLength is false.
     */
    uint length()
    {
        uint result = 0;
        if(_supLength)
        {
            foreach(it; _chain)
                result += it.length;
        }
        return result;
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
     * Always returns false.  It is impossible to tell how many elements from
     * the underlying iterator will pass the filter function.
     */
    bool supportsLength()
    {
        //
        // cannot know what the filter delegate/function will decide.
        //
        return false;
    }

    /**
     * Returns 0
     */
    uint length()
    {
        //
        // cannot know what the filter delegate/function will decide.
        //
        return 0;
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
 * Function that converts an iterator to an array.
 *
 * More optimized for iterators that support a length.
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
 * Convert a keyed iterator to an associative array.
 */
V[K] toAA(K, V)(KeyedIterator!(K, V) it)
{
    V[K] result;
    foreach(k, v; it)
        result[k] = v;
    return result;
}
