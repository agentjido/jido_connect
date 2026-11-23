defmodule Jido.Connect.AccountSetup do
  @moduledoc """
  Runs provider setup for a trusted host. The host authenticates the principal,
  owns OAuth transaction storage, and saves the resulting credential.
  """

  alias Jido.Connect.{Callback, Error}

  defmodule Credential do
    @moduledoc "Provider setup result. Store `fields` in the host's credential store."
    @derive {Inspect, except: [:fields]}
    @enforce_keys [:fields, :scopes]
    defstruct [:fields, :scopes, :expires_at, :refresh_expires_at, subject: %{}]

    @type t :: %__MODULE__{
            fields: map(),
            scopes: [String.t()],
            subject: map(),
            expires_at: DateTime.t() | nil,
            refresh_expires_at: DateTime.t() | nil
          }
  end

  defmodule BrowserFlow do
    @moduledoc "Short-lived host OAuth transaction. Keep it out of the agent context."
    @derive {Inspect, except: [:verifier, :state]}
    @enforce_keys [
      :provider,
      :principal,
      :target,
      :state,
      :verifier,
      :client_id,
      :redirect_uri,
      :expires_at
    ]
    defstruct @enforce_keys
  end

  defmodule DeviceFlow do
    @moduledoc "Device authorization state. Display the verification URI and user code."
    @derive {Inspect, except: [:device_code]}
    @enforce_keys [
      :provider,
      :client_id,
      :device_code,
      :user_code,
      :verification_uri,
      :interval_ms,
      :next_poll_at,
      :expires_at
    ]
    defstruct @enforce_keys
  end

  @callback import_key(String.t(), keyword()) :: {:ok, Credential.t()} | {:error, Error.error()}
  @callback authorize_url(keyword()) :: String.t()
  @callback exchange_code(String.t(), keyword()) ::
              {:ok, Credential.t()} | {:error, Error.error()}
  @callback start_device(keyword()) :: {:ok, map()} | {:error, Error.error()}
  @callback poll_device(String.t(), keyword()) ::
              {:ok, Credential.t()}
              | {:pending, :authorization_pending | :slow_down}
              | {:error, Error.error()}
  @callback refresh(String.t(), keyword()) :: {:ok, Credential.t()} | {:error, Error.error()}

  @optional_callbacks import_key: 2,
                      authorize_url: 1,
                      exchange_code: 2,
                      start_device: 1,
                      poll_device: 2,
                      refresh: 2

  @browser_lifetime_seconds 600
  @slow_down_ms 5_000

  @doc "Validates a manually supplied key and shapes it for host storage."
  def import_key(provider, key, opts \\ []) when is_binary(key) do
    provider |> call(:import_key, [key, opts]) |> credential_result()
  end

  @doc "Builds a PKCE authorization URL and a transaction for the host to store."
  def start_browser(provider, principal, target, opts) do
    with {:ok, client_id, redirect_uri} <- browser_config(opts) do
      flow = %BrowserFlow{
        provider: provider,
        principal: principal,
        target: target,
        state: nonce(),
        verifier: nonce(),
        client_id: client_id,
        redirect_uri: redirect_uri,
        expires_at: DateTime.add(DateTime.utc_now(), @browser_lifetime_seconds, :second)
      }

      challenge = :crypto.hash(:sha256, flow.verifier) |> Base.url_encode64(padding: false)
      opts = Keyword.merge(opts, state: flow.state, code_challenge: challenge)

      case call(provider, :authorize_url, [opts]) do
        {:ok, url} when is_binary(url) -> {:ok, url, flow}
        _ -> setup_error()
      end
    end
  end

  @doc """
  Consumes a transaction before exchanging a code. `consume` must atomically
  match and remove the state for the authenticated principal. It must leave
  state from another principal in place. On success the host saves the
  credential for the returned target.
  """
  def finish_browser(provider, principal, state, code, consume, opts)
      when is_binary(state) and byte_size(state) > 0 and is_binary(code) and byte_size(code) > 0 and
             is_function(consume, 2) do
    with {:ok, client_id, redirect_uri} <- browser_config(opts),
         {:ok, {:ok, %BrowserFlow{} = flow}} <-
           Callback.run(fn -> consume.(principal, state) end, phase: :oauth_state),
         true <- valid_flow?(flow, provider, principal, state, client_id, redirect_uri) do
      opts = Keyword.merge(opts, state: state, code_verifier: flow.verifier)

      with {:ok, credential} <-
             call(provider, :exchange_code, [code, opts]) |> credential_result() do
        {:ok, flow.target, credential}
      end
    else
      _ -> invalid_oauth_state()
    end
  end

  def finish_browser(_, _, _, _, _, _), do: invalid_oauth_state()

  @doc "Starts headless device authorization."
  def start_device(provider, opts) do
    with {:ok, client_id} <- required_option(opts, :client_id),
         {:ok,
          {:ok,
           %{
             device_code: code,
             user_code: user_code,
             verification_uri: uri,
             expires_in: ttl,
             interval: interval
           }}} <-
           call(provider, :start_device, [opts]),
         true <-
           is_binary(code) and code != "" and is_binary(user_code) and is_binary(uri) and
             is_integer(interval) and interval > 0 and is_integer(ttl) and ttl > 0 do
      now = System.monotonic_time(:millisecond)

      {:ok,
       %DeviceFlow{
         provider: provider,
         client_id: client_id,
         device_code: code,
         user_code: user_code,
         verification_uri: uri,
         interval_ms: interval * 1_000,
         next_poll_at: now + interval * 1_000,
         expires_at: now + ttl * 1_000
       }}
    else
      _ -> setup_error()
    end
  end

  @doc "Polls only when due. A pending response includes the delay and updated flow."
  def poll_device(%DeviceFlow{} = flow, opts) do
    now = System.monotonic_time(:millisecond)

    cond do
      Keyword.get(opts, :client_id) != flow.client_id ->
        setup_error()

      now >= flow.expires_at ->
        {:error, Error.auth("Device authorization expired", reason: :oauth_expired)}

      now < flow.next_poll_at ->
        pending(flow, now)

      true ->
        poll_provider(flow, opts)
    end
  end

  @doc "Renews a credential. The host serializes refresh and stores the replacement."
  def refresh(provider, refresh_token, opts) when is_binary(refresh_token) do
    provider |> call(:refresh, [refresh_token, opts]) |> credential_result()
  end

  defp poll_provider(flow, opts) do
    case call(flow.provider, :poll_device, [flow.device_code, opts]) do
      {:ok, {:pending, reason}} when reason in [:authorization_pending, :slow_down] ->
        now = System.monotonic_time(:millisecond)

        interval =
          if reason == :slow_down, do: flow.interval_ms + @slow_down_ms, else: flow.interval_ms

        pending(%{flow | interval_ms: interval, next_poll_at: now + interval}, now)

      result ->
        credential_result(result)
    end
  end

  defp pending(flow, now),
    do: {:pending, max(0, min(flow.next_poll_at, flow.expires_at) - now), flow}

  defp valid_flow?(flow, provider, principal, state, client_id, redirect_uri) do
    flow.provider == provider and flow.principal == principal and flow.state == state and
      flow.client_id == client_id and flow.redirect_uri == redirect_uri and
      DateTime.after?(flow.expires_at, DateTime.utc_now())
  end

  defp browser_config(opts) do
    with {:ok, client_id} <- required_option(opts, :client_id),
         {:ok, redirect_uri} <- required_option(opts, :redirect_uri) do
      {:ok, client_id, redirect_uri}
    end
  end

  defp required_option(opts, key) do
    case Keyword.get(opts, key) do
      value when is_binary(value) and byte_size(value) > 0 -> {:ok, value}
      _ -> {:error, Error.config("Provider setup option is required", key: key)}
    end
  end

  defp credential_result({:ok, {:ok, %Credential{} = credential}}), do: {:ok, credential}

  defp credential_result({:ok, {:error, %Error.AuthError{reason: reason}}}) when is_atom(reason),
    do: {:error, Error.auth("Provider setup denied", reason: reason)}

  defp credential_result(_), do: setup_error()

  defp invalid_oauth_state,
    do:
      {:error,
       Error.auth("OAuth transaction is invalid or expired", reason: :invalid_oauth_state)}

  defp setup_error,
    do: {:error, Error.auth("Provider setup failed", reason: :provider_setup_failed)}

  defp call(provider, function, args),
    do: Callback.call(provider, function, args, phase: :account_setup)

  defp nonce, do: 32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
end
