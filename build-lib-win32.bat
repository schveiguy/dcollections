for %%i in (dcollections\*.d) do dmd -c -I. %%i
lib -c dcollections.lib ArrayList.obj ArrayMultiset.obj DefaultAllocator.obj Functions.obj Hash.obj HashMap.obj HashMultiset.obj HashSet.obj Iterators.obj Link.obj LinkList.obj RBTree.obj TreeMap.obj TreeMultiset.obj TreeSet.obj
