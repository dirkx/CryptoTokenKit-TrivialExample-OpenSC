CryptoTokenKit-TrivialExample-OpenSC
====================================

Yosemite 10.10 its new CryptoTokenKit -- trivial example to track card insert/query as to compare with OpenSC

Quick example -- see the view controller to track readers and cards that are (un)plugged; scan them and print some details on what is found. Including a entersafe specific serial number extraction through the normal APDU interface.

NOTE: not very careful in cleaning up dangling card references; will leak observers/card-descriptors.

