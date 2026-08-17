defmodule Jido.Connect.Jira.Client.Request do
  @moduledoc "Runtime-only Jira request data for one selected connection."

  alias Jido.Connect.{Connection, Context, Data, Error}

  @enforce_keys [:connection, :auth_profile, :endpoint, :credentials]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          connection: Connection.t(),
          auth_profile: atom(),
          endpoint: String.t(),
          credentials: map()
        }

  @doc "Builds request data from the selected connection and leased credentials."
  @spec new(Connection.t(), map()) :: {:ok, t()} | {:error, Error.error()}
  def new(%Connection{provider: :jira} = connection, credentials) when is_map(credentials) do
    with {:ok, endpoint} <- endpoint(connection),
         :ok <- validate_credentials(connection.profile, credentials) do
      {:ok,
       %__MODULE__{
         connection: connection,
         auth_profile: connection.profile,
         endpoint: endpoint,
         credentials: credentials
       }}
    end
  end

  def new(%Connection{} = connection, _credentials) do
    {:error,
     Error.auth("Jira request requires a Jira connection",
       reason: :jira_connection_required,
       connection_id: connection.id
     )}
  end

  @doc "Builds request data from a provider handler runtime map."
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
     Error.auth("Jira request context is required",
       reason: :jira_request_context_required
     )}
  end

  @doc "Gets one credential field by atom or string key."
  @spec credential(t(), atom()) :: term()
  def credential(%__MODULE__{credentials: credentials}, key), do: Data.get(credentials, key)

  @doc "Builds an absolute provider URL without dropping the connection endpoint path."
  @spec url(t(), String.t()) :: String.t()
  def url(%__MODULE__{endpoint: endpoint}, path) when is_binary(path) do
    endpoint <> "/" <> String.trim_leading(path, "/")
  end

  defp endpoint(%Connection{metadata: metadata, id: connection_id}) do
    endpoint =
      Enum.find_value([:cloud_endpoint, :site, :base_url], fn key ->
        case Data.get(metadata, key) do
          value when is_binary(value) and value != "" -> value
          _value -> nil
        end
      end)

    case normalize_endpoint(endpoint) do
      {:ok, value} ->
        {:ok, value}

      {:error, :insecure} ->
        {:error,
         Error.auth("Jira connection endpoint must use HTTPS",
           reason: :insecure_jira_endpoint,
           connection_id: connection_id
         )}

      :error ->
        {:error,
         Error.auth("Jira connection endpoint is required",
           reason: :jira_endpoint_required,
           connection_id: connection_id,
           details: %{metadata_fields: [:cloud_endpoint, :site, :base_url]}
         )}
    end
  end

  defp normalize_endpoint(endpoint) when is_binary(endpoint) do
    endpoint = String.trim_trailing(endpoint, "/")
    uri = URI.parse(endpoint)

    cond do
      uri.scheme == "https" and is_binary(uri.host) and uri.host != "" ->
        {:ok, endpoint}

      uri.scheme == "http" and is_binary(uri.host) and uri.host != "" ->
        {:error, :insecure}

      true ->
        :error
    end
  end

  defp normalize_endpoint(_endpoint), do: :error

  defp validate_credentials(:api_token, credentials) do
    require_fields(credentials, [:email, :api_token], :api_token)
  end

  defp validate_credentials(:oauth2_user, credentials) do
    require_fields(credentials, [:access_token], :oauth2_user)
  end

  defp validate_credentials(profile, _credentials) do
    {:error,
     Error.auth("Unsupported Jira authentication profile",
       reason: :unsupported_jira_auth_profile,
       details: %{profile: profile, allowed_profiles: [:api_token, :oauth2_user]}
     )}
  end

  defp require_fields(credentials, fields, profile) do
    missing =
      Enum.filter(fields, fn field ->
        case Data.get(credentials, field) do
          value when is_binary(value) and value != "" -> false
          _value -> true
        end
      end)

    if missing == [] do
      :ok
    else
      {:error,
       Error.auth("Jira credentials are incomplete",
         reason: :jira_credentials_required,
         details: %{profile: profile, missing_fields: missing}
       )}
    end
  end
end

defimpl Inspect, for: Jido.Connect.Jira.Client.Request do
  import Inspect.Algebra

  def inspect(request, opts) do
    public = %{
      connection_id: request.connection.id,
      auth_profile: request.auth_profile,
      endpoint: request.endpoint,
      credentials: "[redacted]"
    }

    concat(["#Jido.Connect.Jira.Client.Request<", to_doc(public, opts), ">"])
  end
end
