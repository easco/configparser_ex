defmodule ConfigParser do
  defmodule ParseState do
    defstruct line_number: 1, current_section: :default, result: {:ok, %{}}

    def begin_section(parse_state, new_section) do
      # Create a new result, based on the old, with the new section added
      {:ok, section_map} = parse_state.result

      # Only add a new section if it's not already there
      section_atom = String.to_atom(new_section)
      unless Map.has_key?(section_map, section_atom) do
        new_result = {:ok, Map.put(section_map, section_atom, %{}) }
      end

      %ParseState{current_section: section_atom, result: new_result}
    end

    def define_config(parse_state, key, value) do
      {:ok, section_map} = parse_state.result

      # pull the values out for the section that's currently being built
      value_map = section_map[parse_state.current_section]

      # create a new set of values by adding the key/value pair passed in
      new_values = Map.put(value_map, key, value)

      # create a new result replacing the current section with thenew values
      new_result = {:ok, Map.put(section_map, parse_state.current_section, new_values)}

      %{parse_state | result: new_result}
    end
  end

  @hash_comment_regex ~r/#.*/
  @semicolon_comment_regex ~r/;.*/
  @section_regex ~r/\[(\w+)\]/
  @definition_regex ~r/(\w+)\s*=\s*(\w+)/

  # If the parse state indicates an error we simply skip over lines and propogate
  # the error.
  def parse_line(_line, parse_state = %ParseState{result: {:error, _error_string}}) do
    parse_state
  end

  # Parse a line while the parse state indicates we're in a good state
  def parse_line(line, parse_state = %ParseState{result: {:ok, _}}) do
    cond do
      # if we can skip this line (it's empty or a comment) then simply advance the line number
      can_skip_line(line) ->
        %{parse_state | line_number: parse_state.line_number + 1}

      # match a line that begins a new section like "[new_section]"
      match = Regex.run(@section_regex, line) ->
        [_, new_section] = match
        %{ParseState.begin_section(parse_state, new_section) | line_number: parse_state.line_number + 1}

      # match a line that defines a value "key = value"
      match = Regex.run(@definition_regex, line) ->
        [_, key, value] = match
        %{ParseState.define_config(parse_state, key, value) | line_number: parse_state.line_number + 1}

      # Any non-matching lines result in a syntax error
      true ->
        %{parse_state | result: {:error, "Syntax Error on line #{parse_state.line_number}"}}
    end
  end

  def parse(config_file_path) do
    file_stream = File.stream!(config_file_path, [], :line)
    parse_stream(file_stream)
  end

  def parse_stream(line_stream) do
    %ParseState{result: result} = Enum.reduce(line_stream, %ParseState{}, &parse_line/2)
    result
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
end
