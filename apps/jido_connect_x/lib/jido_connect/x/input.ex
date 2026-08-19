defmodule Jido.Connect.X.Input do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.X.Contract

  def validate("x.account.get", input) do
    with :ok <- strict(input, []) do
      {:ok, %{}}
    end
  end

  def validate("x.bookmark.list", input), do: paged(input, 20, 1)
  def validate("x.post.list", input), do: paged(input, 5, 5)
  def validate(_action, _input), do: invalid(:action)

  defp paged(input, default, minimum) do
    with :ok <- strict(input, [:max_results, :pagination_token]),
         max_results = Data.get(input, :max_results, default),
         pagination_token = Data.get(input, :pagination_token),
         :ok <- integer(max_results, minimum, 100, :max_results),
         :ok <- optional_token(pagination_token) do
      {:ok, %{max_results: max_results, pagination_token: pagination_token}}
    end
  end

  defp strict(input, allowed) when is_map(input) do
    allowed = MapSet.new(Enum.map(allowed, &to_string/1))
    normalized_keys = Enum.map(Map.keys(input), &to_string/1)

    cond do
      length(normalized_keys) != length(Enum.uniq(normalized_keys)) -> invalid(:duplicate_field)
      Enum.all?(normalized_keys, &MapSet.member?(allowed, &1)) -> :ok
      true -> invalid(:unknown_field)
    end
  end

  defp strict(_input, _allowed), do: invalid(:input)

  defp integer(value, minimum, maximum, _field)
       when is_integer(value) and value >= minimum and value <= maximum,
       do: :ok

  defp integer(_value, _minimum, _maximum, field), do: invalid(field)

  defp optional_token(nil), do: :ok

  defp optional_token(value) when is_binary(value) do
    if String.length(value) in 1..Contract.pagination_token_max(),
      do: :ok,
      else: invalid(:pagination_token)
  end

  defp optional_token(_value), do: invalid(:pagination_token)

  defp invalid(field) do
    {:error,
     Error.validation("Invalid X action input",
       reason: :invalid_x_input,
       subject: field,
       details: %{field: field}
     )}
  end
end
