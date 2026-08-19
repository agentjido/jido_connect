defmodule Jido.Connect.Confluence.Client.Transport do
  @moduledoc "Confluence Cloud REST v2 transport boundary."

  alias Jido.Connect.{Error, ProviderResponse, Sanitizer}
  alias Jido.Connect.Provider.Transport, as: ProviderTransport
  alias Jido.Connect.Confluence.Client.Request

  @spec request(Request.t(), keyword()) :: Req.Request.t()
  def request(%Request{} = request, opts \\ []) when is_list(opts) do
    req_options =
      Application.get_env(:jido_connect_confluence, :confluence_req_options, [])
      |> Keyword.merge(Keyword.get(opts, :req_options, []))
      |> maybe_disable_retry(Keyword.get(opts, :mutation?, false))

    ProviderTransport.basic_request(
      request.endpoint,
      Request.credential(request, :email),
      Request.credential(request, :api_token),
      headers: [{"accept", "application/json"}],
      req_options: req_options
    )
  end

  @spec handle_error_response(term(), keyword()) :: {:error, Error.ProviderError.t()}
  def handle_error_response(response, opts \\ []) do
    envelope = ProviderResponse.from_result!(:confluence, response, opts)

    {:error,
     Error.provider(Keyword.get(opts, :message, "Confluence API request failed"),
       provider: :confluence,
       reason: error_reason(response),
       status: envelope.status,
       delivery: envelope.delivery,
       mutation?: envelope.mutation?,
       provider_idempotency?: false,
       details: %{response: ProviderResponse.to_public_map(envelope)}
     )}
  end

  @spec invalid_success_response(String.t(), term(), keyword()) ::
          {:error, Error.ProviderError.t()}
  def invalid_success_response(message, body, opts \\ []) do
    {:error,
     Error.provider(message,
       provider: :confluence,
       reason: :invalid_response,
       delivery: :response_received,
       mutation?: Keyword.get(opts, :mutation?, false),
       provider_idempotency?: false,
       details: %{body_summary: Sanitizer.provider_body_summary(body)}
     )}
  end

  defp maybe_disable_retry(req_options, true), do: Keyword.put(req_options, :retry, false)
  defp maybe_disable_retry(req_options, false), do: req_options

  defp error_reason({:ok, %{status: status}}) when is_integer(status), do: :http_error
  defp error_reason({:error, _reason}), do: :request_error
  defp error_reason(_response), do: :unexpected_response
end
