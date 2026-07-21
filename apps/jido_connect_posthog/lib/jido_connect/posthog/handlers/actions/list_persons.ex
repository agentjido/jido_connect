defmodule Jido.Connect.PostHog.Handlers.Actions.ListPersons do
  @moduledoc false

  alias Jido.Connect.PostHog.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, %Req.Response{status: 200, body: body}} <-
           client.list_persons(token, build_opts(input)) do
      {:ok, normalize_persons(body)}
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
    |> maybe_opt(:search, Map.get(input, :search))
  end

  defp maybe_opt(opts, _key, nil), do: opts
  defp maybe_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp normalize_persons(%{"results" => results} = body) do
    %{
      persons: results,
      next: Map.get(body, "next")
    }
  end

  defp normalize_persons(body), do: body
end
