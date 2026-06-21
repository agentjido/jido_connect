defmodule Jido.Connect.Nextcloud.Client.Transport do
  @moduledoc "Nextcloud HTTP transport helpers."

  alias Jido.Connect.{Error, Provider.Transport}
  alias Jido.Connect.Nextcloud.Client.Credentials

  @doc "Builds a Nextcloud Req request for either app-password Basic auth or OAuth bearer auth."
  def request(%{base_url: base_url} = credentials, opts \\ []) do
    headers =
      [
        Credentials.authorization_header(credentials),
        {"accept", Keyword.get(opts, :accept, "application/json")},
        {"user-agent", "jido-connect-nextcloud"}
      ] ++ Keyword.get(opts, :headers, [])

    Req.new(
      base_url: base_url,
      headers: headers
    )
    |> Req.merge(
      Application.get_env(:jido_connect_nextcloud, :nextcloud_req_options, [])
      |> Keyword.merge(Keyword.get(opts, :req_options, []))
    )
  end

  @doc "Executes a request with methods Req does not expose as named helpers."
  def request(%Req.Request{} = request, method, opts)
      when method in [:propfind, :search, :mkcol, :move, :copy] do
    Req.request(request, Keyword.put(opts, :method, method))
  end

  def request(%Req.Request{} = request, method, opts),
    do: Transport.request(request, method, opts)

  @doc "Normalizes a Nextcloud provider error response."
  def handle_error_response(response, opts \\ [])

  def handle_error_response({:ok, %{status: status, body: body}}, opts)
      when is_integer(status) do
    message = Keyword.get(opts, :message, "Nextcloud API request failed")

    {:error,
     Error.provider(message,
       provider: :nextcloud,
       reason: Keyword.get(opts, :reason, reason_from_status(status)),
       status: status,
       details: %{message: error_message(body), body: body}
     )}
  end

  def handle_error_response(response, opts) do
    message = Keyword.get(opts, :message, "Nextcloud API request failed")
    Transport.provider_error(response, provider: :nextcloud, message: message)
  end

  def invalid_success_response(message, body) do
    {:error,
     Error.provider(message,
       provider: :nextcloud,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end

  defp reason_from_status(401), do: :unauthorized
  defp reason_from_status(403), do: :forbidden
  defp reason_from_status(404), do: :not_found
  defp reason_from_status(409), do: :conflict
  defp reason_from_status(423), do: :locked
  defp reason_from_status(429), do: :rate_limited
  defp reason_from_status(status) when status in 500..599, do: :server_error
  defp reason_from_status(_status), do: :http_error

  defp error_message(%{"ocs" => %{"meta" => %{"message" => message}}}) when is_binary(message),
    do: message

  defp error_message(%{"message" => message}) when is_binary(message), do: message
  defp error_message(%{message: message}) when is_binary(message), do: message
  defp error_message(body) when is_binary(body), do: body
  defp error_message(_body), do: "Nextcloud API request failed"
end
