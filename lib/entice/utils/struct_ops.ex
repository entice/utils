defmodule Entice.Utils.StructOps do
  import Inflex

  @doc """
  Takes a struct and copies the values of all matching keys
  of a second struct into it.
  """
  def copy_into(%{__struct__: result} = a, %{__struct__: _} = b),
  do: struct(result, Dict.merge(Map.from_struct(a), Map.from_struct(b)))


  @doc """
  Takes a struct and returns the last atom of its name.
  """
  def to_name(%{__struct__: name}),
  do: Module.split(name) |> List.last |> to_string


  @doc """
  Takes a struct and returns the last atom of it as a snake cased string.
  """
  def to_underscore_name(%{__struct__: _} = struct),
  do: struct |> to_name |> underscore
end
