defmodule Jido.Connect.Gmail.Handlers.Actions.ListHistory do
  @moduledoc false

  alias Jido.Connect.{Error, Gmail.Client}

  @max_page_size 500

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_input(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.list_history(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok, public_map(result)}
    end
  end

  defp validate_input(%{start_history_id: start_history_id} = input)
       when is_binary(start_history_id) do
    cond do
      String.trim(start_history_id) == "" ->
        invalid_start_history_id()

      Map.get(input, :page_size, 100) > @max_page_size ->
        {:error,
         Error.validation("Gmail history page size exceeds provider limit",
           reason: :invalid_history_page_size,
           details: %{max_page_size: @max_page_size}
         )}

      true ->
        :ok
    end
  end

  defp validate_input(_input), do: invalid_start_history_id()

  defp normalize_input(input) do
    input
    |> Map.put_new(:history_types, [])
    |> Map.put_new(:page_size, 100)
  end

  defp invalid_start_history_id do
    {:error,
     Error.validation("Gmail history start_history_id must be a non-empty string",
       reason: :invalid_start_history_id,
       details: %{expected: "non-empty string"}
     )}
  end

  defp fetch_client(%{gmail_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(list) when is_list(list), do: Enum.map(list, &public_map/1)

  defp public_map(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key, public_map(value)} end)

  defp public_map(value), do: value
end
