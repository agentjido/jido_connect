defmodule Mix.Tasks.Jido.Connect.Ngrok do
  @moduledoc """
  Starts an ngrok tunnel for a local Jido Connect demo host.

      mix jido.connect.ngrok
      mix jido.connect.ngrok --port 4001
      mix jido.connect.ngrok --api-url http://127.0.0.1:4041/api/tunnels

  The task runs until interrupted. It assumes `ngrok` is installed and available
  on `PATH`.
  """

  use Mix.Task

  alias Jido.Connect.Dev.Ngrok

  @shortdoc "Starts an ngrok tunnel for local Jido Connect demos"
  @default_port 4000

  @impl Mix.Task
  def run(args) do
    {opts, _argv, invalid} =
      OptionParser.parse(args,
        strict: [
          authtoken: :string,
          port: :integer,
          host_header: :string,
          pooling_enabled: :boolean,
          api_url: :string
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
    |> await_tunnel_url(port, opts)
    |> print_urls(port)

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

  defp await_tunnel_url(port_ref, local_port, opts, attempts_left \\ 60)

  defp await_tunnel_url(_port_ref, _local_port, _opts, 0),
    do: Mix.raise("ngrok did not expose a public HTTPS tunnel for the requested port")

  defp await_tunnel_url(port_ref, local_port, opts, attempts_left) do
    receive do
      {^port_ref, {:data, {:eol, line}}} ->
        Mix.shell().info("[ngrok] #{line}")

        case tunnel_url_from_log(line) do
          {:ok, url} -> url
          :error -> await_tunnel_url(port_ref, local_port, opts, attempts_left)
        end

      {^port_ref, {:data, {:noeol, line}}} ->
        Mix.shell().info("[ngrok] #{line}")

        case tunnel_url_from_log(line) do
          {:ok, url} -> url
          :error -> await_tunnel_url(port_ref, local_port, opts, attempts_left)
        end

      {^port_ref, {:exit_status, status}} ->
        Mix.raise("ngrok exited before exposing a tunnel, status #{status}")
    after
      500 ->
        case tunnel_url(local_port, opts) do
          {:ok, url} -> url
          :error -> await_tunnel_url(port_ref, local_port, opts, attempts_left - 1)
        end
    end
  end

  defp tunnel_url(local_port, opts) do
    case Ngrok.public_url(local_port, Keyword.take(opts, [:api_url])) do
      {:ok, url} -> {:ok, url}
      {:error, _reason} -> :error
    end
  end

  defp tunnel_url_from_log(line) do
    line = IO.iodata_to_binary(line)

    case Regex.run(~r/url=(https:\/\/\S+)/, line) do
      [_match, url] -> {:ok, url}
      _other -> :error
    end
  end

  defp print_urls(public_url, local_port) do
    Mix.shell().info("""

    Jido Connect local tunnel is ready.

    Local host:       http://localhost:#{local_port}
    Public base URL:  #{public_url}
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
