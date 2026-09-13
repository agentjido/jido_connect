defmodule Jido.Connect.Dev.PublicUrl do
  @moduledoc "Resolves local-demo public base URLs from options, env, or ngrok."

  alias Jido.Connect.Dev.Ngrok
  alias Jido.Connect.Error

  @spec resolve(keyword(), [String.t()]) :: {:ok, String.t()} | {:error, Error.error()}
  def resolve(opts \\ [], env_keys \\ []) do
    case explicit_url(opts, env_keys) do
      nil ->
        with {:ok, url} <- Ngrok.public_url(), do: validate_url(url)

      url ->
        validate_url(url)
    end
  end

  @spec resolve!(keyword(), [String.t()]) :: String.t()
  def resolve!(opts \\ [], env_keys \\ []) do
    case resolve(opts, env_keys) do
      {:ok, url} -> url
      {:error, error} -> raise error
    end
  end

  defp explicit_url(opts, env_keys) do
    opts[:url] ||
      Enum.find_value(env_keys, fn key ->
        case System.get_env(key) do
          nil -> nil
          "" -> nil
          value -> value
        end
      end)
  end

  defp validate_url(url) when is_binary(url) do
    url = String.trim(url)

    case URI.parse(url) do
      %URI{scheme: scheme, host: host, userinfo: nil, query: nil, fragment: nil}
      when scheme in ["http", "https"] and is_binary(host) and host != "" and url != "" ->
        if String.match?(url, ~r/\s/) do
          invalid_url()
        else
          {:ok, String.trim_trailing(url, "/")}
        end

      _other ->
        invalid_url()
    end
  rescue
    ArgumentError -> invalid_url()
  end

  defp validate_url(_url), do: invalid_url()

  defp invalid_url, do: {:error, Error.config("Invalid public base URL", key: :url)}
end
