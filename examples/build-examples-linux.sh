#!/bin/sh

#
# this assumes dcollections is somewhere in your -L path
#

for file in *.d
do
    dmd $file -L-ldcollections
done
