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

    private int privateDG(ref U u)
    {
        auto v = _dg(u);
        return dg(v);
    }

    private int privateFN(ref U u)
    {
        auto v = _fn(u);
        return dg(v);
    }

    int opApply(int delegate(ref V v) dg)
    {
        if(_dg is null)
            return _src.opApply(&privateFN);
        else
            return _src.opApply(&privateDG);
    }
}

/**
 * A Chain iterator iterates through a chain of iterators.  If the 
 */
