#!/bin/sh

for file in *.d
do
    dmd -I../ -L-L../ $file -L-ldcollections
done
