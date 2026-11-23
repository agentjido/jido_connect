defmodule Jido.Connect.GitHub.AccountSetup do
  @moduledoc "GitHub setup for manually supplied tokens, browser OAuth, and device OAuth."
  @behaviour Jido.Connect.AccountSetup

  alias Jido.Connect.AccountSetup.Credential
  alias Jido.Connect.Error
  alias Jido.Connect.GitHub.{Client, OAuth}

  @impl true
  def import_key(token, opts) do
    token = String.trim(token)

    if token != "" and String.valid?(token) and not Regex.match?(~r/[\x00-\x20\x7f]/, token) do
      {:ok,
       %Credential{fields: %{access_token: token}, scopes: Keyword.get(opts, :scope, ["repo"])}}
    else
      {:error, Error.auth("GitHub token is invalid", reason: :invalid_key)}
    end
  end

  @impl true
  defdelegate authorize_url(opts), to: OAuth

  @impl true
  def exchange_code(code, opts), do: OAuth.exchange_code(code, opts) |> verify_oauth_account(opts)

  @impl true
  defdelegate start_device(opts), to: OAuth, as: :start_device_authorization

  @impl true
  def poll_device(code, opts),
    do: OAuth.poll_device_authorization(code, opts) |> verify_oauth_account(opts)

  @impl true
  def refresh(token, opts) do
    with {:ok, response} <- OAuth.refresh_token(token, opts) do
      normalize(response, opts)
    else
      {:error, %Error.ProviderError{reason: "bad_refresh_token"}} ->
        {:error, Error.auth("Reconnect GitHub", reason: :reconnect_required)}

      {:error, _} = error ->
        error
    end
  end

  defp verify_oauth_account({:ok, response}, opts) do
    with {:ok, credential} <- normalize(response, opts),
         {:ok, account} <- Client.get_user(response.access_token) do
      subject = Map.take(account, [:id, :login, "id", "login"])
      {:ok, %{credential | subject: subject}}
    end
  end

  defp verify_oauth_account(result, _opts), do: result

  defp normalize(response, opts) do
    if Keyword.get(opts, :required_scopes, []) -- response.scope == [] do
      now = DateTime.utc_now()

      {:ok,
       %Credential{
         fields: Map.take(response, [:access_token, :refresh_token]),
         scopes: response.scope,
         expires_at: expires_at(now, response[:expires_in]),
         refresh_expires_at: expires_at(now, response[:refresh_token_expires_in])
       }}
    else
      {:error, Error.auth("GitHub grant is missing required scopes", reason: :missing_scopes)}
    end
  end

  defp expires_at(_now, nil), do: nil
  defp expires_at(now, seconds), do: DateTime.add(now, seconds, :second)
end
