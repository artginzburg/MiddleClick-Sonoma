#!/bin/sh

# Replaces all occurrences of `[[Class alloc] init]` with `[Class new]` in a file, `Class` being an arbitrary class name.

# Change `-i ''` to `-i.bak` after `sed` to make backup files.

sed -i '' -E 's/\[\[([A-Za-z_]+) +alloc\] +init\]/[\1 new]/g' ./MiddleClick/*.m
