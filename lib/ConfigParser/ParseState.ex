 defmodule ConfigParser.ParseState do
    defstruct line_number: 1,         # What line of the "file" are we parsing
          current_section: nil,       # Section that definitions go into
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

      # next line cannot be a continuation 
      %{parse_state | current_section: section_key, 
                               result: new_result, 
                        continuation?: false,
                             last_key: nil}
    end

    def define_config(parse_state, key, value) do
      {:ok, section_map} = parse_state.result

      if parse_state.current_section != nil do
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

        # The next line could be a continuation of this value so set continuation to true
        # and store the key that we're defining now.
        %{parse_state | result: new_result, 
                 continuation?: true,
                      last_key: String.strip(key)}
      else
        new_result = {:error, "A configuration section must be defined before defining configuration values in line #{parse_state.line_number}"}
        %{parse_state | result: new_result}
      end
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