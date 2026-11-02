defmodule Jido.Connect.Tempo.Client.Request do
  @moduledoc """
  Runtime-only Tempo request data for one selected connection.

  `new/2` is the connection contract of every Tempo call. It accepts only a
  `:tempo` connection with a non-blank `subject.account_id` (the Atlassian
  account ID the host recorded) and a `metadata.api_origin` from `origins/0`,
  plus the lease field of the connection's profile: `api_token` for
  `:api_token`, `access_token` for `:oauth2_user`. Anything else is a
  `Jido.Connect.Error.AuthError` before any HTTP request.
  """

  alias Jido.Connect.{Connection, Context, Data, Error}

  @origins ["https://api.tempo.io", "https://api.eu.tempo.io", "https://api.us.tempo.io"]
  @token_fields %{api_token: :api_token, oauth2_user: :access_token}
  # Map keys of atoms follow the atom table since OTP 26, so the list is sorted.
  @allowed_profiles @token_fields |> Map.keys() |> Enum.sort()

  @enforce_keys [:connection_id, :auth_profile, :api_origin, :account_id, :token]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          connection_id: String.t(),
          auth_profile: :api_token | :oauth2_user,
          api_origin: String.t(),
          account_id: String.t(),
          token: String.t()
        }

  @doc "Returns the Tempo API origins a connection may use."
  @spec origins() :: [String.t()]
  def origins, do: @origins

  @doc """
  Returns whether `link`, from a Tempo response, names a Tempo origin and
  `path`.

  The link must use HTTPS on the default port, name one of `origins/0` and
  have the decoded path `path`; its query is not checked. Tempo's links name
  `https://api.tempo.io` even on a regional origin (recorded 2026-11-02), so
  any Tempo origin is accepted. A caller never sends a request to the link
  itself: it rebuilds the request at the connection's origin.
  """
  @spec tempo_link?(String.t(), String.t()) :: boolean()
  def tempo_link?(link, path) when is_binary(link) and is_binary(path) do
    uri = URI.parse(link)

    uri.scheme == "https" and uri.port == 443 and "https://#{uri.host}" in @origins and
      URI.decode(uri.path || "") == URI.decode(path)
  end

  @doc "Builds request data from the selected connection and leased credentials."
  @spec new(Connection.t(), map()) :: {:ok, t()} | {:error, Error.AuthError.t()}
  def new(%Connection{provider: :tempo} = connection, credentials) when is_map(credentials) do
    with {:ok, token_field} <- token_field(connection),
         {:ok, account_id} <- account_id(connection),
         {:ok, api_origin} <- api_origin(connection),
         {:ok, token} <- token(connection, credentials, token_field) do
      {:ok,
       %__MODULE__{
         connection_id: connection.id,
         auth_profile: connection.profile,
         api_origin: api_origin,
         account_id: account_id,
         token: token
       }}
    end
  end

  def new(%Connection{} = connection, _credentials) do
    {:error,
     Error.auth("Tempo request requires a Tempo connection",
       reason: :tempo_connection_required,
       connection_id: connection.id
     )}
  end

  @doc "Builds request data from a provider handler runtime map."
  @spec from_runtime(map()) :: {:ok, t()} | {:error, Error.AuthError.t()}
  def from_runtime(%{
        context: %Context{connection: %Connection{} = connection},
        credentials: credentials
      })
      when is_map(credentials) do
    new(connection, credentials)
  end

  def from_runtime(_runtime) do
    {:error,
     Error.auth("Tempo request context is required", reason: :tempo_request_context_required)}
  end

  @doc "Returns the leased token sent as the Bearer credential."
  @spec token(t()) :: String.t()
  def token(%__MODULE__{token: token}), do: token

  defp token_field(%Connection{profile: profile} = connection) do
    case Map.fetch(@token_fields, profile) do
      {:ok, field} ->
        {:ok, field}

      :error ->
        {:error,
         Error.auth("Unsupported Tempo authentication profile",
           reason: :unsupported_tempo_auth_profile,
           connection_id: connection.id,
           details: %{profile: profile, allowed_profiles: @allowed_profiles}
         )}
    end
  end

  defp account_id(%Connection{subject: subject} = connection) do
    case Data.get(subject, :account_id) do
      value when is_binary(value) ->
        if String.trim(value) == "", do: account_id_error(connection), else: {:ok, value}

      _other ->
        account_id_error(connection)
    end
  end

  defp account_id_error(connection) do
    {:error,
     Error.auth("Tempo connection requires subject.account_id",
       reason: :tempo_account_id_required,
       connection_id: connection.id
     )}
  end

  defp api_origin(%Connection{metadata: metadata} = connection) do
    case Data.get(metadata, :api_origin) do
      origin when origin in @origins ->
        {:ok, origin}

      origin when origin in [nil, ""] ->
        {:error,
         Error.auth("Tempo connection requires metadata.api_origin",
           reason: :tempo_api_origin_required,
           connection_id: connection.id,
           details: %{allowed_origins: @origins}
         )}

      "http://" <> _rest ->
        {:error,
         Error.auth("Tempo API origin must use HTTPS",
           reason: :insecure_tempo_api_origin,
           connection_id: connection.id,
           details: %{allowed_origins: @origins}
         )}

      _other ->
        {:error,
         Error.auth("Tempo API origin is not supported",
           reason: :unsupported_tempo_api_origin,
           connection_id: connection.id,
           details: %{allowed_origins: @origins}
         )}
    end
  end

  defp token(connection, credentials, field) do
    case Data.get(credentials, field) do
      value when is_binary(value) and value != "" ->
        {:ok, value}

      _missing ->
        {:error,
         Error.auth("Tempo credentials are incomplete",
           reason: :tempo_credentials_required,
           connection_id: connection.id,
           details: %{profile: connection.profile, missing_fields: [field]}
         )}
    end
  end
end

defimpl Inspect, for: Jido.Connect.Tempo.Client.Request do
  import Inspect.Algebra

  def inspect(request, opts) do
    public = %{
      connection_id: request.connection_id,
      auth_profile: request.auth_profile,
      api_origin: request.api_origin,
      account_id: request.account_id,
      token: "[redacted]"
    }

    concat(["#Jido.Connect.Tempo.Client.Request<", to_doc(public, opts), ">"])
  end
end
