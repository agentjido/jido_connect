defmodule Jido.Connect.PostHog.Handlers.Actions.RunQuery do
  @moduledoc false

  alias Jido.Connect.PostHog.Client
  alias Jido.Connect.PostHog.Client.Normalizer

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, %Req.Response{status: 200, body: body}} <-
           client.run_query(token, input.query, build_opts(input)) do
      normalize_result(input.query, body)
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

  defp normalize_result(query, body) when is_map(body) do
    payload = Map.put(body, "query", query)

    case Normalizer.query_result(payload) do
      {:ok, result} ->
        {:ok,
         %{
           query: result.query,
           columns: result.columns,
           results: result.results,
           has_more: result.has_more
         }}

      {:error, _reason} ->
        # Fallback to raw extraction if normalizer rejects the shape
        {:ok,
         %{
           query: query,
           columns: Map.get(body, "columns", []),
           results: Map.get(body, "results", []),
           has_more: Map.get(body, "has_more")
         }}
    end
  end

  defp normalize_result(query, _body),
    do: {:ok, %{query: query, columns: [], results: [], has_more: nil}}
end
