CommonMark.swift
================

A CommonMark-compliant markdown renderer written in Swift.

- It is a port of stmd.js with a slow move towards Swiftisms. (Pattern matching!)
- I've only tested in in Xcode6.1β.
- It is currently about **65 TIMES SLOWER** than the JavaScript reference
  implementation.

  Literally 65 times slower.  This thing spends more 25% of its time in
  `_swift_release_` and `_swift_retain_`, and rediculous amounds of time in
  `objc_msgSend`, `icu::RegexMatcher::MatchAt`,
  `OSAtomicCompareAndSwapPtrBarrier$VARIANT$mp`, and some others.  There are 11
  low level functions that flat out take longer than stmd.js.  Diving deeper, I
  spend more time releasing references to `Swift.Character` than stmd.js spends
  parsing a document.

  There are probably areas where I can do better, the regex engine can do
  better, the compiler can do better, etc. Right now though, man it's slow.
