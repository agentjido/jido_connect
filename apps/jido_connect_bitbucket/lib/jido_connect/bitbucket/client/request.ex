defmodule Jido.Connect.Bitbucket.Client.Request do
  @moduledoc "Runtime-only Bitbucket request data for one selected connection."

  alias Jido.Connect.{Connection, Context, Data, Error}

  @default_endpoint "https://api.bitbucket.org/2.0"
  @enforce_keys [:connection, :endpoint, :credentials]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          connection: Connection.t(),
          endpoint: String.t(),
          credentials: map()
        }

  @doc "Builds request data from a Bitbucket API-token connection."
  @spec new(Connection.t(), map()) :: {:ok, t()} | {:error, Error.error()}
  def new(%Connection{provider: :bitbucket, profile: :api_token} = connection, credentials)
      when is_map(credentials) do
    with {:ok, endpoint} <- endpoint(connection),
         :ok <- validate_credentials(credentials) do
      {:ok,
       %__MODULE__{
         connection: connection,
         endpoint: endpoint,
         credentials: credentials
       }}
    end
  end

  def new(%Connection{provider: :bitbucket} = connection, _credentials) do
    {:error,
     Error.auth("Unsupported Bitbucket authentication profile",
       reason: :unsupported_bitbucket_auth_profile,
       connection_id: connection.id,
       details: %{profile: connection.profile, allowed_profiles: [:api_token]}
     )}
  end

  def new(%Connection{} = connection, _credentials) do
    {:error,
     Error.auth("Bitbucket request requires a Bitbucket connection",
       reason: :bitbucket_connection_required,
       connection_id: connection.id
     )}
  end

  @doc "Builds request data from the provider handler runtime."
  @spec from_runtime(map()) :: {:ok, t()} | {:error, Error.error()}
  def from_runtime(%{
        context: %Context{connection: %Connection{} = connection},
        credentials: credentials
      })
      when is_map(credentials) do
    new(connection, credentials)
  end

  def from_runtime(_runtime) do
    {:error,
     Error.auth("Bitbucket request context is required",
       reason: :bitbucket_request_context_required
     )}
  end

  @doc "Gets one credential field by atom or string key."
  @spec credential(t(), atom()) :: term()
  def credential(%__MODULE__{credentials: credentials}, key), do: Data.get(credentials, key)

  @doc "Returns the connection's non-secret account subject."
  @spec account(t()) :: String.t()
  def account(%__MODULE__{connection: connection}) do
    subject = connection.subject || %{}
    Data.get(subject, :id) || connection.owner_id
  end

  @doc "Builds an absolute URL without removing the endpoint path."
  @spec url(t(), String.t()) :: String.t()
  def url(%__MODULE__{endpoint: endpoint}, path) when is_binary(path) do
    endpoint <> "/" <> String.trim_leading(path, "/")
  end

  defp endpoint(%Connection{metadata: metadata, id: connection_id}) do
    configured = Data.get(metadata, :api_endpoint) || Data.get(metadata, :base_url)
    endpoint = configured || @default_endpoint

    case normalize_endpoint(endpoint) do
      {:ok, endpoint} ->
        {:ok, endpoint}

      :error ->
        {:error,
         Error.auth("Bitbucket endpoint must be the official Cloud API URL",
           reason: :invalid_bitbucket_endpoint,
           connection_id: connection_id
         )}
    end
  end

  defp normalize_endpoint(endpoint) when is_binary(endpoint) do
    endpoint = String.trim_trailing(endpoint, "/")

    if endpoint == @default_endpoint, do: {:ok, endpoint}, else: :error
  end

  defp normalize_endpoint(_endpoint), do: :error

  defp validate_credentials(credentials) do
    missing =
      Enum.filter([:email, :api_token], fn field ->
        case Data.get(credentials, field) do
          value when is_binary(value) and value != "" -> false
          _value -> true
        end
      end)

    if missing == [] do
      :ok
    else
      {:error,
       Error.auth("Bitbucket credentials are incomplete",
         reason: :bitbucket_credentials_required,
         details: %{missing_fields: missing}
       )}
    end
  end
end

defimpl Inspect, for: Jido.Connect.Bitbucket.Client.Request do
  import Inspect.Algebra

  def inspect(request, opts) do
    public = %{
      connection_id: request.connection.id,
      endpoint: request.endpoint,
      credentials: "[redacted]"
    }

    concat(["#Jido.Connect.Bitbucket.Client.Request<", to_doc(public, opts), ">"])
  end
end
