defmodule Jido.Connect.DemoWeb.IntegrationController do
  use Jido.Connect.DemoWeb, :controller

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Demo.{GitHubRuntime, GoogleRuntime, Ngrok, SlackRuntime, Store}
  alias Jido.Connect.Google.OAuth, as: GoogleOAuth
  alias Jido.Connect.GitHub.{OAuth, Webhook}
  alias Jido.Connect.Slack.Webhook, as: SlackWebhook

  def index(conn, _params) do
    json(conn, %{integrations: Jido.Connect.Demo.Integrations.api_index()})
  end

  def catalog(conn, params) do
    filters =
      [
        query: Map.get(params, "q") || Map.get(params, "query"),
        status: Map.get(params, "status"),
        category: Map.get(params, "category"),
        auth_kind: Map.get(params, "auth_kind"),
        tool: Map.get(params, "tool")
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)

    json(conn, %{catalog: Jido.Connect.Demo.Integrations.catalog(filters)})
  end

  def health(conn, _params), do: json(conn, %{ok: true})

  def github_show(conn, _params) do
    render(conn, :github,
      public_url: Ngrok.public_base_url(),
      github_urls: Ngrok.github_urls(),
      github_install_url: github_install_url(),
      env: github_env(),
      connections: Store.list_connections(:github),
      deliveries: Store.recent_deliveries(),
      results: Store.recent_results()
    )
  end

  def slack_show(conn, _params) do
    maybe_create_slack_env_connection()

    render(conn, :slack,
      public_url: Ngrok.public_base_url(),
      slack_urls: Ngrok.slack_urls(),
      env: SlackRuntime.env(),
      connections: Store.list_connections(:slack),
      deliveries: Store.recent_deliveries(),
      results: Store.recent_results()
    )
  end

  def google_show(conn, _params) do
    google_catalog = GoogleRuntime.catalog_entries()

    render(conn, :google,
      public_url: Ngrok.public_base_url(),
      google_urls: Ngrok.google_urls(),
      env: GoogleRuntime.env(),
      scopes: GoogleRuntime.scopes(),
      connections: Store.list_connections(:google),
      results: Store.recent_results(),
      default_spreadsheet_id: GoogleRuntime.env_value("GOOGLE_SHEETS_SPREADSHEET_ID") || "",
      google_catalog: google_catalog
    )
  end

  def github_setup(conn, _params) do
    text(conn, "GitHub setup endpoint is reachable.\n")
  end

  def github_setup_complete(conn, %{"installation_id" => installation_id} = params) do
    connection =
      installation_id
      |> String.to_integer()
      |> GitHubRuntime.create_installation_connection(params)

    Store.put_result(:github_setup, :ok, %{connection_id: connection.id})

    redirect(conn, to: ~p"/integrations/github")
  end

  def github_setup_complete(conn, %{"code" => code}) do
    path = write_secret!("github-app-code.txt", code)

    text(conn, """
    GitHub App manifest code captured.

    Stored: #{path}

    Run from the repo root:
    mix jido.connect.github.app.convert #{code}
    """)
  end

  def github_setup_complete(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> text("missing manifest code\n")
  end

  def github_oauth_start(conn, params) do
    client_id = Map.get(params, "client_id") || System.get_env("GITHUB_CLIENT_ID")

    if blank?(client_id) do
      conn
      |> put_status(:bad_request)
      |> json(%{ok: false, error: "missing GITHUB_CLIENT_ID"})
    else
      state = random_token()
      write_secret!("github-oauth-state.txt", state)

      redirect(conn,
        external:
          OAuth.authorize_url(
            client_id: client_id,
            redirect_uri: github_callback_url(conn),
            scope: Map.get(params, "scope", "repo"),
            state: state
          )
      )
    end
  end

  def github_oauth_callback(conn, params) do
    installation_connection = maybe_store_installation_connection(params)
    stored_state = read_secret("github-oauth-state.txt")
    app_install_callback? = not blank?(Map.get(params, "installation_id"))

    result =
      cond do
        blank?(Map.get(params, "code")) ->
          %{ok: false, error: "missing code", params: params}

        not app_install_callback? and not blank?(stored_state) and
            Map.get(params, "state") != stored_state ->
          %{ok: false, error: "invalid state", params: params}

        true ->
          %{ok: true, params: params}
      end

    write_secret!("github-oauth-callback.json", Jason.encode!(result, pretty: true))

    cond do
      not result.ok ->
        conn
        |> put_status(:bad_request)
        |> json(result)

      blank?(System.get_env("GITHUB_CLIENT_SECRET")) ->
        Store.put_result(
          :github_oauth,
          :captured,
          Map.merge(result, installation_result(installation_connection))
        )

        redirect(conn, to: ~p"/integrations/github")

      true ->
        exchange_oauth_callback(conn, params, installation_connection)
    end
  end

  def google_oauth_start(conn, params) do
    client_id = Map.get(params, "client_id") || GoogleRuntime.env_value("GOOGLE_CLIENT_ID")

    if blank?(client_id) do
      conn
      |> put_status(:bad_request)
      |> json(%{ok: false, error: "missing GOOGLE_CLIENT_ID"})
    else
      state = random_token()
      write_secret!("google-oauth-state.txt", state)

      redirect(conn,
        external:
          GoogleOAuth.authorize_url(
            client_id: client_id,
            redirect_uri: google_callback_url(conn),
            scope: google_oauth_scope(params),
            state: state,
            prompt: Map.get(params, "prompt", "consent")
          )
      )
    end
  end

  def google_oauth_callback(conn, params) do
    stored_state = read_secret("google-oauth-state.txt")

    result =
      cond do
        blank?(Map.get(params, "code")) ->
          %{ok: false, error: "missing code", params: params}

        not blank?(stored_state) and Map.get(params, "state") != stored_state ->
          %{ok: false, error: "invalid state", params: params}

        true ->
          %{ok: true, params: Map.drop(params, ["code"])}
      end

    write_secret!("google-oauth-callback.json", Jason.encode!(result, pretty: true))

    cond do
      not result.ok ->
        conn
        |> put_status(:bad_request)
        |> json(result)

      blank?(GoogleRuntime.env_value("GOOGLE_CLIENT_SECRET")) ->
        Store.put_result(:google_oauth, :captured, result)
        redirect(conn, to: ~p"/integrations/google")

      true ->
        exchange_google_oauth_callback(conn, params)
    end
  end

  def github_manual_connection(conn, params) do
    connection = GitHubRuntime.create_manual_connection(params)
    Store.put_result(:connection, :ok, %{connection_id: connection.id, mode: :manual_token})
    redirect(conn, to: ~p"/integrations/github")
  end

  def google_manual_connection(conn, params) do
    connection = GoogleRuntime.create_manual_connection(params)

    Store.put_result(:google_connection, :ok, %{
      connection_id: connection.id,
      mode: connection.metadata.mode
    })

    redirect(conn, to: ~p"/integrations/google")
  end

  def slack_bot_connection(conn, params) do
    case SlackRuntime.create_bot_connection(params) do
      {:ok, connection} ->
        Store.put_result(:slack_connection, :ok, %{
          connection_id: connection.id,
          team: connection.metadata.team,
          mode: :bot_token
        })

      {:error, reason} ->
        Store.put_result(:slack_connection, :error, reason)
    end

    redirect(conn, to: ~p"/integrations/slack")
  end

  def github_list_issues(conn, params) do
    connection_id = Map.fetch!(params, "connection_id")
    action_params = %{repo: Map.fetch!(params, "repo"), state: Map.get(params, "state", "open")}

    result = GitHubRuntime.run_list_issues(connection_id, action_params)
    Store.put_result(:github_issue_list, result_status(result), result)
    redirect(conn, to: ~p"/integrations/github")
  end

  def google_get_values(conn, params) do
    connection_id = Map.fetch!(params, "connection_id")

    action_params =
      %{
        spreadsheet_id: Map.fetch!(params, "spreadsheet_id"),
        range: Map.get(params, "range", "Sheet1!A1:B2")
      }
      |> Data.compact()

    result = GoogleRuntime.run_get_values(connection_id, action_params)
    Store.put_result(:google_sheets_values_get, result_status(result), result)
    redirect(conn, to: ~p"/integrations/google")
  end

  def google_gmail_list_messages(conn, params) do
    connection_id = Map.fetch!(params, "connection_id")

    action_params =
      %{
        max_results: params |> Map.get("max_results", "10") |> parse_integer(10),
        query: Map.get(params, "query")
      }
      |> Data.compact()

    result = GoogleRuntime.run_gmail_list_messages(connection_id, action_params)
    Store.put_result(:google_gmail_messages_list, result_status(result), result)
    redirect(conn, to: ~p"/integrations/google")
  end

  def google_gmail_get_profile(conn, params) do
    connection_id = Map.fetch!(params, "connection_id")

    result = GoogleRuntime.run_gmail_get_profile(connection_id, %{})
    Store.put_result(:google_gmail_profile_get, result_status(result), result)
    redirect(conn, to: ~p"/integrations/google")
  end

  def google_drive_list_files(conn, params) do
    connection_id = Map.fetch!(params, "connection_id")

    action_params =
      %{
        page_size: params |> Map.get("page_size", "10") |> parse_integer(10),
        query: Map.get(params, "query")
      }
      |> Data.compact()

    result = GoogleRuntime.run_drive_list_files(connection_id, action_params)
    Store.put_result(:google_drive_files_list, result_status(result), result)
    redirect(conn, to: ~p"/integrations/google")
  end

  def google_drive_get_about(conn, params) do
    connection_id = Map.fetch!(params, "connection_id")

    result = GoogleRuntime.run_drive_get_about(connection_id, %{})
    Store.put_result(:google_drive_about_get, result_status(result), result)
    redirect(conn, to: ~p"/integrations/google")
  end

  def google_calendar_list_events(conn, params) do
    connection_id = Map.fetch!(params, "connection_id")

    action_params =
      %{
        calendar_id: Map.get(params, "calendar_id", "primary"),
        max_results: params |> Map.get("max_results", "10") |> parse_integer(10),
        time_min: Map.get(params, "time_min"),
        time_max: Map.get(params, "time_max")
      }
      |> Data.compact()

    result = GoogleRuntime.run_calendar_list_events(connection_id, action_params)
    Store.put_result(:google_calendar_events_list, result_status(result), result)
    redirect(conn, to: ~p"/integrations/google")
  end

  def google_calendar_list_calendars(conn, params) do
    connection_id = Map.fetch!(params, "connection_id")

    result = GoogleRuntime.run_calendar_list_calendars(connection_id, %{})
    Store.put_result(:google_calendar_calendars_list, result_status(result), result)
    redirect(conn, to: ~p"/integrations/google")
  end

  def slack_list_channels(conn, params) do
    connection_id = Map.fetch!(params, "connection_id")

    action_params =
      %{
        types: Map.get(params, "types", "public_channel"),
        exclude_archived: truthy?(Map.get(params, "exclude_archived", "true")),
        limit: params |> Map.get("limit", "100") |> parse_integer(100),
        cursor: Map.get(params, "cursor"),
        team_id: Map.get(params, "team_id")
      }
      |> Data.compact()

    result = SlackRuntime.run_list_channels(connection_id, action_params)
    Store.put_result(:slack_channel_list, result_status(result), result)
    redirect(conn, to: ~p"/integrations/slack")
  end

  def github_create_issue(conn, params) do
    connection_id = Map.fetch!(params, "connection_id")

    action_params = %{
      repo: Map.fetch!(params, "repo"),
      title: Map.fetch!(params, "title"),
      body: Map.get(params, "body"),
      labels: []
    }

    result = GitHubRuntime.run_create_issue(connection_id, action_params)
    Store.put_result(:github_issue_create, result_status(result), result)
    redirect(conn, to: ~p"/integrations/github")
  end

  def slack_post_message(conn, params) do
    connection_id = Map.fetch!(params, "connection_id")

    action_params =
      %{
        channel: Map.fetch!(params, "channel"),
        text: Map.fetch!(params, "text"),
        thread_ts: Map.get(params, "thread_ts"),
        reply_broadcast: truthy?(Map.get(params, "reply_broadcast"))
      }
      |> Data.compact()

    result = SlackRuntime.run_post_message(connection_id, action_params)
    Store.put_result(:slack_message_post, result_status(result), result)
    redirect(conn, to: ~p"/integrations/slack")
  end

  def github_poll_new_issues(conn, params) do
    connection_id = Map.fetch!(params, "connection_id")
    result = GitHubRuntime.poll_new_issues(connection_id, %{repo: Map.fetch!(params, "repo")})
    Store.put_result(:github_issue_poll, result_status(result), result)
    redirect(conn, to: ~p"/integrations/github")
  end

  def slack_oauth_callback(conn, params) do
    path = write_secret!("slack-oauth-callback.json", Jason.encode!(params, pretty: true))
    Store.put_result(:slack_oauth, :captured, %{stored: path, params: Map.drop(params, ["code"])})
    redirect(conn, to: ~p"/integrations/slack")
  end

  defp exchange_oauth_callback(conn, params, installation_connection) do
    with {:ok, token} <-
           OAuth.exchange_code(Map.fetch!(params, "code"),
             redirect_uri: github_callback_url(conn),
             state: Map.get(params, "state")
           ),
         connection <- GitHubRuntime.create_manual_connection(%{"token" => token.access_token}) do
      Store.put_result(
        :github_oauth,
        :ok,
        %{connection_id: connection.id, scopes: token.scope}
        |> Map.merge(installation_result(installation_connection))
      )

      redirect(conn, to: ~p"/integrations/github")
    else
      {:error, reason} ->
        if installation_connection do
          Store.put_result(:github_oauth, :error, %{
            reason: reason,
            installation_connection_id: installation_connection.id
          })

          redirect(conn, to: ~p"/integrations/github")
        else
          Store.put_result(:github_oauth, :error, reason)

          conn
          |> put_status(:bad_request)
          |> json(%{ok: false, error: inspect(reason)})
        end
    end
  end

  defp exchange_google_oauth_callback(conn, params) do
    with {:ok, token} <-
           GoogleOAuth.exchange_code(Map.fetch!(params, "code"),
             client_id: GoogleRuntime.env_value("GOOGLE_CLIENT_ID"),
             client_secret: GoogleRuntime.env_value("GOOGLE_CLIENT_SECRET"),
             redirect_uri: google_callback_url(conn)
           ),
         connection <- GoogleRuntime.create_oauth_connection(token) do
      token_path =
        write_secret!("google-oauth-token.json", Jason.encode!(json_safe(token), pretty: true))

      Store.put_result(:google_oauth, :ok, %{
        connection_id: connection.id,
        scopes: token.scope,
        token_path: token_path
      })

      redirect(conn, to: ~p"/integrations/google")
    else
      {:error, reason} ->
        Store.put_result(:google_oauth, :error, reason)

        conn
        |> put_status(:bad_request)
        |> json(%{ok: false, error: inspect(reason)})
    end
  end

  def github_webhook(conn, _params) do
    delivery = get_req_header(conn, "x-github-delivery") |> List.first() || "local"
    event = get_req_header(conn, "x-github-event") |> List.first() || "unknown"

    body = conn.assigns[:raw_body] || ""

    headers = %{
      "x-github-delivery" => delivery,
      "x-github-event" => event,
      "x-hub-signature-256" => get_req_header(conn, "x-hub-signature-256") |> List.first()
    }

    with {:ok, verified} <-
           Webhook.verify_delivery(body, headers, System.get_env("GITHUB_WEBHOOK_SECRET"),
             seen_delivery_ids: known_delivery_ids()
           ) do
      path = write_secret!("github-webhook-#{delivery}.json", body)
      signal = normalize_webhook_signal(verified)

      Store.put_delivery(%{
        delivery_id: verified.delivery_id,
        event: verified.event,
        duplicate?: verified.duplicate?,
        signal: signal,
        stored: path,
        received_at: verified.received_at
      })

      json(conn, %{
        ok: true,
        event: event,
        delivery: delivery,
        stored: path,
        signal: signal
      })
    else
      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{ok: false, error: inspect(reason)})
    end
  end

  def slack_events(conn, _params) do
    body = conn.assigns[:raw_body] || ""

    headers = %{
      "x-slack-signature" => get_req_header(conn, "x-slack-signature") |> List.first(),
      "x-slack-request-timestamp" =>
        get_req_header(conn, "x-slack-request-timestamp") |> List.first()
    }

    with {:ok, delivery} <-
           SlackWebhook.verify_delivery(body, headers, slack_signing_secret(),
             seen_delivery_ids: known_delivery_ids()
           ),
         payload = delivery.payload,
         {:challenge, {:error, %Error.ProviderError{reason: :not_url_verification}}} <-
           {:challenge, SlackWebhook.url_verification_challenge(payload)} do
      delivery_id = delivery.delivery_id || "slack-#{System.unique_integer([:positive])}"
      event = delivery.event || "unknown"
      signal = normalize_slack_signal(payload)
      path = write_secret!("slack-event-#{delivery_id}.json", body)

      Store.put_delivery(%{
        delivery_id: delivery_id,
        event: event,
        duplicate?: delivery.duplicate?,
        signal: signal,
        stored: path,
        received_at: delivery.received_at
      })

      json(conn, %{ok: true, event: event, delivery: delivery_id, signal: signal})
    else
      {:challenge, {:ok, challenge}} ->
        text(conn, challenge)

      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{ok: false, error: inspect(reason)})
    end
  end

  def slack_interactivity(conn, _params) do
    body = conn.assigns[:raw_body] || ""

    headers = %{
      "x-slack-signature" => get_req_header(conn, "x-slack-signature") |> List.first(),
      "x-slack-request-timestamp" =>
        get_req_header(conn, "x-slack-request-timestamp") |> List.first()
    }

    case SlackWebhook.verify_signature(body, headers, slack_signing_secret()) do
      :ok ->
        Store.put_result(:slack_interactivity, :captured, %{bytes: byte_size(body)})
        json(conn, %{ok: true})

      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{ok: false, error: inspect(reason)})
    end
  end

  defp github_callback_url(_conn) do
    base_url =
      case Ngrok.public_base_url() do
        nil -> Jido.Connect.DemoWeb.Endpoint.url()
        "" -> Jido.Connect.DemoWeb.Endpoint.url()
        url -> url
      end

    base_url <> ~p"/integrations/github/oauth/callback"
  end

  defp google_callback_url(_conn) do
    case GoogleRuntime.env_value("GOOGLE_REDIRECT_URI") do
      nil ->
        google_default_callback_url()

      "" ->
        google_default_callback_url()

      redirect_uri ->
        redirect_uri
    end
  end

  defp google_default_callback_url do
    base_url =
      case Ngrok.public_base_url() do
        nil -> Jido.Connect.DemoWeb.Endpoint.url()
        "" -> Jido.Connect.DemoWeb.Endpoint.url()
        url -> url
      end

    base_url <> ~p"/integrations/google/oauth/callback"
  end

  defp google_oauth_scope(params) do
    case Map.get(params, "scope") do
      nil -> GoogleRuntime.scopes()
      "" -> GoogleRuntime.scopes()
      scope -> scope
    end
  end

  defp github_install_url do
    case System.get_env("GITHUB_APP_SLUG") do
      nil -> nil
      "" -> nil
      slug -> "https://github.com/apps/#{slug}/installations/new"
    end
  end

  defp normalize_webhook_signal(%{event: event, payload: payload}) do
    case Webhook.normalize_signal(event, payload) do
      {:ok, signal} -> signal
      {:error, reason} -> %{error: reason}
    end
  end

  defp normalize_slack_signal(payload) do
    case SlackWebhook.normalize_event(payload) do
      {:ok, signal} -> signal
      {:error, reason} -> %{error: reason}
    end
  end

  defp known_delivery_ids do
    Jido.Connect.Demo.Store.recent_deliveries()
    |> Enum.map(& &1.delivery_id)
  end

  defp maybe_create_slack_env_connection do
    if SlackRuntime.env()["SLACK_BOT_TOKEN"] and Store.list_connections(:slack) == [] do
      case SlackRuntime.ensure_env_connection() do
        {:ok, connection} ->
          Store.put_result(:slack_connection, :ok, %{
            connection_id: connection.id,
            team: connection.metadata.team,
            mode: :env_bot_token
          })

        {:error, reason} ->
          Store.put_result(:slack_connection, :error, reason)
      end
    end
  end

  defp random_token do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp write_secret!(name, contents) do
    dir = secret_dir()
    File.mkdir_p!(dir)
    path = Path.join(dir, name)
    File.write!(path, contents)
    path
  end

  defp json_safe(%DateTime{} = value), do: DateTime.to_iso8601(value)

  defp json_safe(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)

  defp json_safe(%Date{} = value), do: Date.to_iso8601(value)

  defp json_safe(%Time{} = value), do: Time.to_iso8601(value)

  defp json_safe(%_struct{} = value), do: value |> Map.from_struct() |> json_safe()

  defp json_safe(value) when is_map(value) do
    Map.new(value, fn {key, item} -> {key, json_safe(item)} end)
  end

  defp json_safe(value) when is_list(value), do: Enum.map(value, &json_safe/1)

  defp json_safe(value), do: value

  defp read_secret(name) do
    secret_dir()
    |> Path.join(name)
    |> File.read()
    |> case do
      {:ok, contents} -> contents
      {:error, _reason} -> nil
    end
  end

  defp secret_dir do
    case System.get_env("JIDO_CONNECT_DEMO_SECRET_DIR") do
      nil -> default_secret_dir()
      "" -> default_secret_dir()
      dir -> Path.expand(dir)
    end
  end

  defp default_secret_dir do
    Path.expand("../../.secrets/dev-demo", File.cwd!())
  end

  defp maybe_store_installation_connection(%{"installation_id" => installation_id} = params) do
    case Integer.parse(installation_id) do
      {id, ""} ->
        connection = GitHubRuntime.create_installation_connection(id, params)
        Store.put_result(:github_setup, :ok, %{connection_id: connection.id})
        connection

      _other ->
        Store.put_result(:github_setup, :error, %{installation_id: installation_id})
        nil
    end
  end

  defp maybe_store_installation_connection(_params), do: nil

  defp installation_result(nil), do: %{}

  defp installation_result(connection) do
    %{installation_connection_id: connection.id}
  end

  defp github_env do
    %{
      "GITHUB_APP_ID" => present?("GITHUB_APP_ID"),
      "GITHUB_APP_SLUG" => present?("GITHUB_APP_SLUG"),
      "GITHUB_CLIENT_ID" => present?("GITHUB_CLIENT_ID"),
      "GITHUB_CLIENT_SECRET" => present?("GITHUB_CLIENT_SECRET"),
      "GITHUB_WEBHOOK_SECRET" => present?("GITHUB_WEBHOOK_SECRET"),
      "GITHUB_PRIVATE_KEY_PATH" => present?("GITHUB_PRIVATE_KEY_PATH"),
      "GITHUB_TOKEN" => present?("GITHUB_TOKEN")
    }
  end

  defp slack_signing_secret do
    SlackRuntime.env_value("SLACK_SIGNING_SECRET")
  end

  defp parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _other -> default
    end
  end

  defp parse_integer(value, _default) when is_integer(value), do: value
  defp parse_integer(_value, default), do: default

  defp present?(name), do: not blank?(System.get_env(name))
  defp result_status({:ok, _value}), do: :ok
  defp result_status({:ok, _state, _directives}), do: :ok
  defp result_status({:error, _reason}), do: :error

  defp truthy?(value), do: value in [true, "true", "1", "on", "yes"]

  defp blank?(value), do: is_nil(value) or value == ""
end
