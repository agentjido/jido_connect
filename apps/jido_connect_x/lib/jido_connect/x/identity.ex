defmodule Jido.Connect.X.Identity do
  @moduledoc false

  alias Jido.Connect.{Context, CredentialLease, Data, Error}
  alias Jido.Connect.X.Contract
  alias Jido.MCP.Endpoint

  @username ~r/^[A-Za-z0-9_]{1,15}$/

  @enforce_keys [:expected_username]
  defstruct @enforce_keys

  @type t :: %__MODULE__{expected_username: String.t()}

  def from_runtime(%{
        context: %Context{connection: connection},
        credential_lease: %CredentialLease{} = lease
      }) do
    with :ok <- CredentialLease.validate_connection_binding(lease, connection),
         :ok <- connection_contract(connection),
         {:ok, expected_username} <- expected_username(connection.metadata),
         :ok <- validate_endpoint(lease) do
      {:ok, %__MODULE__{expected_username: expected_username}}
    end
  end

  def from_runtime(_runtime), do: auth_error(:x_runtime_context_required)

  @doc "Normalizes one valid X username to lowercase ASCII for exact comparison."
  def normalize_username(username) when is_binary(username) do
    if Regex.match?(@username, username) do
      {:ok, String.downcase(username, :ascii)}
    else
      auth_error(:invalid_x_username)
    end
  end

  def normalize_username(_username), do: auth_error(:invalid_x_username)

  def matches_authenticated_username?(%__MODULE__{expected_username: expected}, authenticated) do
    case normalize_username(authenticated) do
      {:ok, normalized} -> normalized == expected
      {:error, _error} -> false
    end
  end

  def validate_endpoint(%CredentialLease{} = lease) do
    with {:ok, source} <- fetch_endpoint(lease),
         :ok <- validate_source(source),
         {:ok, endpoint} <- endpoint(source),
         :ok <- exact_endpoint(endpoint) do
      :ok
    end
  end

  def validate_endpoint(_lease), do: auth_error(:x_mcp_endpoint_required)

  defp connection_contract(connection) do
    with {:ok, endpoint_id} <- one_metadata_value(connection.metadata, :mcp_endpoint_id) do
      cond do
        connection.provider != :x -> auth_error(:x_connection_required)
        connection.profile != :local_mcp -> auth_error(:unsupported_x_auth_profile)
        connection.owner_type != :user -> auth_error(:x_user_owner_required)
        endpoint_id != Contract.endpoint_id() -> auth_error(:x_mcp_endpoint_mismatch)
        true -> :ok
      end
    else
      :error -> auth_error(:x_mcp_endpoint_mismatch)
    end
  end

  defp expected_username(metadata) when is_map(metadata) do
    with {:ok, username} <- one_metadata_value(metadata, :expected_username),
         {:ok, normalized} <- normalize_username(username) do
      {:ok, normalized}
    else
      _error -> auth_error(:invalid_x_username)
    end
  end

  defp expected_username(_metadata), do: auth_error(:invalid_x_username)

  defp fetch_endpoint(lease) do
    case CredentialLease.fetch_field(lease, :mcp_endpoint) do
      {:ok, source} -> {:ok, source}
      :error -> auth_error(:x_mcp_endpoint_required)
    end
  end

  defp validate_source(%Endpoint{}), do: :ok

  defp validate_source(source) when is_map(source) do
    case Data.get(source, :transport) do
      {:streamable_http, opts} when is_list(opts) -> validate_transport_options(opts)
      _transport -> auth_error(:x_mcp_endpoint_mismatch)
    end
  end

  defp validate_source(source) when is_list(source) do
    if Keyword.keyword?(source),
      do: validate_source(Map.new(source)),
      else: auth_error(:x_mcp_endpoint_mismatch)
  end

  defp validate_source(_source), do: auth_error(:x_mcp_endpoint_mismatch)

  defp validate_transport_options(opts) do
    if Keyword.keyword?(opts) do
      with :ok <- at_most_one(opts, :url),
           :ok <- at_most_one(opts, :base_url),
           :ok <- at_most_one(opts, :mcp_path),
           :ok <- optional_exact(opts, :url, Contract.endpoint()),
           :ok <- optional_exact(opts, :base_url, Contract.base_url()),
           :ok <- optional_exact(opts, :mcp_path, Contract.mcp_path()) do
        :ok
      end
    else
      auth_error(:x_mcp_endpoint_mismatch)
    end
  end

  defp at_most_one(opts, key) do
    if length(Keyword.get_values(opts, key)) <= 1,
      do: :ok,
      else: auth_error(:x_mcp_endpoint_mismatch)
  end

  defp optional_exact(opts, key, expected) do
    case Keyword.fetch(opts, key) do
      :error -> :ok
      {:ok, ^expected} -> :ok
      {:ok, _other} -> auth_error(:x_mcp_endpoint_mismatch)
    end
  end

  defp endpoint(%Endpoint{} = endpoint), do: {:ok, endpoint}

  defp endpoint(source) when is_map(source) or is_list(source) do
    case Endpoint.new("x-validation", source) do
      {:ok, endpoint} -> {:ok, endpoint}
      {:error, _reason} -> auth_error(:x_mcp_endpoint_mismatch)
    end
  end

  defp exact_endpoint(%Endpoint{transport: {:streamable_http, opts}}) do
    base_urls = Keyword.get_values(opts, :base_url)
    paths = Keyword.get_values(opts, :mcp_path)

    with [base_url] <- base_urls,
         [mcp_path] <- paths,
         true <- Keyword.get_values(opts, :url) == [],
         :ok <- exact_base_url(base_url),
         true <- mcp_path == Contract.mcp_path() do
      :ok
    else
      _other -> auth_error(:x_mcp_endpoint_mismatch)
    end
  end

  defp exact_endpoint(_endpoint), do: auth_error(:x_mcp_endpoint_mismatch)

  defp exact_base_url(base_url) when is_binary(base_url) do
    uri = URI.parse(base_url)

    if base_url == Contract.base_url() and uri.scheme == "http" and
         uri.host == "127.0.0.1" and uri.port == 8000 and uri.path in [nil, ""] and
         is_nil(uri.userinfo) and is_nil(uri.query) and is_nil(uri.fragment) do
      :ok
    else
      auth_error(:x_mcp_endpoint_mismatch)
    end
  end

  defp exact_base_url(_base_url), do: auth_error(:x_mcp_endpoint_mismatch)

  defp one_metadata_value(metadata, key) when is_map(metadata) do
    string_key = Atom.to_string(key)

    case {Map.fetch(metadata, key), Map.fetch(metadata, string_key)} do
      {{:ok, value}, :error} -> {:ok, value}
      {:error, {:ok, value}} -> {:ok, value}
      _missing_or_duplicate -> :error
    end
  end

  defp one_metadata_value(_metadata, _key), do: :error

  defp auth_error(reason) do
    {:error,
     Error.auth("X connection identity is not valid",
       reason: reason,
       details: %{provider: :x}
     )}
  end
end
