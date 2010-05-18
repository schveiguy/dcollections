#!/bin/sh

rm -f *.o
if [ "$1" = 'unittest' ]
then
    echo 'void main(){}' > unit_test.d
    if dmd -unittest -gc -version=old unit_test.d dcollections/*.d dcollections/model/*.d
    then
        echo running unit tests...
        ./unit_test
    fi
    rm unit_test.d
else
    dmd -lib -oflibdcollections.a dcollections/*.d dcollections/model/*.d
    #rm -f libdcollections.a
    #ar ruv libdcollections.a *.o
fi
