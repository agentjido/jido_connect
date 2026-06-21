defmodule Jido.Connect.Nextcloud.Client.Credentials do
  @moduledoc false

  alias Jido.Connect.Error

  @type t :: %{
          base_url: String.t(),
          auth: {:basic, String.t()} | {:bearer, String.t()},
          login_name: String.t() | nil
        }

  @spec from_runtime(map()) :: {:ok, t()} | {:error, Error.AuthError.t()}
  def from_runtime(%{credentials: credentials}) when is_map(credentials) do
    from_credentials(credentials)
  end

  def from_runtime(_runtime), do: {:error, Error.auth("Nextcloud credentials are required")}

  @spec from_credentials(map()) :: {:ok, t()} | {:error, Error.AuthError.t()}
  def from_credentials(credentials) when is_map(credentials) do
    base_url = credentials[:base_url] || credentials["base_url"]
    login_name = credentials[:login_name] || credentials["login_name"]
    app_password = credentials[:app_password] || credentials["app_password"]
    access_token = credentials[:access_token] || credentials["access_token"]

    cond do
      blank?(base_url) ->
        {:error,
         Error.auth("Nextcloud base_url credential is required", reason: :missing_base_url)}

      present?(login_name) and present?(app_password) ->
        {:ok,
         %{
           base_url: normalize_base_url(base_url),
           auth: {:basic, Base.encode64("#{login_name}:#{app_password}")},
           login_name: login_name
         }}

      present?(access_token) ->
        {:ok,
         %{
           base_url: normalize_base_url(base_url),
           auth: {:bearer, access_token},
           login_name: login_name
         }}

      true ->
        {:error,
         Error.auth("Nextcloud app password or access token credential is required",
           reason: :missing_credentials
         )}
    end
  end

  def authorization_header(%{auth: {:basic, value}}), do: {"authorization", "Basic #{value}"}
  def authorization_header(%{auth: {:bearer, value}}), do: {"authorization", "Bearer #{value}"}

  defp normalize_base_url(base_url) when is_binary(base_url) do
    base_url
    |> String.trim()
    |> String.trim_trailing("/")
  end

  defp present?(value), do: not blank?(value)
  defp blank?(value), do: value in [nil, ""]
end
