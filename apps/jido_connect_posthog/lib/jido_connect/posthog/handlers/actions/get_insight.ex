defmodule Jido.Connect.PostHog.Handlers.Actions.GetInsight do
  @moduledoc false

  alias Jido.Connect.PostHog.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, %Req.Response{status: 200, body: body}} <-
           client.get_insight(input.insight_id, token) do
      {:ok, normalize_insight(body)}
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

  defp normalize_insight(%{"id" => id} = body) do
    %{
      id: id,
      short_id: Map.get(body, "short_id"),
      name: Map.get(body, "name"),
      derived_name: Map.get(body, "derived_name"),
      type: Map.get(body, "type") || Map.get(body, "kind"),
      result: Map.get(body, "result"),
      created_at: Map.get(body, "created_at"),
      updated_at: Map.get(body, "updated_at")
    }
  end

  defp normalize_insight(body), do: body
end
