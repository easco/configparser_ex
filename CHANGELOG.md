# Changelog

## 4.0.0

Changed the way that strings get parsed to use new functionality
(added in Elixir 1.7) where `StringIO.open` can accept a function for working
with the device that is automatically closed when the function completes. Since
this changes the minimum Elixir version this is a major version release.

## 3.0.1

Fixed compiler warnings for Elixir 1.7.1 and later

## 3.0.0

This represents a significant change for multi-line values.  Prior to
version 3, the parser would join multi-line values using a single space.  The
Python ConfigParser library, in contrast, joins them with a newline.  This
version joins the lines of a multi-line value with a newline like Python does.
It also adds parser options, in particular the `join_continuations` option,
which should allow users to continue using a space if desired.

## 2.0.1

When parsing from a string, the library opened a `StringIO` device which
it never closed.  This release fixes the problem.  Thanks to @vietkungfu on
GitHub.

## 2.0.0

Replaced calls to deprecated String.strip with String.trim.  Makes
minimum Elixir Version 1.3.  If you need to run on versions prior to 1.3 you
can use the 1.0.0 version.  Bumped the major version as this may be a breaking
change for some folks.

## 1.0.0

Changed the way comments were parsed to make it more compatible with
other libraries

## 0.2.1

Small code changes to address a compiler warning from Elixir 1.2.3

## 0.2.0

Identical releases caused by author's inexperience with Hex

## 0.1.0

Initial release
