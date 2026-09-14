defmodule Mix.Tasks.Jido.Connect.Ngrok do
  @moduledoc """
  Starts an ngrok tunnel for a local Jido Connect demo host.

      mix jido.connect.ngrok
      mix jido.connect.ngrok --port 4001
      mix jido.connect.ngrok --provider github
      mix jido.connect.ngrok --provider slack

  The task runs until interrupted. It assumes `ngrok` is installed and available
  on `PATH`.
  """

  use Mix.Task

  alias Jido.Connect.Dev.Ngrok

  @shortdoc "Starts an ngrok tunnel for local Jido Connect demos"
  @default_port 4000
  @ngrok_api ~c"http://127.0.0.1:4040/api/tunnels"

  @impl Mix.Task
  def run(args) do
    {opts, _argv, invalid} =
      OptionParser.parse(args,
        strict: [
          authtoken: :string,
          port: :integer,
          host_header: :string,
          pooling_enabled: :boolean,
          provider: :string
        ]
      )

    if invalid != [] do
      Mix.raise("invalid options: #{inspect(invalid)}")
    end

    port = Keyword.get(opts, :port, @default_port)

    unless System.find_executable("ngrok") do
      Mix.raise("ngrok was not found on PATH. Install it from https://ngrok.com/download")
    end

    configure_authtoken(opts)

    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    ngrok_args = build_ngrok_args(port, opts)

    Mix.shell().info("Starting: ngrok #{Enum.join(ngrok_args, " ")}")
    Mix.shell().info("This task stays attached. Press Ctrl-C to stop ngrok.")

    port_ref =
      Port.open(
        {:spawn_executable, System.find_executable("ngrok")},
        [
          {:args, ngrok_args},
          :exit_status,
          {:line, 2048},
          :stderr_to_stdout
        ]
      )

    port_ref
    |> await_tunnel_url(port)
    |> print_urls(port, Keyword.get(opts, :provider))

    stream_ngrok(port_ref)
  end

  defp build_ngrok_args(port, opts) do
    ["http", Integer.to_string(port), "--log", "stdout"]
    |> maybe_host_header(opts)
    |> maybe_pooling(opts)
  end

  defp maybe_host_header(args, opts) do
    case Keyword.get(opts, :host_header) do
      nil -> args
      host_header -> args ++ ["--host-header=#{host_header}"]
    end
  end

  defp maybe_pooling(args, opts) do
    if Keyword.get(opts, :pooling_enabled, false) do
      args ++ ["--pooling-enabled"]
    else
      args
    end
  end

  defp configure_authtoken(opts) do
    authtoken = Keyword.get(opts, :authtoken) || System.get_env("NGROK_AUTHTOKEN")

    if is_binary(authtoken) and authtoken != "" do
      Mix.shell().info("Configuring ngrok authtoken from local secret input.")

      case System.cmd("ngrok", ["config", "add-authtoken", authtoken], stderr_to_stdout: true) do
        {_output, 0} ->
          :ok

        {output, status} ->
          Mix.raise("ngrok authtoken configuration failed with status #{status}:\n#{output}")
      end
    end
  end

  defp await_tunnel_url(port_ref, local_port, attempts_left \\ 60)

  defp await_tunnel_url(_port_ref, _local_port, 0),
    do: Mix.raise("ngrok did not expose a public HTTPS tunnel for the requested port")

  defp await_tunnel_url(port_ref, local_port, attempts_left) do
    receive do
      {^port_ref, {:data, {:eol, line}}} ->
        Mix.shell().info("[ngrok] #{line}")

        case tunnel_url_from_log(line) do
          {:ok, url} -> url
          :error -> await_tunnel_url(port_ref, local_port, attempts_left)
        end

      {^port_ref, {:data, {:noeol, line}}} ->
        Mix.shell().info("[ngrok] #{line}")

        case tunnel_url_from_log(line) do
          {:ok, url} -> url
          :error -> await_tunnel_url(port_ref, local_port, attempts_left)
        end

      {^port_ref, {:exit_status, status}} ->
        Mix.raise("ngrok exited before exposing a tunnel, status #{status}")
    after
      500 ->
        case tunnel_url(local_port) do
          {:ok, url} -> url
          :error -> await_tunnel_url(port_ref, local_port, attempts_left - 1)
        end
    end
  end

  defp tunnel_url(local_port) do
    case :httpc.request(:get, {@ngrok_api, []}, [], body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        body
        |> Jason.decode!()
        |> Map.get("tunnels", [])
        |> Ngrok.select_public_url(local_port)
        |> case do
          {:ok, url} -> {:ok, url}
          {:error, _reason} -> :error
        end

      _other ->
        :error
    end
  rescue
    _error -> :error
  end

  defp tunnel_url_from_log(line) do
    line = IO.iodata_to_binary(line)

    case Regex.run(~r/url=(https:\/\/\S+)/, line) do
      [_match, url] -> {:ok, url}
      _other -> :error
    end
  end

  defp print_urls(public_url, local_port, provider) do
    Mix.shell().info("""

    Jido Connect local tunnel is ready.

    Local host:       http://localhost:#{local_port}
    Public base URL:  #{public_url}
    Health check:     #{public_url}/health
    Integrations:     #{public_url}/integrations
    """)

    if provider == "github" do
      print_github_urls(public_url)
    end

    if provider == "slack" do
      print_slack_urls(public_url)
    end
  end

  defp print_github_urls(public_url) do
    callback_url = public_url <> "/integrations/github/oauth/callback"
    webhook_url = public_url <> "/integrations/github/webhook"
    setup_url = public_url <> "/integrations/github/setup"

    Mix.shell().info("""
    GitHub App URLs:
    Callback URL:     #{callback_url}
    Webhook URL:      #{webhook_url}
    Setup URL:        #{setup_url}

    Local env keys:
    GITHUB_APP_ID=
    GITHUB_CLIENT_ID=
    GITHUB_CLIENT_SECRET=
    GITHUB_WEBHOOK_SECRET=
    GITHUB_PRIVATE_KEY_PATH=
    """)
  end

  defp print_slack_urls(public_url) do
    callback_url = public_url <> "/integrations/slack/oauth/callback"
    events_url = public_url <> "/integrations/slack/events"
    interactivity_url = public_url <> "/integrations/slack/interactivity"

    Mix.shell().info("""
    Slack App URLs:
    OAuth Redirect URL:      #{callback_url}
    Events Request URL:      #{events_url}
    Interactivity Request URL: #{interactivity_url}

    Local env keys:
    SLACK_CLIENT_ID=
    SLACK_CLIENT_SECRET=
    SLACK_SIGNING_SECRET=
    SLACK_BOT_TOKEN=
    """)
  end

  defp stream_ngrok(port_ref) do
    receive do
      {^port_ref, {:data, {:eol, line}}} ->
        Mix.shell().info("[ngrok] #{line}")
        stream_ngrok(port_ref)

      {^port_ref, {:data, {:noeol, line}}} ->
        Mix.shell().info("[ngrok] #{line}")
        stream_ngrok(port_ref)

      {^port_ref, {:exit_status, status}} ->
        Mix.raise("ngrok exited with status #{status}")
    end
  end
end
