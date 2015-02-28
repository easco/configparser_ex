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

    assert {:ok, %{section: %{}}} == ConfigParser.parse_stream(line_stream)
  end

  test "parses a config option into a section" do
    {:ok, pid} = StringIO.open("""
      [section]
      # this is an interesting key value pair
      key = value
      """)
    line_stream = IO.stream(pid, :line)

    assert {:ok, %{section: %{"key" => "value"}}} == ConfigParser.parse_stream(line_stream)
  end

  test "recognizes syntax error" do
    {:ok, pid} = StringIO.open("""
      [section]
      # this is an interesting key value pair
      this is a bad line
      key = value
      """)
    line_stream = IO.stream(pid, :line)

    assert {:error, "Syntax Error on line 3"} == ConfigParser.parse_stream(line_stream)
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
end
