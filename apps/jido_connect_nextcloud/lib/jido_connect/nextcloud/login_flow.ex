defmodule Jido.Connect.Nextcloud.LoginFlow do
  @moduledoc """
  Helpers for Nextcloud Login Flow v2 app-password creation.

  Hosts own browser launch, polling cadence, credential storage, and state.
  """

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Nextcloud.Client.Transport

  def init(base_url, opts \\ []) when is_binary(base_url) do
    base_url = normalize_base_url(base_url)

    Req.new(base_url: base_url, headers: [{"accept", "application/json"}])
    |> Req.merge(Application.get_env(:jido_connect_nextcloud, :nextcloud_login_req_options, []))
    |> Req.merge(Keyword.get(opts, :req_options, []))
    |> Req.post(url: "/index.php/login/v2")
    |> case do
      {:ok, %{status: status, body: body}} when status in 200..299 and is_map(body) ->
        {:ok,
         %{
           login: Data.get(body, "login"),
           poll: Data.get(body, "poll")
         }}

      response ->
        Transport.handle_error_response(response,
          message: "Failed to initialize Nextcloud login flow"
        )
    end
  end

  def poll(endpoint, token, opts \\ []) when is_binary(endpoint) and is_binary(token) do
    Req.new(base_url: endpoint, headers: [{"accept", "application/json"}])
    |> Req.merge(Application.get_env(:jido_connect_nextcloud, :nextcloud_login_req_options, []))
    |> Req.merge(Keyword.get(opts, :req_options, []))
    |> Req.post(form: %{token: token})
    |> case do
      {:ok, %{status: 404}} ->
        {:error,
         Error.provider("Nextcloud login flow is still pending",
           provider: :nextcloud,
           reason: :pending
         )}

      {:ok, %{status: status, body: body}} when status in 200..299 and is_map(body) ->
        {:ok,
         %{
           base_url: normalize_base_url(Data.get(body, "server")),
           login_name: Data.get(body, "loginName"),
           app_password: Data.get(body, "appPassword")
         }}

      response ->
        Transport.handle_error_response(response, message: "Failed to poll Nextcloud login flow")
    end
  end

  defp normalize_base_url(base_url) do
    base_url
    |> String.trim()
    |> String.trim_trailing("/")
  end
end
