defmodule ConfigParser.ParseState do
  @moduledoc false

  @default_options %{
    join_continuations: :with_newline
  }

  # What line of the "file" are we parsing
  defstruct line_number: 1,
            # Section that definitions go into
            current_section: nil,
            # The amount of whitespace on the last line
            last_indent: 0,
            # Could the line being parsed be a continuation
            continuation?: false,
            # If this is a continuation, which key would it continue
            last_key: nil,
            # The result as it is being built.
            result: {:ok, %{}},
            # options used when parsing the config
            options: @default_options

  alias __MODULE__

  def default_options, do: @default_options

  def begin_section(parse_state, new_section) do
    # Create a new result, based on the old, with the new section added
    {:ok, section_map} = parse_state.result

    # Only add a new section if it's not already there
    section_key = String.trim(new_section)

    new_result =
      if Map.has_key?(section_map, section_key) do
        # don't change the result if they section already exists
        parse_state.result
      else
        # add the section as an empty map if it doesn't exist
        {:ok, Map.put(section_map, section_key, %{})}
      end

    # next line cannot be a continuation
    %{
      parse_state
      | current_section: section_key,
        result: new_result,
        continuation?: false,
        last_key: nil
    }
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
      %{parse_state | result: new_result, continuation?: true, last_key: String.trim(key)}
    else
      new_result =
        {:error,
         "A configuration section must be defined before defining configuration values in line #{parse_state.line_number}"}

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
