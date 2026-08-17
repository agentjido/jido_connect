defmodule Jido.Connect.Things.Client do
  @moduledoc """
  Small Things Cloud account, history, and commit client.

  The client does not persist credentials. Hosts build it for one call from a
  durable `Jido.Connect.Connection` and a short-lived `CredentialLease`.
  """

  alias Jido.Connect.{Connection, Context, CredentialLease, Data, Error}
  alias Jido.Connect.Things.Client.{Response, Transport}

  @production_endpoint "https://cloud.culturedcode.com"
  @things_user_agent "ThingsMac/32209501"
  @receive_timeout 15_000
  @app_id "com.culturedcode.ThingsMac"
  @app_instance_id "000000000000000000000000000000000000000000000000000000000000000-com.culturedcode.ThingsMac-000000000000000000000000000000000000000000000000000000000000000"

  @enforce_keys [
    :endpoint,
    :email,
    :expected_email,
    :password,
    :transport,
    :transport_injected?
  ]
  defstruct @enforce_keys

  def production_endpoint, do: @production_endpoint

  def from_runtime(context, lease, opts \\ [])

  def from_runtime(
        %Context{connection: %Connection{} = connection},
        %CredentialLease{} = lease,
        opts
      ) do
    endpoint =
      connection.metadata
      |> Data.get(:endpoint, @production_endpoint)
      |> normalize_endpoint()

    expected_email = Data.get(connection.subject || %{}, :email)
    email = CredentialLease.get_field(lease, :email)
    password = CredentialLease.get_field(lease, :password)
    transport = option(opts, :transport) || Transport

    with :ok <- present(expected_email, :connection_account_email_required),
         :ok <- present(email, :lease_account_email_required),
         :ok <- present(password, :lease_credential_required),
         :ok <- same_email(expected_email, email),
         :ok <- safe_password(password),
         :ok <- valid_transport(transport) do
      {:ok,
       %__MODULE__{
         endpoint: endpoint,
         email: email,
         expected_email: expected_email,
         password: password,
         transport: transport,
         transport_injected?: transport != Transport
       }}
    end
  end

  def from_runtime(%Context{}, %CredentialLease{}, _opts) do
    {:error, Error.connection_required(%{provider: :things})}
  end

  def verify_account(%__MODULE__{} = client) do
    path = "/version/1/account/#{path_segment(client.email)}"

    client
    |> request(:get, path, headers: auth_headers(client))
    |> Response.account()
  end

  def history(%__MODULE__{} = client, history_key) when is_binary(history_key) do
    path = "/version/1/history/#{path_segment(history_key)}"

    client
    |> request(:get, path, headers: common_headers())
    |> Response.history(history_key)
  end

  def history_page(%__MODULE__{} = client, history_key, start_index)
      when is_binary(history_key) and is_integer(start_index) and start_index >= 0 do
    path = "/version/1/history/#{path_segment(history_key)}/items"

    client
    |> request(:get, path,
      headers: common_headers(),
      params: [{"start-index", Integer.to_string(start_index)}]
    )
    |> Response.page()
  end

  def commit(%__MODULE__{} = client, history_key, ancestor_index, body)
      when is_binary(history_key) and is_integer(ancestor_index) and is_binary(body) do
    path = "/version/1/history/#{path_segment(history_key)}/commit"

    request(client, :post, path,
      headers: write_headers(),
      params: [
        {"ancestor-index", Integer.to_string(ancestor_index)},
        {"_cnt", "1"}
      ],
      body: body
    )
  end

  def request(%__MODULE__{} = client, method, path, opts) do
    call_transport(
      client.transport,
      method,
      client.endpoint <> path,
      Keyword.put_new(opts, :receive_timeout, @receive_timeout)
    )
  rescue
    _exception -> {:error, %{kind: :transport_exception}}
  catch
    kind, _reason -> {:error, %{kind: kind}}
  end

  defp call_transport(transport, method, url, opts) when is_function(transport, 3) do
    transport.(method, url, opts)
  end

  defp call_transport(module, method, url, opts) when is_atom(module) do
    module.request(method, url, opts)
  end

  defp valid_transport(transport) when is_function(transport, 3), do: :ok

  defp valid_transport(module) when is_atom(module) do
    if function_exported?(module, :request, 3) do
      :ok
    else
      config_error(:invalid_transport)
    end
  end

  defp valid_transport(_transport), do: config_error(:invalid_transport)

  defp present(value, _reason) when is_binary(value) and value != "", do: :ok
  defp present(_value, reason), do: auth_error(reason)

  defp same_email(email, email), do: :ok
  defp same_email(_expected, _actual), do: auth_error(:connection_account_mismatch)

  defp safe_password(password) when is_binary(password) do
    if String.contains?(password, ["\r", "\n"]) do
      auth_error(:invalid_lease_credential)
    else
      :ok
    end
  end

  defp auth_error(reason) do
    {:error,
     Error.auth("Things Cloud connection and credential lease do not match", reason: reason)}
  end

  defp config_error(reason) do
    {:error, Error.config("Things Cloud runtime transport is invalid", key: reason)}
  end

  defp normalize_endpoint(endpoint) when is_binary(endpoint),
    do: String.trim_trailing(endpoint, "/")

  defp normalize_endpoint(_endpoint), do: ""

  defp auth_headers(%__MODULE__{password: password}) do
    encoded_password = URI.encode(password, &URI.char_unreserved?/1)
    [{"authorization", "Password #{encoded_password}"} | common_headers()]
  end

  defp common_headers do
    [
      {"accept", "application/json"},
      {"accept-charset", "UTF-8"},
      {"accept-language", "en-US,en;q=0.9"},
      {"user-agent", @things_user_agent},
      {"things-client-info", client_info_header()}
    ]
  end

  defp write_headers do
    common_headers() ++
      [
        {"schema", "301"},
        {"push-priority", "5"},
        {"app-instance-id", @app_instance_id},
        {"app-id", @app_id},
        {"content-type", "application/json; charset=UTF-8"},
        {"content-encoding", "UTF-8"}
      ]
  end

  defp client_info_header do
    %{
      dm: "MacBookPro18,3",
      lr: "US",
      nf: true,
      nk: true,
      nn: "ThingsMac",
      nv: "32209501",
      on: "macOS",
      ov: "15.7.3",
      pl: "en-US",
      ul: "en-Latn-US"
    }
    |> Jason.encode!()
    |> Base.encode64()
  end

  defp path_segment(value), do: URI.encode(to_string(value), &URI.char_unreserved?/1)

  defp option(opts, key) when is_list(opts), do: Keyword.get(opts, key)
  defp option(opts, key) when is_map(opts), do: Map.get(opts, key)
end

defimpl Inspect, for: Jido.Connect.Things.Client do
  import Inspect.Algebra

  def inspect(client, opts) do
    binding =
      client.expected_email
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 12)

    doc =
      to_doc(
        %{
          endpoint: client.endpoint,
          account_binding: binding,
          transport_injected?: client.transport_injected?
        },
        opts
      )

    concat(["#Jido.Connect.Things.Client<", doc, ">"])
  end
end
