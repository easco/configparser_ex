 defmodule ConfigParser.ParseState do
    @moduledoc false

    @default_options %{
      join_continuations: :with_newline,
      overwrite_sections: true
    }

    defstruct line_number: 1,               # What line of the "file" are we parsing
          current_section: nil,             # Section that definitions go into
              last_indent: 0,               # The amount of whitespace on the last line
            continuation?: false,           # Could the line being parsed be a coninuation
                 last_key: nil,             # If this is a continuation, which key would it continue
                   result: {:ok, %{}},      # The result as it is being built.
                  options: @default_options # options used when parsing the config
    alias __MODULE__

    def default_options, do: @default_options

    def begin_section(parse_state, new_section) do
      # Create a new result, based on the old, with the new section added
      {:ok, section_map} = parse_state.result

      section_key = 
        if not parse_state.options.overwrite_sections do
          # Numbering the sections with nnn_ prefix
          section_num = Map.keys(section_map)
                        |> Enum.count()
                        |> Integer.to_string
                        |> String.pad_leading(3, "0")
          section_num<>"_"<>String.trim(new_section)
        else
          # Only add a new section if it's not already there
          String.trim(new_section)
        end

      new_result =
        if Map.has_key?(section_map, section_key) do
          # don't change the result if they section already exists
          parse_state.result
        else
          # add the section as an empty map if it doesn't exist
          {:ok, Map.put(section_map, section_key, %{}) }
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
        new_values =
          if value == nil do
            Map.put(value_map, String.trim(key), nil)
          else
            Map.put(value_map, String.trim(key), String.trim(value))
          end

        # create a new result replacing the current section with thenew values
        new_result = {:ok, Map.put(section_map, parse_state.current_section, new_values)}

        # The next line could be a continuation of this value so set continuation to true
        # and store the key that we're defining now.
        %{parse_state | result: new_result,
                 continuation?: true,
                      last_key: String.trim(key)}
      else
        new_result = {:error, "A configuration section must be defined before defining configuration values in line #{parse_state.line_number}"}
        %{parse_state | result: new_result}
      end
    end

    def append_continuation(%ParseState{options: options} = parse_state, continuation_value) do
      {:ok, section_map} = parse_state.result

      # pull the values out for the section that's currently being built
      value_map = section_map[parse_state.current_section]

      # create a new set of values by adding the key/value pair passed in
      new_value = append_continuation(options, value_map[parse_state.last_key], continuation_value)

      define_config(parse_state, parse_state.last_key, new_value)
    end

    defp append_continuation(%{join_continuations: :with_newline}, value, continuation) do 
      "#{value}\n#{continuation}"
    end

    defp append_continuation(%{join_continuations: :with_space}, value, continuation) do
      "#{value} #{continuation}"
    end
  end
