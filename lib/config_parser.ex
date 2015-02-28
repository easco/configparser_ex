defmodule ConfigParser do
  defmodule ParseState do
    defstruct line_number: 1,         # What line of the "file" are we parsing
          current_section: :default,  # Section that definitions go into
              last_indent: 0,         # The amount of whitespace on the last line
            continuation?: false,     # Could the line being parsed be a coninuation
                 last_key: nil,       # If this is a continuation, which key would it continue
                   result: {:ok, %{}} # The result as it is being built.

    def begin_section(parse_state, new_section) do
      # Create a new result, based on the old, with the new section added
      {:ok, section_map} = parse_state.result

      # Only add a new section if it's not already there
      section_key = String.strip(new_section)
      unless Map.has_key?(section_map, section_key) do
        new_result = {:ok, Map.put(section_map, section_key, %{}) }
      end

      %{parse_state | current_section: section_key, 
                               result: new_result, 
                        continuation?: false,
                             last_key: nil}
    end

    def define_config(parse_state, key, value) do
      {:ok, section_map} = parse_state.result

      # pull the values out for the section that's currently being built
      value_map = section_map[parse_state.current_section]

      # create a new set of values by adding the key/value pair passed in
      if value == nil do
        new_values = Map.put(value_map, String.strip(key), nil)
      else
        new_values = Map.put(value_map, String.strip(key), String.strip(value))
      end

      # create a new result replacing the current section with thenew values
      new_result = {:ok, Map.put(section_map, parse_state.current_section, new_values)}

      %{parse_state | result: new_result, 
               continuation?: true,
                    last_key: String.strip(key)}
    end

    def append_continuation(parse_state, continuation_value) do
      {:ok, section_map} = parse_state.result

      # pull the values out for the section that's currently being built
      value_map = section_map[parse_state.current_section]

      # create a new set of values by adding the key/value pair passed in
      new_value = "#{value_map[parse_state.last_key]} #{continuation_value}"

      define_config(parse_state, parse_state.last_key, new_value)
    end
  end

  @hash_comment_regex ~r{#.*}
  @semicolon_comment_regex ~r{;.*}
  @section_regex ~r{\[([\w\s]+)\]}
  
  @equals_definition_regex ~r{([^=]+)=(.*)}
  @colon_definition_regex ~r{([^:]+):(.*)}

  @value_like_regex ~r{\s*(\S.*)}

  # If the parse state indicates an error we simply skip over lines and propogate
  # the error.
  def parse_line(_line, parse_state = %ParseState{result: {:error, _error_string}}) do
    parse_state
  end

  # Parse a line while the parse state indicates we're in a good state
  def parse_line(line, parse_state = %ParseState{result: {:ok, _}}) do
    line = strip_inline_comments(line)

    # find out how many whitespace characters are on the front of the line
    indent_level = indent_level(line)

    if parse_state.continuation? 
       && indent_level > parse_state.last_indent
       && (match = Regex.run(@value_like_regex, line)) do

      # note that we do not increase the "last indent"
      %{ParseState.append_continuation(parse_state, String.strip(line)) | line_number: parse_state.line_number + 1, continuation?: true}
    else
      cond do
        # if we can skip this line (it's empty or a comment) then simply advance the line number
        # and note that the next line can't be a continuation
        can_skip_line(line) ->
          %{parse_state | line_number: parse_state.line_number + 1, continuation?: false, last_indent: indent_level}

        # match a line that begins a new section like "[new_section]"
        match = Regex.run(@section_regex, line) ->
          [_, new_section] = match
          %{ParseState.begin_section(parse_state, new_section) | line_number: parse_state.line_number + 1 , last_indent: indent_level}

        # match a line that defines a value "key = value"
        match = Regex.run(@equals_definition_regex, line) ->
          [_, key, value] = match
          %{ParseState.define_config(parse_state, key, value) | line_number: parse_state.line_number + 1, last_indent: indent_level}

        # match a line that defines a value "key : value"
        match = Regex.run(@colon_definition_regex, line) ->
          [_, key, value] = match
          %{ParseState.define_config(parse_state, key, value) | line_number: parse_state.line_number + 1, last_indent: indent_level}

        match = Regex.run(@value_like_regex, line) ->
          [_, key] = match
          %{ParseState.define_config(parse_state, key, nil) | continuation?: false, line_number: parse_state.line_number + 1, last_indent: indent_level}

        # match a line that is just "value-ish"
        # Any non-matching lines result in a syntax error
        true ->
          %{parse_state | result: {:error, "Syntax Error on line #{parse_state.line_number}"}}
      end # cond
    end # continuation if
  end

  def parse(config_file_path) do
    file_stream = File.stream!(config_file_path, [], :line)
    parse_stream(file_stream)
  end

  def parse_stream(line_stream) do
    %ParseState{result: result} = Enum.reduce(line_stream, %ParseState{}, &parse_line/2)
    result
  end

  def indent_level(line) do
    [_whole, spaces | _rest] = Regex.run(~r{(\s*).*}, line)
    spaces = String.replace(spaces, "\t", "  ")
    String.length(spaces)
  end

  def can_skip_line(line) do
    is_comment(line) || is_empty(line)
  end

  def is_comment(line) do
    String.strip(line) =~ @hash_comment_regex || String.strip(line) =~ @semicolon_comment_regex
  end

  def is_empty(line) do
    String.strip(line) == ""
  end

  def strip_inline_comments(line) do
    line_list = String.split(line, ";")
    List.first(line_list)
  end
end
