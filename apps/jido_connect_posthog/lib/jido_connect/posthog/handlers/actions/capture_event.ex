defmodule Jido.Connect.PostHog.Handlers.Actions.CaptureEvent do
  @moduledoc false

  alias Jido.Connect.PostHog.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, %Req.Response{status: status}}
         when status in 200..299 <-
           client.capture_event(token, input.event, input.distinct_id,
             properties: Map.get(input, :properties, %{}),
             timestamp: Map.get(input, :timestamp)
           ) do
      {:ok, %{status: "captured"}}
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
end
