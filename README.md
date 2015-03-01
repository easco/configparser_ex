ConfigParser
============

This library implements a parser for config files in the style of Windows INI, as parsed by the Python [configparser](https://docs.python.org/3/library/configparser.html) library.

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

The `:ok` atom in the frst part of the tuple indicates that parsing was successful.  The map in the second part of the tuple has keys that are the sections created in the file and the values are themselves value maps.  The value maps reflect the keys and values defined within that section.

Config Definitions
------------------



