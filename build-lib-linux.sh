#!/bin/sh

rm -f *.o
if [ "$1" = 'unittest' ]
then
    echo 'void main(){}' > unit_test.d
    dmd -unittest unit_test.d dcollections/*.d dcollections/model/*.d
    rm unit_test.d
else
    dmd -lib -oflibdcollections.a dcollections/*.d dcollections/model/*.d
    #rm -f libdcollections.a
    #ar ruv libdcollections.a *.o
fi
