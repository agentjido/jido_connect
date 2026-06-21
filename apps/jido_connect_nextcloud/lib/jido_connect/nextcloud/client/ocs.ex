defmodule Jido.Connect.Nextcloud.Client.OCS do
  @moduledoc "Nextcloud OCS API client."

  alias Jido.Connect.Nextcloud.Client.Transport

  @share_base "/ocs/v2.php/apps/files_sharing/api/v1"
  @sharee_base "/ocs/v1.php/apps/files_sharing/api/v1"

  def capabilities(credentials) do
    credentials
    |> ocs_request()
    |> Transport.request(:get, url: "/ocs/v2.php/cloud/capabilities")
  end

  def list_shares(credentials, params \\ %{}) do
    credentials
    |> ocs_request()
    |> Transport.request(:get, url: "#{@share_base}/shares", params: clean_params(params))
  end

  def get_share(credentials, share_id) do
    credentials
    |> ocs_request()
    |> Transport.request(:get, url: "#{@share_base}/shares/#{share_id}")
  end

  def create_share(credentials, params) do
    credentials
    |> ocs_request()
    |> Transport.request(:post, url: "#{@share_base}/shares", form: clean_params(params))
  end

  def update_share(credentials, share_id, params) do
    credentials
    |> ocs_request()
    |> Transport.request(:put,
      url: "#{@share_base}/shares/#{share_id}",
      form: clean_params(params)
    )
  end

  def delete_share(credentials, share_id) do
    credentials
    |> ocs_request()
    |> Transport.request(:delete, url: "#{@share_base}/shares/#{share_id}")
  end

  def search_sharees(credentials, params) do
    credentials
    |> ocs_request()
    |> Transport.request(:get, url: "#{@sharee_base}/sharees", params: clean_params(params))
  end

  def office_launch_token(credentials, file_id, app_id, app_secret) do
    credentials
    |> ocs_request()
    |> Transport.request(:get,
      url: "/index.php/apps/richdocuments/wopi/extapp/data/#{file_id}",
      params: %{app_id: app_id, app_secret: app_secret}
    )
  end

  defp ocs_request(credentials) do
    Transport.request(credentials,
      accept: "application/json",
      headers: [
        {"ocs-apirequest", "true"},
        {"content-type", "application/x-www-form-urlencoded"}
      ]
    )
  end

  defp clean_params(params) do
    params
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    |> Map.new(fn {key, value} -> {key, normalize_value(value)} end)
  end

  defp normalize_value(true), do: "true"
  defp normalize_value(false), do: "false"
  defp normalize_value(value), do: value
end
