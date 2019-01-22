ConfigParser
============
[![BuildStatus](https://travis-ci.org/easco/configparser_ex.svg?branch=master)](https://travis-ci.org/easco/configparser_ex)

This library implements a parser for config files in the style of Windows INI, as parsed by the Python [configparser](https://docs.python.org/3/library/configparser.html) library.

---

### A note about Mix.Config

This library is intended for compatibility in environments that are already
using files in the `configparser` format. For most uses in Elixir, consider
using `Mix.Config` instead as it is part of the core library and provides
similar functionality.

---

> **Release Notes**
>
> Starting with Version 3.0, the way the library handles multi-line values has
> changed! Prior versions of the library would join multi-line values with a
> single space. Now it joins them with a newline character. This change
> replicates the behavior of the Python ConfigParser library.
> The release now includes parser options and the `join_continuations` option
> with the value `:with_space` will revert the library to its prior behavior.

---

Basic config files look like this:

```
# Comments can be placed in the file on lines with a hash
[config section]

first_key = value
second_key = another_value
```
The file shown in this sample defines a section called `config section` and then defines two config settings in key-value form.  The result of parsing this file would be:

```
{:ok,
 %{"config section" => %{"first_key" => "value",
     "second_key" => "another_value"}}}
```

The `:ok` atom in the first part of the tuple indicates that parsing was successful.  The map in the second part of the tuple has keys that are the sections created in the file and the values are themselves value maps.  The value maps reflect the keys and values defined within that section.

Config Definitions
------------------

A section definition is simply the name of the section enclosed in square brackets `[like this]`.  Section names can contain spaces.

Within a section, configuration definitions are key value pairs.  On a definition line, the key and value are separated by either a colon (:) or an equal sign (=):

```
[key-value samples]
key_defined = with_an_equal_sign
another_key_defined : with_a_colon
keys can have spaces : true
values = can have spaces too
```
The value of a particular key can extend over more than one line.  The follow-on lines must be indented farther than the first line.

```
[multi-line sample]
this key's value : continues on more than one line
    but the follow on lines must be indented
    farther than the original one.
```

It is possible to define keys with values that are either null or the empty string:

```
[empty-ish values]
this_key_has_a_nil_value
this_key_has_the_empty_string_as_a_value =
```

Comments
-----------

The config file can contain comments:

```
# comments can begin with a hash or number sign a the beginning
; or a comment line can begin with a semicolon

[comment section]
when defining a key = this is the value ; a comment starting with a semicolon
```

Using the Parser
----------------

The `ConfigParser` module includes routines that can parse a file, the contents of a string, or from a stream of lines.

To parse the content of a config file call the `parse_file` function and pass the file's path:

```
  {:ok, parse_result} = ConfigParser.parse_file("/path/to/file")
```

To parse config information out of a string, call the `parse_string` method:

```
  {:ok, parse_result} = ConfigParser.parse_string("""
    [interesting_config]
    config_key = some interesting value
    """)
```

Given a stream whose elements represent the successive lines of a config file, the library can parse the content of the stream:

```
fake_stream = ["[section]", "key1 = value2", "key2:value2"] |> Stream.map(&(&1))
{:ok, parse_result} = ConfigParser.parse_stream(fake_stream)
```

As mentioned previously the result of doing the parsing is a tuple.  If successful, the first element of the tuple is `:ok` and the second element is the parsed result.

If the parser encounters an error, then the first part of the tuple will be the atom `:error` and the second element will be a string describing the error that was encountered:

```
{:error, "Syntax Error on line 3"}
```
    ---

Parser Options
--------------

Starting with Version 3 of the library, it is possible to pass options to the parser:

|  Option              | Value            | Effect |
|----------------------|-----------------|--------------------------------------------------------------------------------------------------------------------------------------|
| `join_continuations` | `:with_newline` | The parser joins the lines of multi-line values with a newline. This is the default and matches the behavior of Python ConfigParser. |
| `join_continuations` | `:with_space`   | The parser joins the lines of multi-line values with a space. This is the default behavior of the library prior to version 3.        |

You may add options as keyword arguments to the end of the `parse_file`, `parse_string`, or `parse_stream` functions

    {:ok, parse_result} = ConfigParser.parse_file("/path/to/file", join_continuations: :with_newline)


Not Implemented
---------------

This library is primarily intended to provide backward-compatibility in environments that already use config files. It does not handle creating, manipulating, or writing config files.  It treats config files as read-only entities.

This library currently returns the parsed result as a raw data structure.

It does not support the value interpolation in the Python library and does not implement the DEFAULT section as described in the Python documentation.

This library does not support the Python ConfigParser's customization features.