defmodule Entice.Utils.Mixfile do
  use Mix.Project

  def project do
    [app: :entice_utils,
     version: "0.0.1",
     elixir: "~> 1.2",
     deps: deps]
  end

  defp deps do
    [{:inflex, "~> 1.5"}]
  end
end
