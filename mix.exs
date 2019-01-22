defmodule ConfigParser.Mixfile do
  use Mix.Project

  def project do
    [
      app: :configparser_ex,
      version: "4.0.0",
      name: "ConfigParser for Elixir",
      source_url: "https://github.com/easco/configparser_ex",
      elixir: ">= 1.7.0",
      description:
        "A module that parses INI-like files. Not unlike the Python configparser package.",
      package: package(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    []
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [{:earmark, "~> 1.3", only: :dev}, {:ex_doc, "~> 0.19", only: :dev}]
  end

  defp package do
    [
      maintainers: ["Scott Thompson"],
      files: ["mix.exs", "lib", "LICENSE*", "README*"],
      licenses: ["bsd"],
      links: %{"GitHub" => "https://github.com/easco/configparser_ex"}
    ]
  end
end
