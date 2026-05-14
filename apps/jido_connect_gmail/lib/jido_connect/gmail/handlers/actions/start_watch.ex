defmodule Jido.Connect.Gmail.Handlers.Actions.StartWatch do
  @moduledoc false

  alias Jido.Connect.{Error, Gmail.Client}

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_input(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, watch} <-
           client.start_watch(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok, %{watch: public_map(watch)}}
    end
  end

  defp validate_input(%{topic_name: topic_name}) when is_binary(topic_name) do
    if String.trim(topic_name) == "" do
      invalid_topic_name()
    else
      :ok
    end
  end

  defp validate_input(_input), do: invalid_topic_name()

  defp normalize_input(input), do: Map.put_new(input, :label_ids, [])

  defp invalid_topic_name do
    {:error,
     Error.validation("Gmail watch topic_name must be a non-empty Pub/Sub topic name",
       reason: :invalid_watch_topic_name,
       details: %{expected: "projects/{project}/topics/{topic}"}
     )}
  end

  defp fetch_client(%{gmail_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
