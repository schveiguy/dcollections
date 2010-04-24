#!/bin/sh

if [ "$1" = 'unittest' ]
then
    unittest='-unittest'
fi

rm -f *.o
dmd -c $unittest dcollections/*.d
rm -f libdcollections.a
ar ruv libdcollections.a *.o
