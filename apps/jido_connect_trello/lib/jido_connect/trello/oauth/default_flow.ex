defmodule Jido.Connect.Trello.OAuth.DefaultFlow do
  @moduledoc false

  @spec begin(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def begin(resource, opts) when is_binary(resource) and is_list(opts) do
    redirect_uri = Keyword.fetch!(opts, :redirect_uri)
    scopes = Keyword.get(opts, :scopes, [])

    with {:ok, protected} <- backend().discover_resource(resource, metadata_opts(opts)),
         {:ok, issuer} <- authorization_server(protected, opts),
         {:ok, metadata} <- backend().discover_authorization(issuer, metadata_opts(opts)),
         {:ok, client} <- oauth_client(metadata, redirect_uri, scopes, opts),
         {:ok, authorize_url, transaction} <-
           backend().start_authorization(%{
             client_id: client.client_id,
             redirect_uri: redirect_uri,
             authorization_endpoint: metadata["authorization_endpoint"],
             issuer: issuer,
             require_issuer: metadata["authorization_response_iss_parameter_supported"] == true,
             scopes: scopes,
             resource: resource
           }) do
      backend().abort(transaction.transaction_id)

      transaction =
        transaction
        |> Map.drop([:transaction_id])
        |> Map.merge(%{
          client_id: client.client_id,
          client_secret: client.client_secret,
          token_endpoint: metadata["token_endpoint"],
          resource: resource
        })

      {:ok,
       %{authorize_url: authorize_url, state: transaction.state_param, transaction: transaction}}
    end
  rescue
    _exception -> {:error, :trello_oauth_begin_failed}
  end

  @spec exchange_code(String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def exchange_code(code, transaction, opts)
      when is_binary(code) and is_map(transaction) and is_list(opts) do
    callback = Keyword.get(opts, :callback_params, %{})

    response = %{
      "code" => code,
      "state" => value(callback, :state),
      "iss" => value(callback, :iss)
    }

    legacy_transaction = %{
      state_param: value(transaction, :state_param),
      issuer: value(transaction, :issuer),
      require_issuer: value(transaction, :require_issuer),
      redirect_uri: value(transaction, :redirect_uri)
    }

    client = oauth_client_from_transaction(transaction)

    with {:ok, ^code} <- backend().validate_callback(response, legacy_transaction),
         {:ok, tokens} <-
           backend().exchange_code(%{
             code: code,
             code_verifier: value(transaction, :code_verifier),
             client_id: client["client_id"],
             client_secret: client["client_secret"],
             redirect_uri: value(transaction, :redirect_uri),
             token_endpoint: client["token_endpoint"],
             resource: value(transaction, :resource)
           }) do
      {:ok, Map.put(tokens, :oauth_client, client)}
    end
  rescue
    _exception -> {:error, :trello_oauth_exchange_failed}
  end

  @spec refresh_token(String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def refresh_token(refresh_token, oauth_client, opts)
      when is_binary(refresh_token) and is_map(oauth_client) and is_list(opts) do
    scope = Keyword.get(opts, :scope)

    refresh_opts =
      [client_secret: value(oauth_client, :client_secret), scope: normalize_scope(scope)]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    with {:ok, tokens} <-
           backend().refresh_token(
             refresh_token,
             value(oauth_client, :client_id),
             value(oauth_client, :token_endpoint),
             refresh_opts
           ) do
      {:ok, Map.put(tokens, :oauth_client, oauth_client)}
    end
  rescue
    _exception -> {:error, :trello_oauth_refresh_failed}
  end

  defp authorization_server(%{authorization_servers: servers}, opts) when is_list(servers) do
    configured = Keyword.get(opts, :authorization_server)

    issuers =
      Enum.map(servers, fn server -> value(server, :issuer) end)
      |> Enum.filter(&(is_binary(&1) and &1 != ""))
      |> Enum.uniq()

    case {configured, issuers} do
      {nil, [issuer]} ->
        {:ok, issuer}

      {issuer, issuers} when is_binary(issuer) ->
        if issuer in issuers, do: {:ok, issuer}, else: {:error, :authorization_server_mismatch}

      _result ->
        {:error, :authorization_server_ambiguous}
    end
  end

  defp authorization_server(_protected, _opts), do: {:error, :authorization_server_missing}

  defp oauth_client(metadata, redirect_uri, scopes, opts) do
    case Keyword.get(opts, :client_id) do
      client_id when is_binary(client_id) and client_id != "" ->
        {:ok,
         %{
           client_id: client_id,
           client_secret: Keyword.get(opts, :client_secret)
         }}

      _client_id ->
        register_client(metadata, redirect_uri, scopes, opts)
    end
  end

  defp register_client(%{"registration_endpoint" => endpoint}, redirect_uri, scopes, opts)
       when is_binary(endpoint) and endpoint != "" do
    backend().register_client(%{
      registration_endpoint: endpoint,
      client_name: Keyword.get(opts, :client_name, "Jido Connect Trello"),
      application_type: "web",
      redirect_uris: [redirect_uri],
      grant_types: ["authorization_code", "refresh_token"],
      response_types: ["code"],
      scope: Enum.join(scopes, " "),
      token_endpoint_auth_method: "none"
    })
  end

  defp register_client(_metadata, _redirect_uri, _scopes, _opts),
    do: {:error, :oauth_client_not_configured}

  defp oauth_client_from_transaction(transaction) do
    %{
      "client_id" => value(transaction, :client_id),
      "client_secret" => value(transaction, :client_secret),
      "token_endpoint" => value(transaction, :token_endpoint)
    }
  end

  defp metadata_opts(opts), do: Keyword.get(opts, :metadata_opts, [])

  defp backend do
    Application.get_env(
      :jido_connect_trello,
      :trello_oauth_backend,
      Jido.Connect.Trello.OAuth.DefaultFlow.ExMCPBackend
    )
  end

  defp normalize_scope(scopes) when is_list(scopes), do: Enum.join(scopes, " ")
  defp normalize_scope(scope) when is_binary(scope), do: scope
  defp normalize_scope(_scope), do: nil

  defp value(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
end
