# dcollections

## Status

dcollections version 1.0 is released, and only bug fixes will be incorporated,
no new features.  dcollections version 2.0 for the D2 compiler is in alpha
stage, and will be developed moving forward replacement for 1.0.  Please see
the web site for the latest version.

## Documentation

The documentation for the D2 version of dcollections is not yet published
online.  The automatic doc generator on dsource is D1 only, so I must find a
different way of generating documentation.

In addition, many docs are outdated.  In particular, the requirements for
creating alternate implementations are not correct.  This will be fixed in the
future.

You can build the documentation yourself using dmd's ddoc feature.  I have done
this in the distribution for your convenience, but I have eliminated the
candydoc features.  I plan to use a more advanced tool, such as descent, which
does cross linking.

## Building the library

### Using dub

You can use [dub] to make this library a dependency for your project.

[dub]: http://code.dlang.org/about

### Using alternate build scripts

To build libdcollections.a or dcollections.lib, run the build script (either
build-lib-linux.sh or build-lib-win32.bat)

Move libdcollections.a or dcollections.lib to a directory in your link path, or
add the following to your dmd.conf file under the DFLAGS line:

-L-Lpath/to/library -L-ldcollections

or in your sc.ini file:

LIB=...;path/to/library
DFLAGS=... -L+dcollections.lib

where the ... represents what's there now.

Then copy the dcollections source tree to wherever you have your import tree.
Otherwise, add a -Ipath/to/dcollections to the appropriate config file for your
system

## Building the examples

### Using dub

You can compile and run each of the examples using [dub]:

```
dub --config=cursors

dub --config=iterators

dub --config=lists

dub --config=maps

dub --config=multisets

dub --config=sets
```

[dub]: http://code.dlang.org/about

## Compiler

This library was tested with DMD version 2.065.  Since D2 is not officially
released yet, and some bugs still exist, I suggest using that version or later.

There are several outstanding bugs in dmd that are blocking some features of
dcollections.  Two of the major ones are 4174 and 3659.  There are some
workarounds in place, but you may run into some of these.

Bug 5870 is impossible to create a workaround for, however, it only occurs when -debug is enabled, so if you are compiling with -debug you may run into this one.

## Concepts

Read the `concepts.txt` document in the distribution to understand some of the
concepts behind dcollections for D2.  For those of you experienced with
dcollections for D1, please read this document, there are some significant
changes.  I plan to make these documents more official on the web site in time.

## License

Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_1_0.txt or copy [here][BoostLicense].

[BoostLicense]: http://www.boost.org/LICENSE_1_0.txt
