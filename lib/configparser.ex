defmodule ConfigParser do
  alias ConfigParser.ParseState, as: ParseState

  @moduledoc """
    The ConfigParser library implements a parser for config files in the style of Windows INI,
    as parsed by the Python [configparser](https://docs.python.org/3/library/configparser.html) library.

    A note about `Mix.Config`
    ---------------------------

    This library is intended for compatibility in environments that are already
    using config files in the format described above. If you are working in a
    pure Elixir environment, please consider using `Mix.Config` instead as it is
    part of the core library and provides similar functionality.

    Basic Usage
    -----------

    The `ConfigParser` module includes routines that can parse a file, the contents of a string, or from a stream of lines.

    To parse the content of a config file call the `parse_file` function and pass the file's path:

      {:ok, parse_result} = ConfigParser.parse_file("/path/to/file")

    To parse config information out of a string, call the `parse_string` method:

      {:ok, parse_result} = ConfigParser.parse_string(\"\"\"
        [interesting_config]
        config_key = some interesting value
        \"\"\")

    Given a stream whose elements represent the successive lines of a config file, the library can parse the content of the stream:

      fake_stream = ["[section]", "key1 = value2", "key2:value2"]
        |> Stream.map(&(&1))

      {:ok, parse_result} = ConfigParser.parse_stream(fake_stream)

    As shown, the result of doing the parsing is a tuple. If successful, the first element of the tuple is `:ok` and the second element is the parsed result.

    If the parser encounters an error, then the first part of the tuple will be the atom `:error` and the second element will be a string describing the error that was encountered:

      {:error, "Syntax Error on line 3"}

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
  """

  @doc """
    Accepts `config_file_path`, a file system path to a config file.
    Attempts to opens and parses the contents of that file.
  """
  def parse_file(config_file_path, parser_options \\ []) do
    file_stream = File.stream!(config_file_path, [], :line)
    parse_stream(file_stream, parser_options)
  end

  @doc """
    Parse a string as if it was the content of a config file.
  """
  def parse_string(config_string, parser_options \\ []) do
    {:ok, result} = StringIO.open(config_string, fn io_device ->
      line_stream = IO.stream(io_device, :line)
      parse_stream(line_stream, parser_options)
    end)

    result
  end

  @doc """
    Parses a stream whose elements should be strings representing the
    individual lines of a config file.
  """
  def parse_stream(line_stream, parser_options \\ []) do
    options_map = options_to_map(parser_options)

    result =
      with {:ok, ^options_map} <- validate_options(options_map) do
        %ParseState{result: parse_result} =
          Enum.reduce(line_stream, %ParseState{options: options_map}, &parse_line/2)

        parse_result
      else
        error -> error
      end

    result
  end

  @doc """
    Return a list of sections in the given config parser state
  """
  def sections(parser_results) do
    Map.keys(parser_results)
  end

  @doc """
    Returns `true` if the named section is found in the config parser results
  """
  def has_section?(parser_results, which_section) do
    nil != Enum.find(sections(parser_results), &(&1 == which_section))
  end

  @doc """
    Returns a List with the options, the keys, defined in the given section. If the
    section is not found, returns an empty List
  """
  def options(parser_results, in_section) do
    if has_section?(parser_results, in_section) do
      Map.keys(parser_results[in_section])
    else
      nil
    end
  end

  @doc """
    Return the value for the configuration option with the given `key`.

    You can change the way values are looked up using the `search_options` map.
    The following keys are recognized:

    * `:raw` - reserved for future enhancements
    * `:vars` - a map of keys and values.
    * `:fallback` - a value to return if the option given by `key` is not found

    The routine searches for a value with the given `key` in the `:vars` map
    if provided, then in the given section from the parse result.

    If no value is found, and the `options` map has a `:fallback` key, the
    value associated with that key will be returned.

    If all else fails, the routine returns `nil`
  """
  def get(parser_results, section, key, search_options \\ %{}) do
    cond do
      search_options[:vars] && Map.has_key?(search_options[:vars], key) ->
        search_options[:vars][key]

      has_option?(parser_results, section, key) ->
        parser_results[section][key]

      search_options[:fallback] ->
        search_options[:fallback]

      true ->
        nil
    end
  end

  @doc """
    This is a convenience routine which calls `ConfigParser.get`
    then tries to construct a integer value from the result.

    See `ConfigParser.get` for explanations of the options.
  """
  def getint(parser_results, section, key, search_options \\ %{}) do
    value = get(parser_results, section, key, search_options)

    if is_binary(value) do
      String.to_integer(value)
    else
      value
    end
  end

  @doc """
    This is a convenience routine which calls `ConfigParser.get`
    then tries to construct a float value from the result.

    See `ConfigParser.get` for explanations of the options.
  """
  def getfloat(parser_results, section, key, search_options \\ %{}) do
    value = get(parser_results, section, key, search_options)

    if is_binary(value) do
      String.to_float(value)
    else
      value
    end
  end

  @doc """
    This is a convenience routine which calls `ConfigParser.get`
    then tries to construct a boolean value from the result.

    An option value of "true", "1", "yes", or "on" evaluates to true
    An options value of "false", "0", "no", or "off" evaluates to false

    See `ConfigParser.get` for explanations of the options.
  """
  def getboolean(parser_results, section, key, search_options \\ %{}) do
    string_value = get(parser_results, section, key, search_options)

    case String.downcase(string_value) do
      "true" ->
        true

      "1" ->
        true

      "yes" ->
        true

      "on" ->
        true

      "false" ->
        false

      "0" ->
        false

      "no" ->
        false

      "off" ->
        false

      _ ->
        raise RuntimeError,
          message: "ConfigParser.getboolean tried to convert an unexpected value #{string_value}"
    end
  end

  @doc """
    returns true if the parse results define the given option in the
    section provided
  """
  def has_option?(parser_results, section, option) do
    potential_options = options(parser_results, section)

    if nil != potential_options do
      nil != Enum.find(potential_options, &(&1 == option))
    else
      false
    end
  end

  # If the parse state indicates an error we simply skip over lines and propagate
  # the error.
  defp parse_line(_line, parse_state = %ParseState{result: {:error, _error_string}}) do
    parse_state
  end

  @section_regex ~r{\[([^\]]+)\]}
  @equals_definition_regex ~r{([^=]+)=(.*)}
  @colon_definition_regex ~r{([^:]+):(.*)}
  @value_like_regex ~r{\s*(\S.*)}

  # Parse a line while the parse state indicates we're in a good state
  defp parse_line(line, parse_state = %ParseState{result: {:ok, _}}) do
    line = strip_inline_comments(line)

    # find out how many whitespace characters are on the front of the line
    indent_level = indent_level(line)

    if parse_state.continuation? && indent_level > parse_state.last_indent &&
         Regex.run(@value_like_regex, line) do
      # note that we do not increase the "last indent"
      %{
        ParseState.append_continuation(parse_state, String.trim(line))
        | line_number: parse_state.line_number + 1,
          continuation?: true
      }
    else
      cond do
        # if we can skip this line (it's empty or a comment) then simply advance the line number
        # and note that the next line can't be a continuation
        can_skip_line(line) ->
          %{
            parse_state
            | line_number: parse_state.line_number + 1,
              continuation?: false,
              last_indent: indent_level
          }

        # match a line that begins a new section like "[new_section]"
        match = Regex.run(@section_regex, line) ->
          [_, new_section] = match

          %{
            ParseState.begin_section(parse_state, new_section)
            | line_number: parse_state.line_number + 1,
              last_indent: indent_level
          }

        # match a line that defines a value "key = value"
        match = Regex.run(@equals_definition_regex, line) ->
          [_, key, value] = match

          %{
            ParseState.define_config(parse_state, key, value)
            | line_number: parse_state.line_number + 1,
              last_indent: indent_level
          }

        # match a line that defines a value "key : value"
        match = Regex.run(@colon_definition_regex, line) ->
          [_, key, value] = match

          %{
            ParseState.define_config(parse_state, key, value)
            | line_number: parse_state.line_number + 1,
              last_indent: indent_level
          }

        # when there's a value-ish line that on a line by itself, but which is not a continuation
        # then it actually represents a key that has no associated value (or a value of nil)
        match = Regex.run(@value_like_regex, line) ->
          [_, key] = match

          %{
            ParseState.define_config(parse_state, key, nil)
            | continuation?: false,
              line_number: parse_state.line_number + 1,
              last_indent: indent_level
          }

        # Any non-matching lines result in a syntax error
        true ->
          %{parse_state | result: {:error, "Syntax Error on line #{parse_state.line_number}"}}
      end

      # cond
    end

    # continuation if
  end

  # Calculate how much whitespace is at the front of the given
  # line.
  defp indent_level(line) do
    [_whole, spaces | _rest] = Regex.run(~r{(\s*).*}, line)
    spaces = String.replace(spaces, "\t", "  ")
    String.length(spaces)
  end

  # Returns true if the parser can ignore the line passed in.
  # this is done if the line is a comment just whitespace
  defp can_skip_line(line) do
    is_comment(line) || is_empty(line)
  end

  # Returns true if the line appears to be a comment
  @hash_comment_regex ~r{^#.*}
  @semicolon_comment_regex ~r{^;.*}

  defp is_comment(line) do
    String.trim(line) =~ @hash_comment_regex || String.trim(line) =~ @semicolon_comment_regex
  end

  # returns true if the line contains only whitespace
  defp is_empty(line) do
    String.trim(line) == ""
  end

  # semicolons on a line define the start of a comment.
  # this removes the semicolon and anything following it.
  defp strip_inline_comments(line) do
    line_list = String.split(line, ";")
    List.first(line_list)
  end

  defp options_to_map([]), do: ParseState.default_options()
  defp options_to_map(options) when is_list(options), do: Map.merge(ParseState.default_options(), Enum.into(options , %{}))

  defp validate_options(%{} = options_map) do
    Enum.reduce(options_map, {:ok, options_map}, &option_reducer/2)
  end

  # validate an individual option pair when all prior options have been valid
  defp option_reducer(pair, {:ok, %{}} = result) do
    with {:ok, ^pair} <- validate_option(pair) do
      result
    else
      {:error, option_error} -> {:error, [option_error]}
    end
  end

  # validate an individual option pair when an error has already been encountered
  # accumulates a list of errors
  defp option_reducer(pair, {:error, errors_list} = result) do
    with {:ok, ^pair} <- validate_option(pair) do
      result
    else
      {:error, option_error} -> {:error, [option_error | errors_list]}
    end
  end

  defp validate_option({:overwrite_sections, value} = pair) do
    if is_boolean(value) do
      {:ok, pair}
    else
      {:error,
       "The value for the overwrite_sections option should be true or false"}
    end
  end

  defp validate_option({:join_continuations, value} = pair) do
    if value == :with_newline || value == :with_space do
      {:ok, pair}
    else
      {:error,
       "The value for the join_continuations option should be :with_newline or :with_space"}
    end
  end

  defp validate_option({option_key, _}) do
    {:error, "The ConfigParser library does not recognize the option #{inspect(option_key)}."}
  end
end
