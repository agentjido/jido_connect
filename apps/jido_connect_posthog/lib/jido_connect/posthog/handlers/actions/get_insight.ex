defmodule Jido.Connect.PostHog.Handlers.Actions.GetInsight do
  @moduledoc false

  alias Jido.Connect.PostHog.Client
  alias Jido.Connect.PostHog.Client.Normalizer

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, %Req.Response{status: 200, body: body}} <-
           client.get_insight(input.insight_id, token, build_opts(input)) do
      normalize_insight(body)
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

  defp build_opts(input) do
    []
    |> maybe_opt(:date_from, Map.get(input, :date_from))
    |> maybe_opt(:date_to, Map.get(input, :date_to))
  end

  defp maybe_opt(opts, _key, nil), do: opts
  defp maybe_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp normalize_insight(%{"id" => _id} = body) do
    case Normalizer.insight(body) do
      {:ok, insight} ->
        {:ok,
         %{
           id: insight.id,
           short_id: insight.short_id,
           name: insight.name,
           derived_name: insight.derived_name,
           type: insight.type,
           result: insight.result,
           created_at: insight.created_at,
           updated_at: insight.updated_at
         }}

      {:error, _} ->
        {:ok, raw_normalize(body)}
    end
  end

  defp normalize_insight(body), do: {:ok, body}

  defp raw_normalize(body) do
    %{
      id: Map.get(body, "id"),
      short_id: Map.get(body, "short_id"),
      name: Map.get(body, "name"),
      derived_name: Map.get(body, "derived_name"),
      type: Map.get(body, "type") || Map.get(body, "kind"),
      result: Map.get(body, "result"),
      created_at: Map.get(body, "created_at"),
      updated_at: Map.get(body, "updated_at")
    }
  end
end
