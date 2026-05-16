defmodule Jido.Connect.PostHog.Handlers.Actions.GetEvent do
  @moduledoc false

  alias Jido.Connect.PostHog.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, %Req.Response{status: 200, body: body}} <-
           client.get_event(input.event_id, token) do
      {:ok, normalize_event(body)}
    else
      {:ok, %Req.Response{status: status, body: body}} ->
        Jido.Connect.PostHog.Client.Transport.handle_error_response(
          {:ok, %{status: status, body: body}}
        )

      {:error, reason} ->
        Jido.Connect.PostHog.Client.Transport.handle_error_response({:error, reason})
    end
  end

  defp fetch_client(%{posthog_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp normalize_event(%{"id" => id} = body) do
    %{
      id: id,
      event: Map.get(body, "event"),
      distinct_id: Map.get(body, "distinct_id"),
      properties: Map.get(body, "properties", %{}),
      timestamp: Map.get(body, "timestamp")
    }
  end

  defp normalize_event(body), do: body
end
