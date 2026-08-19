defmodule Jido.Connect.Bitbucket.Client.Transport do
  @moduledoc "Bitbucket Cloud REST transport boundary."

  alias Jido.Connect.{Error, Provider.Transport, Sanitizer}
  alias Jido.Connect.Bitbucket.Client.Request

  @doc "Builds a Basic-auth request for one Bitbucket connection."
  @spec request(Request.t(), keyword()) :: Req.Request.t()
  def request(%Request{} = request, opts \\ []) when is_list(opts) do
    req_options =
      Application.get_env(:jido_connect_bitbucket, :bitbucket_req_options, [])
      |> Keyword.merge(Keyword.get(opts, :req_options, []))

    Transport.basic_request(
      request.endpoint,
      Request.credential(request, :email),
      Request.credential(request, :api_token),
      headers: [{"accept", "application/json"}],
      req_options: req_options
    )
  end

  @doc "Normalizes a Bitbucket provider error without retaining the response body."
  @spec handle_error_response(term()) :: {:error, Error.ProviderError.t()}
  def handle_error_response({:ok, %{status: status, body: body}}) when is_integer(status) do
    {:error,
     Error.provider("Bitbucket API request failed",
       provider: :bitbucket,
       reason: :http_error,
       status: status,
       delivery: :rejected,
       details: %{body_summary: Sanitizer.provider_body_summary(body)}
     )}
  end

  def handle_error_response({:error, _reason}) do
    {:error,
     Error.provider("Bitbucket API request failed",
       provider: :bitbucket,
       reason: :request_error,
       delivery: :sent_outcome_unknown
     )}
  end

  def handle_error_response(_response) do
    {:error,
     Error.provider("Bitbucket API request failed",
       provider: :bitbucket,
       reason: :unexpected_response,
       delivery: :sent_outcome_unknown
     )}
  end

  @doc "Returns a sanitized provider error for a malformed success payload."
  @spec invalid_success_response(String.t(), term()) :: {:error, Error.ProviderError.t()}
  def invalid_success_response(message, body) do
    {:error,
     Error.provider(message,
       provider: :bitbucket,
       reason: :invalid_response,
       delivery: :response_received,
       details: %{body_summary: Sanitizer.provider_body_summary(body)}
     )}
  end
end
