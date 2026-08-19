defmodule Jido.Connect.Confluence.Client.Request do
  @moduledoc "Runtime-only Confluence request data for one validated Cloud tenant."

  alias Jido.Connect.{Connection, Context, Data, Error}

  @enforce_keys [:connection, :endpoint, :credentials]
  defstruct @enforce_keys

  @type t :: %__MODULE__{connection: Connection.t(), endpoint: String.t(), credentials: map()}

  @spec new(Connection.t(), map()) :: {:ok, t()} | {:error, Error.error()}
  def new(%Connection{provider: :confluence, profile: :api_token} = connection, credentials)
      when is_map(credentials) do
    with {:ok, endpoint} <- endpoint(connection),
         :ok <- validate_credentials(credentials) do
      {:ok, %__MODULE__{connection: connection, endpoint: endpoint, credentials: credentials}}
    end
  end

  def new(%Connection{provider: :confluence} = connection, _credentials) do
    {:error,
     Error.auth("Unsupported Confluence authentication profile",
       reason: :unsupported_confluence_auth_profile,
       connection_id: connection.id,
       details: %{profile: connection.profile, allowed_profiles: [:api_token]}
     )}
  end

  def new(%Connection{} = connection, _credentials) do
    {:error,
     Error.auth("Confluence request requires a Confluence connection",
       reason: :confluence_connection_required,
       connection_id: connection.id
     )}
  end

  @spec from_runtime(map()) :: {:ok, t()} | {:error, Error.error()}
  def from_runtime(%{
        context: %Context{connection: %Connection{} = connection},
        credentials: credentials
      })
      when is_map(credentials),
      do: new(connection, credentials)

  def from_runtime(_runtime) do
    {:error,
     Error.auth("Confluence request context is required",
       reason: :confluence_request_context_required
     )}
  end

  @spec credential(t(), atom()) :: term()
  def credential(%__MODULE__{credentials: credentials}, key), do: Data.get(credentials, key)

  @spec account(t()) :: String.t()
  def account(%__MODULE__{connection: connection}) do
    subject = connection.subject || %{}
    Data.get(subject, :id) || connection.owner_id
  end

  @spec url(t(), String.t()) :: String.t()
  def url(%__MODULE__{endpoint: endpoint}, path) when is_binary(path) do
    endpoint <> "/" <> String.trim_leading(path, "/")
  end

  defp endpoint(%Connection{metadata: metadata, id: connection_id}) do
    case Data.get(metadata, :site_url) do
      value when is_binary(value) and value != "" ->
        case normalize_site_url(value) do
          {:ok, endpoint} -> {:ok, endpoint}
          :error -> invalid_endpoint(connection_id)
        end

      _value ->
        {:error,
         Error.auth("Confluence site URL is required",
           reason: :confluence_site_url_required,
           connection_id: connection_id,
           details: %{metadata_field: :site_url}
         )}
    end
  end

  defp normalize_site_url(site_url) do
    uri = URI.parse(site_url)
    host = if is_binary(uri.host), do: String.downcase(uri.host)

    valid_path = uri.path in [nil, "", "/", "/wiki", "/wiki/"]

    valid_host =
      is_binary(host) and
        Regex.match?(~r/\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.atlassian\.net\z/, host)

    if uri.scheme == "https" and valid_host and uri.port == 443 and is_nil(uri.userinfo) and
         is_nil(uri.query) and is_nil(uri.fragment) and valid_path do
      {:ok, "https://#{host}/wiki"}
    else
      :error
    end
  end

  defp invalid_endpoint(connection_id) do
    {:error,
     Error.auth("Confluence site URL must identify an Atlassian Cloud tenant",
       reason: :invalid_confluence_site_url,
       connection_id: connection_id
     )}
  end

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
       Error.auth("Confluence credentials are incomplete",
         reason: :confluence_credentials_required,
         details: %{missing_fields: missing}
       )}
    end
  end
end

defimpl Inspect, for: Jido.Connect.Confluence.Client.Request do
  import Inspect.Algebra

  def inspect(request, opts) do
    public = %{
      connection_id: request.connection.id,
      endpoint: request.endpoint,
      credentials: "[redacted]"
    }

    concat(["#Jido.Connect.Confluence.Client.Request<", to_doc(public, opts), ">"])
  end
end
