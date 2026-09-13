defmodule Jido.Connect.SafeStacktrace do
  @moduledoc false

  @spec format(list()) :: String.t()
  def format(stacktrace) when is_list(stacktrace) do
    stacktrace
    |> Enum.flat_map(&safe_frame/1)
    |> Exception.format_stacktrace()
  end

  defp safe_frame({module, function, args, location})
       when is_atom(module) and is_atom(function) and is_list(location) do
    [{module, function, arity(args), Keyword.take(location, [:file, :line])}]
  end

  defp safe_frame({module, function, args}) when is_atom(module) and is_atom(function) do
    [{module, function, arity(args), []}]
  end

  defp safe_frame(_frame), do: []

  defp arity(args) when is_list(args), do: length(args)
  defp arity(arity) when is_integer(arity) and arity >= 0, do: arity
  defp arity(_args), do: 0
end
