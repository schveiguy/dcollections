#!/bin/sh

#for file in dcollections/*.d
#do
    #objname=`echo $file | sed s/\.d/\.o/ | sed s/\//\./g`
    #dmd -c $file -o
rm -f *.o
dmd -c dcollections/*.d
rm -f libdcollections.a
ar ruv libdcollections.a *.o
