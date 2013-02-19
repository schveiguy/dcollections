#!/bin/sh

for file in *.d
do
    echo $file
    dmd -I../ -L-L../ $file -L-ldcollections
done
