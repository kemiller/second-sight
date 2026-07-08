#!/bin/bash
# swift test wrapper for machines with Command Line Tools only (no Xcode).
#
# CLT ships Testing.framework outside the compiler's default search paths,
# and SwiftPM's synthesized test runner is compiled with
# `#if canImport(Testing)` — so the search paths must be injected from the
# command line, where they reach every compiled module. Package.swift
# settings cannot do this (they don't apply to the synthesized runner,
# which then silently runs zero tests).
set -euo pipefail
cd "$(dirname "$0")/.."

CLT_FRAMEWORKS=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
CLT_TESTING_LIBS=/Library/Developer/CommandLineTools/Library/Developer/usr/lib

if [[ -d "$CLT_FRAMEWORKS/Testing.framework" ]]; then
    exec swift test \
        -Xswiftc -F -Xswiftc "$CLT_FRAMEWORKS" \
        -Xlinker -F -Xlinker "$CLT_FRAMEWORKS" \
        -Xlinker -rpath -Xlinker "$CLT_FRAMEWORKS" \
        -Xlinker -rpath -Xlinker "$CLT_TESTING_LIBS" \
        "$@"
fi
# Full Xcode installed: no extra flags needed.
exec swift test "$@"
