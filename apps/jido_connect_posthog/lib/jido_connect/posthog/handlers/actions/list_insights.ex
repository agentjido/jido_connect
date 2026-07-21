defmodule Jido.Connect.PostHog.Handlers.Actions.ListInsights do
  @moduledoc false

  alias Jido.Connect.PostHog.Client
  alias Jido.Connect.PostHog.Client.Normalizer

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, %Req.Response{status: 200, body: body}} <-
           client.list_insights(token, build_opts(input)) do
      {:ok, normalize_insights(body)}
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
    |> maybe_opt(:limit, Map.get(input, :limit))
    |> maybe_opt(:offset, Map.get(input, :offset))
    |> maybe_opt(:date_from, Map.get(input, :date_from))
    |> maybe_opt(:date_to, Map.get(input, :date_to))
  end

  defp maybe_opt(opts, _key, nil), do: opts
  defp maybe_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp normalize_insights(%{"results" => results} = body) do
    insights =
      Enum.map(results, fn item ->
        case Normalizer.insight(item) do
          {:ok, insight} -> insight
          {:error, _} -> item
        end
      end)

    {:ok, page} = Normalizer.pagination(body)

    %{
      insights: insights,
      next: page.next
    }
  end

  defp normalize_insights(_body), do: %{insights: [], next: nil}
end
