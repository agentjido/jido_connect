defmodule Jido.Connect.Linear.Client.Transport do
  @moduledoc "Linear GraphQL API transport boundary."

  alias Jido.Connect.{Error, Provider.Transport}

  @default_base_url "https://api.linear.app"

  @doc "Builds a Linear GraphQL API bearer request."
  @spec request(String.t(), keyword()) :: Req.Request.t()
  def request(access_token, opts \\ []) when is_binary(access_token) and is_list(opts) do
    Transport.bearer_request(
      Keyword.get(opts, :base_url, base_url()),
      access_token,
      headers: [
        {"accept", "application/json"},
        {"content-type", "application/json"}
      ],
      req_options:
        Application.get_env(:jido_connect_linear, :linear_req_options, [])
        |> Keyword.merge(Keyword.get(opts, :req_options, []))
    )
  end

  @doc "Returns the configured Linear API base URL."
  @spec base_url() :: String.t()
  def base_url do
    Application.get_env(
      :jido_connect_linear,
      :linear_api_base_url,
      @default_base_url
    )
  end

  @doc """
  Executes a GraphQL query against the Linear API.

  Returns `{:ok, %{status: integer, body: map}}` on success or
  `{:error, term}` on transport failure.
  """
  @spec graphql(Req.Request.t(), String.t(), map() | nil) :: term()
  def graphql(request, query, variables \\ nil) when is_binary(query) do
    body = %{query: query}

    body =
      if variables do
        Map.put(body, :variables, variables)
      else
        body
      end

    Req.post(request, url: "/graphql", json: body)
  end

  @doc "Normalizes a Linear provider error response."
  @spec handle_error_response(term(), keyword()) :: {:error, Error.ProviderError.t()}
  def handle_error_response(response, opts \\ [])

  def handle_error_response({:ok, %{status: status, body: body}}, opts)
      when is_integer(status) and is_map(body) do
    message = Keyword.get(opts, :message, "Linear API request failed")

    {:error,
     Error.provider(message,
       provider: :linear,
       reason: Keyword.get(opts, :reason, :http_error),
       status: status,
       details: %{message: linear_error_message(body), body: body}
     )}
  end

  def handle_error_response(response, opts) do
    message = Keyword.get(opts, :message, "Linear API request failed")
    Transport.provider_error(response, provider: :linear, message: message)
  end

  @doc "Returns a sanitized provider error for malformed success payloads."
  @spec invalid_success_response(String.t(), term()) :: {:error, Error.ProviderError.t()}
  def invalid_success_response(message, body) do
    {:error,
     Error.provider(message,
       provider: :linear,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end

  defp linear_error_message(%{"errors" => errors}) when is_list(errors) do
    errors
    |> Enum.map_join("; ", fn
      %{"message" => m} -> m
      msg when is_binary(msg) -> msg
      other -> inspect(other)
    end)
  end

  defp linear_error_message(%{"message" => message}) when is_binary(message), do: message
  defp linear_error_message(_body), do: "Linear API request failed"
end
