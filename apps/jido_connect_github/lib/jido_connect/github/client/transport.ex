defmodule Jido.Connect.GitHub.Client.Transport do
  @moduledoc "GitHub-specific REST transport configuration."

  alias Jido.Connect.{Error, Provider.Transport}

  @api_version "2022-11-28"
  @request_options_key {__MODULE__, :request_options}

  @spec request(String.t()) :: Req.Request.t()
  def request(access_token) when is_binary(access_token) do
    Transport.bearer_request(
      base_url(),
      access_token,
      headers: [
        {"accept", "application/vnd.github+json"},
        {"x-github-api-version", @api_version}
      ],
      req_options:
        Process.get(
          @request_options_key,
          Application.get_env(:jido_connect_github, :github_req_options, [])
        )
    )
  end

  @doc "Runs one request group with process-local Req options."
  def with_request_options(options, callback)
      when is_list(options) and is_function(callback, 0) do
    previous = Process.get(@request_options_key, :missing)
    Process.put(@request_options_key, options)

    try do
      callback.()
    after
      restore_request_options(previous)
    end
  end

  @spec base_url() :: String.t()
  def base_url do
    Application.get_env(:jido_connect_github, :github_api_base_url, "https://api.github.com")
  end

  @spec handle_error_response(term()) :: {:error, Error.ProviderError.t()}
  def handle_error_response(response) do
    response
    |> Transport.provider_error(provider: :github, message: "GitHub API request failed")
    |> remove_remote_body()
  end

  @spec invalid_success_response(String.t(), term()) :: {:error, Error.ProviderError.t()}
  def invalid_success_response(message, body) do
    {:error,
     Error.provider(message,
       provider: :github,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end

  defp remove_remote_body({:error, %Error.ProviderError{} = error}) do
    details = Map.drop(error.details || %{}, [:body, "body"])
    {:error, %{error | details: details}}
  end

  defp restore_request_options(:missing), do: Process.delete(@request_options_key)
  defp restore_request_options(options), do: Process.put(@request_options_key, options)
end
