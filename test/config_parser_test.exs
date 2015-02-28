defmodule ConfigParserTest do
  use ExUnit.Case

  test "parses an empty file" do
    {:ok, pid} = StringIO.open("")
    line_stream = IO.stream(pid, :line)

    assert {:ok, %{}} == ConfigParser.parse_stream(line_stream)
  end

  test "parses an comment only file" do
    {:ok, pid} = StringIO.open("#this is a useless file\n")
    line_stream = IO.stream(pid, :line)

    assert {:ok, %{}} == ConfigParser.parse_stream(line_stream)
  end

  test "parses comments and empty lines" do
    {:ok, pid} = StringIO.open("""
      #this is a useless file

        # filled with comments and empty lines
      """)
    line_stream = IO.stream(pid, :line)

    assert {:ok, %{}} == ConfigParser.parse_stream(line_stream)
  end

  test "parses a single section" do
    {:ok, pid} = StringIO.open("[section]\n")
    line_stream = IO.stream(pid, :line)

    assert {:ok, %{"section" => %{}}} == ConfigParser.parse_stream(line_stream)
  end

  test "parses a section name with a space" do
    {:ok, pid} = StringIO.open("[section with space]\n")
    line_stream = IO.stream(pid, :line)

    assert {:ok, %{"section with space" => %{}}} == ConfigParser.parse_stream(line_stream)
  end

  test "parses a config option into a section" do
    {:ok, pid} = StringIO.open("""
      [section]
      # this is an interesting key value pair
      key = value
      """)
    line_stream = IO.stream(pid, :line)

    assert {:ok, %{"section" => %{"key" => "value"}}} == ConfigParser.parse_stream(line_stream)
  end

  test "allows spaces in the keys" do
    {:ok, pid} = StringIO.open("""
      [section]
      # this is an interesting key value pair
      spaces in keys=allowed
      """)
    line_stream = IO.stream(pid, :line)

    assert {:ok, %{"section" => %{"spaces in keys" => "allowed"}}} == ConfigParser.parse_stream(line_stream)
  end

  test "allows spaces in the values" do
    {:ok, pid} = StringIO.open("""
      [section]
      # this is an interesting key value pair
      spaces in values=allowed as well
      """)
    line_stream = IO.stream(pid, :line)

    assert {:ok, %{"section" => %{"spaces in values" => "allowed as well"}}} == ConfigParser.parse_stream(line_stream)
  end

  test "allows spaces around the delimiter" do
    {:ok, pid} = StringIO.open("""
      [section]
      # this is an interesting key value pair
      spaces around the delimiter = obviously
      """)
    line_stream = IO.stream(pid, :line)

    assert {:ok, %{"section" => %{"spaces around the delimiter" => "obviously"}}} == ConfigParser.parse_stream(line_stream)
  end

  test "allows a colon as the delimiter" do
    {:ok, pid} = StringIO.open("""
      [section]
      # this is an interesting key value pair
      you can also use : to delimit keys from values
      """)
    line_stream = IO.stream(pid, :line)

    assert {:ok, %{"section" => %{"you can also use" => "to delimit keys from values"}}} == ConfigParser.parse_stream(line_stream)
  end

  test "allows a continuation line" do
    {:ok, pid} = StringIO.open("""
      [section]
      you can also use : to delimit keys from values
          and add a continuation
      """)
    line_stream = IO.stream(pid, :line)

    assert {:ok, %{"section" => %{"you can also use" => "to delimit keys from values and add a continuation"}}} == ConfigParser.parse_stream(line_stream)
  end

  test "allows a multi-line continuation" do
    {:ok, pid} = StringIO.open("""
      [section]
      you can also use : to delimit keys 
          from values
          and add a continuation
      """)
    line_stream = IO.stream(pid, :line)

    assert {:ok, %{"section" => %{"you can also use" => "to delimit keys from values and add a continuation"}}} == ConfigParser.parse_stream(line_stream)
  end

  test "allows empty string thing" do
    {:ok, pid} = StringIO.open("""
      [No Values]
      empty string value here =
      """)
    line_stream = IO.stream(pid, :line)

    assert {:ok, %{"No Values" => %{"empty string value here" => ""}}} == ConfigParser.parse_stream(line_stream)
  end

  test "allows lone keys" do
    {:ok, pid} = StringIO.open("""
      [No Values]
      key_without_value
      """)
    line_stream = IO.stream(pid, :line)

    assert {:ok, %{"No Values" => %{"key_without_value" => nil}}} == ConfigParser.parse_stream(line_stream)
  end

  test "parses a config option with an inline comment" do
    {:ok, pid} = StringIO.open("""
      [section]
      # this is an interesting key value pair
      key = value ; With a comment
      """)
    line_stream = IO.stream(pid, :line)

    assert {:ok, %{"section" => %{"key" => "value"}}} == ConfigParser.parse_stream(line_stream)
  end

  test "lines starting with a hash are comments" do
    assert true == ConfigParser.is_comment "# this is a comment\n"
    assert true == ConfigParser.is_comment "   # this is a comment\n"
    assert true == ConfigParser.is_comment "#\n"
  end

  test "lines starting with a semicolon are comments" do
    assert true == ConfigParser.is_comment "; this is a comment\n"
    assert true == ConfigParser.is_comment "   ; this is a comment\n"
    assert true == ConfigParser.is_comment ";\n"
  end

  test "determines when a line is empty" do
    assert true == ConfigParser.is_empty("")
    assert true == ConfigParser.is_empty("\n")
    assert true == ConfigParser.is_empty(" \n")
    assert true == ConfigParser.is_empty(" \n ")
    assert true == ConfigParser.is_empty("\t")
  end

  test "knows that empty and comment lines can be skipped" do
    assert true == ConfigParser.can_skip_line(" \n")
    assert true == ConfigParser.can_skip_line "# this is a comment\n"
    assert true == ConfigParser.can_skip_line "; this is a comment\n"
  end

  test "parses extended example from python page" do
    {:ok, pid} = StringIO.open("""
      [Simple Values]
      key=value
      spaces in keys=allowed
      spaces in values=allowed as well
      spaces around the delimiter = obviously
      you can also use : to delimit keys from values

      [All Values Are Strings]
      values like this: 1000000
      or this: 3.14159265359
      are they treated as numbers? : no
      integers, floats and booleans are held as: strings
      can use the API to get converted values directly: true

      [Multiline Values]
      chorus: I'm a lumberjack, and I'm okay,
          I sleep all night and I work all day

      [No Values]
      key_without_value
      empty string value here =

      [You can use comments]
      # like this
      ; or this

      # By default only in an empty line.
      # Inline comments can be harmful because they prevent users
      # from using the delimiting characters as parts of values.
      # That being said, this can be customized.

          [Sections Can Be Indented]
              can_values_be_as_well = True
              does_that_mean_anything_special = False
              purpose = formatting for readability
              multiline_values = are
                  handled just fine as
                  long as they are indented
                  deeper than the first line
                  of a value
              # Did I mention we can indent comments, too?
      """)
    line_stream = IO.stream(pid, :line)

    assert ConfigParser.parse_stream(line_stream) == {:ok, %{"All Values Are Strings" => %{"are they treated as numbers?" => "no",
     "can use the API to get converted values directly" => "true",
     "integers, floats and booleans are held as" => "strings",
     "or this" => "3.14159265359", "values like this" => "1000000"},
   "Multiline Values" => %{"chorus" => "I'm a lumberjack, and I'm okay, I sleep all night and I work all day"},
   "No Values" => %{"empty string value here" => "",
     "key_without_value" => nil},
   "Sections Can Be Indented" => %{"can_values_be_as_well" => "True",
     "does_that_mean_anything_special" => "False",
     "multiline_values" => "are handled just fine as long as they are indented deeper than the first line of a value",
     "purpose" => "formatting for readability"},
   "Simple Values" => %{"key" => "value",
     "spaces around the delimiter" => "obviously",
     "spaces in keys" => "allowed", "spaces in values" => "allowed as well",
     "you can also use" => "to delimit keys from values"},
   "You can use comments" => %{}}}

  end
end
