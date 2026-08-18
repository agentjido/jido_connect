defmodule Jido.Connect.Slack.Handlers.Actions.SetStatus do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Slack.Handlers.ClientResolver

  def run(input, %{credentials: credentials} = context) do
    with :ok <- validate_text(input, :text),
         :ok <- validate_text(input, :emoji),
         {:ok, expiration} <- expiration(Data.get(input, :expires_at)),
         {:ok, client} <- ClientResolver.fetch(context, credentials),
         {:ok, result} <-
           client.set_status(
             %{
               profile: %{
                 status_text: Data.get(input, :text),
                 status_emoji: Data.get(input, :emoji),
                 status_expiration: expiration
               }
             },
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{status: Data.get(result, :status, %{}), submitted: true}}
    end
  end

  defp validate_text(input, field) do
    case Data.get(input, field) do
      value when is_binary(value) and byte_size(value) in 1..100 ->
        if String.trim(value) == "", do: invalid_status(field), else: :ok

      _value ->
        invalid_status(field)
    end
  end

  defp expiration(nil), do: {:ok, 0}

  defp expiration(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, DateTime.to_unix(datetime)}
      _error -> invalid_status(:expires_at)
    end
  end

  defp expiration(_value), do: invalid_status(:expires_at)

  defp invalid_status(field) do
    {:error,
     Error.validation("Slack custom status input is not valid",
       reason: :invalid_status,
       details: %{field: field}
     )}
  end
end
