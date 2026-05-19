defmodule Jido.Connect.Microsoft.Transport do
  @moduledoc "Microsoft Graph-specific HTTP transport configuration."

  alias Jido.Connect.{Error, Provider.Transport}

  @api_base_url "https://graph.microsoft.com/v1.0"

  @doc "Builds a Microsoft Graph bearer request."
  @spec request(String.t(), keyword()) :: Req.Request.t()
  def request(access_token, opts \\ []) when is_binary(access_token) and is_list(opts) do
    Transport.bearer_request(
      Keyword.get(opts, :base_url, base_url()),
      access_token,
      headers: [
        {"accept", "application/json"}
      ],
      req_options:
        Application.get_env(:jido_connect_microsoft, :microsoft_req_options, [])
        |> Keyword.merge(Keyword.get(opts, :req_options, []))
    )
  end

  @doc "Executes a Microsoft Graph request through the shared provider transport."
  @spec request(Req.Request.t(), Transport.method(), keyword()) :: term()
  def request(%Req.Request{} = request, method, opts) do
    Transport.request(request, method, opts)
  end

  @doc "Returns the configured Microsoft Graph API base URL."
  @spec base_url() :: String.t()
  def base_url do
    Application.get_env(:jido_connect_microsoft, :microsoft_graph_base_url, @api_base_url)
  end

  @doc "Normalizes a Microsoft Graph provider error response."
  @spec handle_error_response(term(), keyword()) :: {:error, Error.ProviderError.t()}
  def handle_error_response(response, opts \\ [])

  def handle_error_response({:ok, %{status: status, body: body}}, opts)
      when is_integer(status) and is_map(body) do
    message = Keyword.get(opts, :message, "Microsoft Graph API request failed")

    {:error,
     Error.provider(message,
       provider: :microsoft,
       reason: Keyword.get(opts, :reason, :http_error),
       status: status,
       details: %{message: graph_error_message(body), body: body}
     )}
  end

  def handle_error_response(response, opts) do
    message = Keyword.get(opts, :message, "Microsoft Graph API request failed")
    Transport.provider_error(response, provider: :microsoft, message: message)
  end

  @doc "Returns a sanitized provider error for malformed success payloads."
  @spec invalid_success_response(String.t(), term()) :: {:error, Error.ProviderError.t()}
  def invalid_success_response(message, body) do
    {:error,
     Error.provider(message,
       provider: :microsoft,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end

  defp graph_error_message(%{"error" => %{"message" => message}}) when is_binary(message),
    do: message

  defp graph_error_message(%{error: %{message: message}}) when is_binary(message), do: message
  defp graph_error_message(%{"error" => message}) when is_binary(message), do: message
  defp graph_error_message(%{error: message}) when is_binary(message), do: message
  defp graph_error_message(_body), do: "Microsoft Graph API request failed"
end
