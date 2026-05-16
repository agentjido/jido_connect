defmodule Jido.Connect.PostHog.Handlers.Actions.GetFeatureFlag do
  @moduledoc false

  alias Jido.Connect.PostHog.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, %Req.Response{status: 200, body: body}} <-
           client.get_feature_flag(input.flag_id, token) do
      {:ok, normalize_flag(body)}
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

  defp normalize_flag(%{"id" => id} = body) do
    %{
      id: stringify_id(id),
      key: Map.get(body, "key"),
      name: Map.get(body, "name"),
      description: Map.get(body, "description"),
      active: Map.get(body, "active"),
      rollout_percentage: Map.get(body, "rollout_percentage"),
      filters: Map.get(body, "filters"),
      created_at: Map.get(body, "created_at")
    }
  end

  defp normalize_flag(body), do: body

  defp stringify_id(id) when is_integer(id), do: Integer.to_string(id)
  defp stringify_id(id) when is_binary(id), do: id
  defp stringify_id(_), do: nil
end
