defmodule Jido.Connect.OAuth do
  @moduledoc """
  Small shared OAuth helpers for provider packages.

  Provider packages still own provider-specific token response normalization,
  refresh behavior, and credential lease shaping. This module keeps the repeated
  mechanics consistent: required secret lookup, authorization URL building, and
  basic Req client defaults.
  """

  alias Jido.Connect.{Error, Http}

  @user_agent "jido-connect"

  @spec authorize_url(String.t(), map() | keyword()) :: String.t()
  def authorize_url(endpoint, params) when is_binary(endpoint) do
    params =
      params
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)

    Http.url_with_query(endpoint, params)
  end

  @spec fetch_required!(keyword(), atom(), String.t()) :: term()
  def fetch_required!(opts, key, env_key) when is_list(opts) and is_atom(key) do
    Keyword.get(opts, key) || System.get_env(env_key) ||
      raise Error.config("#{key} or #{env_key} is required", key: env_key)
  end

  @spec req(keyword()) :: Req.Request.t()
  def req(opts \\ []) do
    Req.new(
      base_url: Keyword.fetch!(opts, :base_url),
      auth: Keyword.get(opts, :auth),
      headers: headers(Keyword.get(opts, :headers, []))
    )
  end

  defp headers(headers) do
    [{"accept", "application/json"}, {"user-agent", @user_agent}]
    |> Kernel.++(headers)
    |> Enum.reverse()
    |> Enum.uniq_by(fn {key, _value} -> String.downcase(to_string(key)) end)
    |> Enum.reverse()
  end
end
