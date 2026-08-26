defmodule Jido.Connect.Trello.BoardIdentity do
  @moduledoc false

  alias Jido.Connect.{Context, CredentialLease, Data, Error}
  alias Jido.Connect.MCP.Endpoint
  alias Jido.Connect.Trello.Contract

  @object_id ~r/^[0-9a-f]{24}$/
  @short_id ~r/^[A-Za-z0-9]{8}$/

  @enforce_keys [
    :board_name,
    :board_url,
    :board_ari,
    :board_object_id,
    :board_short_id,
    :workspace_object_id
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          board_name: String.t(),
          board_url: String.t(),
          board_ari: String.t(),
          board_object_id: String.t(),
          board_short_id: String.t(),
          workspace_object_id: String.t()
        }

  def from_runtime(%{
        context: %Context{connection: connection},
        credential_lease: %CredentialLease{} = lease
      }) do
    with :ok <- CredentialLease.validate_connection_binding(lease, connection),
         :ok <- connection_contract(connection),
         {:ok, identity} <- metadata_identity(connection.metadata),
         :ok <- validate_endpoint(lease) do
      {:ok, identity}
    end
  end

  def from_runtime(_runtime), do: auth_error(:trello_runtime_context_required)

  def validate_endpoint(%CredentialLease{} = lease) do
    with {:ok, source} <- fetch_endpoint(lease),
         :ok <- exact_source_endpoint(source),
         {:ok, endpoint} <- endpoint(source),
         :ok <- exact_endpoint(endpoint) do
      :ok
    end
  end

  def validate_endpoint(_lease), do: auth_error(:trello_mcp_endpoint_required)

  defp connection_contract(connection) do
    endpoint_id = Data.get(connection.metadata, :mcp_endpoint_id)

    cond do
      connection.provider != :trello -> auth_error(:trello_connection_required)
      connection.profile != :oauth_user -> auth_error(:unsupported_trello_auth_profile)
      connection.owner_type != :user -> auth_error(:trello_user_owner_required)
      endpoint_id != Contract.endpoint_id() -> auth_error(:trello_mcp_endpoint_mismatch)
      true -> :ok
    end
  end

  defp metadata_identity(metadata) when is_map(metadata) do
    identity = %__MODULE__{
      board_name: Data.get(metadata, :board_name),
      board_url: Data.get(metadata, :board_url),
      board_ari: Data.get(metadata, :board_ari),
      board_object_id: Data.get(metadata, :board_object_id),
      board_short_id: Data.get(metadata, :board_short_id),
      workspace_object_id: Data.get(metadata, :workspace_object_id)
    }

    expected_ari =
      "ari:cloud:trello::board/workspace/#{identity.workspace_object_id}/#{identity.board_object_id}"

    with :ok <- bounded_name(identity.board_name),
         :ok <- object_id(identity.board_object_id, :board_object_id),
         :ok <- object_id(identity.workspace_object_id, :workspace_object_id),
         :ok <- short_id(identity.board_short_id),
         :ok <- exact_ari(identity.board_ari, expected_ari),
         :ok <- exact_board_url(identity.board_url, identity.board_short_id) do
      {:ok, identity}
    end
  end

  defp metadata_identity(_metadata), do: auth_error(:trello_board_identity_required)

  defp bounded_name(value)
       when is_binary(value) and value != "" and byte_size(value) <= 2_048 do
    if String.trim(value) == value and String.length(value) <= 512,
      do: :ok,
      else: auth_error(:invalid_trello_board_name)
  end

  defp bounded_name(_value), do: auth_error(:invalid_trello_board_name)

  defp object_id(value, _field) when is_binary(value) do
    if Regex.match?(@object_id, value), do: :ok, else: auth_error(:invalid_trello_board_identity)
  end

  defp object_id(_value, _field), do: auth_error(:invalid_trello_board_identity)

  defp short_id(value) when is_binary(value) do
    if Regex.match?(@short_id, value), do: :ok, else: auth_error(:invalid_trello_board_short_id)
  end

  defp short_id(_value), do: auth_error(:invalid_trello_board_short_id)

  defp exact_ari(value, value) when is_binary(value), do: :ok
  defp exact_ari(_actual, _expected), do: auth_error(:trello_board_ari_mismatch)

  defp exact_board_url(url, short_id) when is_binary(url) and is_binary(short_id) do
    uri = URI.parse(url)
    prefix = "/b/#{short_id}/"

    valid_path? =
      is_binary(uri.path) and String.starts_with?(uri.path, prefix) and
        uri.path |> String.replace_prefix(prefix, "") |> valid_slug?()

    if uri.scheme == "https" and uri.host == "trello.com" and uri.port in [nil, 443] and
         is_nil(uri.userinfo) and is_nil(uri.query) and is_nil(uri.fragment) and valid_path? do
      :ok
    else
      auth_error(:invalid_trello_board_url)
    end
  end

  defp exact_board_url(_url, _short_id), do: auth_error(:invalid_trello_board_url)

  defp valid_slug?(slug) when is_binary(slug) do
    String.length(slug) in 1..256 and String.match?(slug, ~r/^[A-Za-z0-9_-]+$/)
  end

  defp fetch_endpoint(lease) do
    case CredentialLease.fetch_field(lease, :mcp_endpoint) do
      {:ok, source} -> {:ok, source}
      :error -> auth_error(:trello_mcp_endpoint_required)
    end
  end

  defp endpoint(%Endpoint{} = endpoint), do: {:ok, endpoint}

  defp endpoint(source) when is_map(source) or is_list(source) do
    case Endpoint.new("trello-validation", source) do
      {:ok, endpoint} -> {:ok, endpoint}
      {:error, _reason} -> auth_error(:invalid_trello_mcp_endpoint)
    end
  end

  defp endpoint(_source), do: auth_error(:invalid_trello_mcp_endpoint)

  defp exact_source_endpoint(%Endpoint{}), do: :ok

  defp exact_source_endpoint(source) when is_map(source) do
    case Data.get(source, :transport) do
      {:streamable_http, options} when is_list(options) ->
        if Keyword.keyword?(options) do
          case Keyword.get_values(options, :url) do
            [] ->
              :ok

            [url] ->
              if url == Contract.endpoint(),
                do: :ok,
                else: auth_error(:trello_mcp_endpoint_mismatch)

            _urls ->
              auth_error(:trello_mcp_endpoint_mismatch)
          end
        else
          auth_error(:invalid_trello_mcp_endpoint)
        end

      _transport ->
        :ok
    end
  end

  defp exact_source_endpoint(source) when is_list(source) do
    if Keyword.keyword?(source),
      do: exact_source_endpoint(Map.new(source)),
      else: auth_error(:invalid_trello_mcp_endpoint)
  end

  defp exact_source_endpoint(_source), do: :ok

  defp exact_endpoint(%Endpoint{transport: {:streamable_http, opts}}) do
    if Keyword.get(opts, :base_url) == Contract.base_url() and
         Keyword.get(opts, :mcp_path) == Contract.mcp_path() do
      :ok
    else
      auth_error(:trello_mcp_endpoint_mismatch)
    end
  end

  defp exact_endpoint(_endpoint), do: auth_error(:trello_mcp_endpoint_mismatch)

  defp auth_error(reason) do
    {:error,
     Error.auth("Trello connection identity is not valid",
       reason: reason,
       details: %{provider: :trello}
     )}
  end
end
