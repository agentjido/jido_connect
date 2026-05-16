defmodule Jido.Connect.PostHog.Handlers.Actions.GetPerson do
  @moduledoc false

  alias Jido.Connect.PostHog.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, %Req.Response{status: 200, body: body}} <-
           client.get_person(input.distinct_id, token) do
      {:ok, normalize_person(body)}
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

  defp normalize_person(%{"id" => id} = body) do
    %{
      id: id,
      distinct_ids: Map.get(body, "distinct_ids", []),
      properties: Map.get(body, "properties", %{}),
      created_at: Map.get(body, "created_at")
    }
  end

  defp normalize_person(body), do: body
end
