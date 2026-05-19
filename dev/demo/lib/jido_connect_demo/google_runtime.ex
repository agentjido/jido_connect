defmodule Jido.Connect.Demo.GoogleRuntime do
  @moduledoc false

  alias Jido.Connect
  alias Jido.Connect.Demo.Store
  alias Jido.Connect.Google.{Connections, Scopes}

  alias Jido.Connect.Google.{
    Calendar,
    Drive,
    Sheets
  }

  alias Jido.Connect.Gmail

  @google_modules [Sheets, Gmail, Drive, Calendar]

  @default_scopes Scopes.user_default() ++
                    Scopes.product(:sheets) ++
                    Scopes.product(:gmail) ++
                    Scopes.product(:drive) ++
                    Scopes.product(:calendar)

  # ---------------------------------------------------------------------------
  # Connection management
  # ---------------------------------------------------------------------------

  def create_oauth_connection(token, attrs \\ %{}) when is_map(token) do
    owner_id = Map.get(attrs, "owner_id", "local-google-user")
    tenant_id = Map.get(attrs, "tenant_id", "local")
    credential_ref = "demo:google-oauth-#{owner_id}"
    scopes = token_scopes(token)

    {:ok, connection} =
      Connections.user_connection(
        %{"scope" => scopes},
        id: "google-oauth-#{owner_id}",
        tenant_id: tenant_id,
        owner_type: :app_user,
        owner_id: owner_id,
        status: :connected,
        credential_ref: credential_ref,
        scopes: scopes,
        metadata: %{mode: :google_oauth}
      )

    Store.put_credential(credential_ref, credential_fields(token))
    Store.put_connection(connection)
  end

  def create_manual_connection(attrs \\ %{}) do
    token = Map.get(attrs, "token") || env_value("GOOGLE_ACCESS_TOKEN")
    owner_id = Map.get(attrs, "owner_id", "local-google-user")
    tenant_id = Map.get(attrs, "tenant_id", "local")
    credential_ref = "demo:google-manual-#{owner_id}"

    {:ok, connection} =
      Connections.user_connection(
        %{"scope" => @default_scopes},
        id: "google-manual-#{owner_id}",
        tenant_id: tenant_id,
        owner_type: :app_user,
        owner_id: owner_id,
        status: if(blank?(token), do: :needs_credentials, else: :connected),
        credential_ref: credential_ref,
        scopes: @default_scopes,
        metadata: %{mode: :manual_access_token}
      )

    if not blank?(token) do
      Store.put_credential(credential_ref, %{
        access_token: token,
        refresh_token: Map.get(attrs, "refresh_token") || env_value("GOOGLE_REFRESH_TOKEN")
      })
    end

    Store.put_connection(connection)
  end

  # ---------------------------------------------------------------------------
  # Context and lease helpers
  # ---------------------------------------------------------------------------

  def context_and_lease(connection_id, opts \\ []) do
    with {:ok, connection} <- Store.get_connection(connection_id),
         {:ok, lease} <- lease_for(connection, opts) do
      context =
        Connect.Context.new!(%{
          tenant_id: connection.tenant_id,
          actor: %{id: connection.owner_id, type: connection.owner_type},
          connection: connection
        })

      {:ok, context, lease}
    end
  end

  # ---------------------------------------------------------------------------
  # Catalog operations
  # ---------------------------------------------------------------------------

  @doc "Returns the list of Google integration modules used by the demo."
  def google_modules, do: @google_modules

  @doc "Discovers catalog entries across all demo Google modules."
  def catalog_entries(opts \\ []) do
    modules = Keyword.get(opts, :modules, @google_modules)

    opts
    |> Keyword.put(:modules, modules)
    |> Connect.Catalog.discover()
    |> Enum.map(&Connect.Catalog.to_map/1)
  end

  @doc "Searches catalog tools matching a query across all Google modules."
  def search_catalog(query, opts \\ []) do
    modules = Keyword.get(opts, :modules, @google_modules)

    Connect.Catalog.discover(modules: modules)
    |> Enum.flat_map(fn entry ->
      entry.actions
      |> Enum.filter(fn action ->
        action.id =~ query or
          (action.label && action.label =~ query) or
          (action.description && action.description =~ query)
      end)
      |> Enum.map(fn action ->
        %{id: action.id, label: action.label, package: entry.package, provider: entry.name}
      end)
    end)
  end

  @doc "Returns a single catalog entry for a specific module."
  def describe(module) when is_atom(module) do
    Connect.Catalog.entry(module)
    |> Connect.Catalog.to_map()
  end

  # ---------------------------------------------------------------------------
  # Tool invocation helpers
  # ---------------------------------------------------------------------------

  def run_get_values(connection_id, params, opts \\ []) do
    call_product_tool(connection_id, "google.sheets.values.get", params, Sheets, opts)
  end

  def run_gmail_list_messages(connection_id, params, opts \\ []) do
    call_product_tool(
      connection_id,
      "google.gmail.messages.list",
      params,
      Gmail,
      Keyword.put(opts, :pack, :google_gmail_metadata)
    )
  end

  def run_gmail_get_profile(connection_id, params, opts \\ []) do
    call_product_tool(
      connection_id,
      "google.gmail.profile.get",
      params,
      Gmail,
      Keyword.put(opts, :pack, :google_gmail_metadata)
    )
  end

  def run_drive_list_files(connection_id, params, opts \\ []) do
    call_product_tool(
      connection_id,
      "google.drive.files.list",
      params,
      Drive,
      Keyword.put(opts, :pack, :google_drive_readonly)
    )
  end

  def run_drive_get_about(connection_id, params, opts \\ []) do
    call_product_tool(
      connection_id,
      "google.drive.about.get",
      params,
      Drive,
      Keyword.put(opts, :pack, :google_drive_readonly)
    )
  end

  def run_calendar_list_events(connection_id, params, opts \\ []) do
    call_product_tool(
      connection_id,
      "google.calendar.event.list",
      params,
      Calendar,
      Keyword.put(opts, :pack, :google_calendar_reader)
    )
  end

  def run_calendar_list_calendars(connection_id, params, opts \\ []) do
    call_product_tool(
      connection_id,
      "google.calendar.calendar.list",
      params,
      Calendar,
      Keyword.put(opts, :pack, :google_calendar_reader)
    )
  end

  defp call_product_tool(connection_id, tool_id, params, module, opts) do
    with {:ok, context, lease} <- context_and_lease(connection_id, opts) do
      Connect.Catalog.call_tool(
        tool_id,
        params,
        modules: [module],
        packs: module.catalog_packs(),
        pack: Keyword.get(opts, :pack),
        context: context,
        credential_lease: lease
      )
    end
  end

  # ---------------------------------------------------------------------------
  # Environment helpers
  # ---------------------------------------------------------------------------

  def env do
    %{
      "GOOGLE_CLIENT_ID" => present?("GOOGLE_CLIENT_ID"),
      "GOOGLE_CLIENT_SECRET" => present?("GOOGLE_CLIENT_SECRET"),
      "GOOGLE_REDIRECT_URI" => present?("GOOGLE_REDIRECT_URI"),
      "GOOGLE_ACCESS_TOKEN" => present?("GOOGLE_ACCESS_TOKEN"),
      "GOOGLE_REFRESH_TOKEN" => present?("GOOGLE_REFRESH_TOKEN"),
      "GOOGLE_SHEETS_SPREADSHEET_ID" => present?("GOOGLE_SHEETS_SPREADSHEET_ID")
    }
  end

  def env_value(name)
      when name in [
             "GOOGLE_CLIENT_ID",
             "GOOGLE_CLIENT_SECRET",
             "GOOGLE_REDIRECT_URI",
             "GOOGLE_ACCESS_TOKEN",
             "GOOGLE_REFRESH_TOKEN",
             "GOOGLE_SHEETS_SPREADSHEET_ID"
           ] do
    local_env(name)
  end

  def scopes, do: @default_scopes

  # ---------------------------------------------------------------------------
  # Lease internals
  # ---------------------------------------------------------------------------

  defp lease_for(%Connect.Connection{} = connection, opts) do
    credentials = Store.get_credential(connection.credential_ref)

    token =
      Keyword.get(opts, :access_token) || credentials[:access_token] ||
        env_value("GOOGLE_ACCESS_TOKEN")

    if blank?(token) do
      {:error,
       Connect.Error.config("Google access token is required", key: "GOOGLE_ACCESS_TOKEN")}
    else
      Connect.CredentialLease.from_connection(
        connection,
        %{
          access_token: token,
          google_sheets_client: Keyword.get(opts, :google_sheets_client) ||
            Application.get_env(:jido_connect_demo, :google_sheets_client, Sheets.Client),
          gmail_client: Keyword.get(opts, :gmail_client) ||
            Application.get_env(:jido_connect_demo, :gmail_client, Gmail.Client),
          google_drive_client: Keyword.get(opts, :google_drive_client) ||
            Application.get_env(:jido_connect_demo, :google_drive_client, Drive.Client),
          google_calendar_client: Keyword.get(opts, :google_calendar_client) ||
            Application.get_env(:jido_connect_demo, :google_calendar_client, Calendar.Client)
        },
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        metadata: %{mode: connection.metadata.mode}
      )
    end
  end

  defp credential_fields(token) do
    %{
      access_token: Map.get(token, :access_token) || Map.get(token, "access_token"),
      refresh_token: Map.get(token, :refresh_token) || Map.get(token, "refresh_token"),
      expires_at: Map.get(token, :expires_at) || Map.get(token, "expires_at"),
      scope: token_scopes(token)
    }
  end

  defp token_scopes(token) do
    token
    |> Map.get(:scope, Map.get(token, "scope", @default_scopes))
    |> Scopes.normalize()
    |> case do
      [] -> @default_scopes
      scopes -> scopes
    end
  end

  defp present?(name), do: not blank?(local_env(name))

  defp local_env(name) do
    System.get_env(name) || maybe_read_dotenv(name)
  end

  defp maybe_read_dotenv(name) do
    if Application.get_env(:jido_connect_demo, :read_dotenv?, true) do
      read_dotenv(name)
    end
  end

  defp read_dotenv(name) do
    Enum.find_value(dotenv_paths(), fn path ->
      if File.exists?(path), do: read_dotenv_value(path, name)
    end)
  end

  defp dotenv_paths do
    [
      Path.expand(".env", File.cwd!()),
      Path.expand("../../.env", File.cwd!()),
      Path.expand("../../../../.env", __DIR__)
    ]
    |> Enum.uniq()
  end

  defp read_dotenv_value(path, name) do
    path
    |> File.stream!()
    |> Enum.find_value(fn line ->
      line = String.trim(line)

      cond do
        line == "" -> nil
        String.starts_with?(line, "#") -> nil
        not String.starts_with?(line, name <> "=") -> nil
        true -> line |> String.split("=", parts: 2) |> List.last() |> unquote_value()
      end
    end)
  end

  defp unquote_value(value) do
    value
    |> String.trim()
    |> String.trim_leading("\"")
    |> String.trim_trailing("\"")
    |> String.trim_leading("'")
    |> String.trim_trailing("'")
  end

  defp blank?(value), do: is_nil(value) or value == ""
end
