defmodule Jido.Connect.Dev.Ngrok do
  @moduledoc """
  Local-development helpers for detecting ngrok public HTTPS tunnels.

  Discovery matches the requested local port. Use `api_url:` or the
  `:jido_connect, :ngrok_api_url` application setting if the ngrok API does not
  run on port 4040.
  """

  alias Jido.Connect.Error

  @api "http://127.0.0.1:4040/api/tunnels"

  @spec public_url(pos_integer(), keyword()) :: {:ok, String.t()} | {:error, Error.error()}
  def public_url(local_port \\ 4000, opts \\ [])
      when is_integer(local_port) and local_port > 0 and is_list(opts) do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    api_url =
      Keyword.get(opts, :api_url, Application.get_env(:jido_connect, :ngrok_api_url, @api))

    case :httpc.request(:get, {String.to_charlist(api_url), []}, [], body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        body
        |> Jason.decode!()
        |> Map.get("tunnels", [])
        |> select_public_url(local_port)
        |> case do
          {:ok, url} ->
            {:ok, url}

          {:error, :not_found} ->
            {:error, Error.config("No HTTPS ngrok tunnel found for local port", key: :ngrok)}

          {:error, :ambiguous} ->
            {:error, Error.config("More than one ngrok tunnel matches local port", key: :ngrok)}
        end

      {:ok, {{_, status, _}, _headers, body}} ->
        {:error,
         Error.config("Unable to inspect ngrok tunnels",
           key: :ngrok,
           details: %{status: status, body: body}
         )}

      {:error, reason} ->
        {:error,
         Error.config("Unable to inspect ngrok tunnels", key: :ngrok, details: %{reason: reason})}
    end
  rescue
    error ->
      {:error,
       Error.config("Unable to inspect ngrok tunnels", key: :ngrok, details: %{error: error})}
  end

  @doc false
  @spec select_public_url(term(), pos_integer()) ::
          {:ok, String.t()} | {:error, :not_found | :ambiguous}
  def select_public_url(tunnels, local_port)
      when is_list(tunnels) and is_integer(local_port) and local_port > 0 do
    urls =
      tunnels
      |> Enum.flat_map(fn
        %{"public_url" => "https://" <> _ = url, "config" => %{"addr" => addr}} ->
          if local_target?(addr, local_port), do: [url], else: []

        _other ->
          []
      end)
      |> Enum.uniq()

    case urls do
      [url] -> {:ok, url}
      [] -> {:error, :not_found}
      _multiple -> {:error, :ambiguous}
    end
  end

  def select_public_url(_tunnels, _local_port), do: {:error, :not_found}

  defp local_target?(addr, local_port) when is_binary(addr) do
    if addr == Integer.to_string(local_port) do
      true
    else
      url = if String.contains?(addr, "://"), do: addr, else: "http://" <> addr
      uri = URI.parse(url)

      uri.scheme == "http" and uri.host in ["localhost", "127.0.0.1", "::1"] and
        uri.port == local_port
    end
  end

  defp local_target?(_addr, _local_port), do: false

  @spec public_url!() :: String.t()
  def public_url! do
    case public_url() do
      {:ok, url} -> url
      {:error, error} -> raise error
    end
  end
end
