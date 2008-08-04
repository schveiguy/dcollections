#!/bin/sh

rm -f *.o
dmd -c dcollections/*.d
rm -f libdcollections.a
ar ruv libdcollections.a *.o
