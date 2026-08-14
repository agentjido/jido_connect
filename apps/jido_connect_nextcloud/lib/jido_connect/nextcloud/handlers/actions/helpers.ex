defmodule Jido.Connect.Nextcloud.Handlers.Actions.Helpers do
  @moduledoc false

  alias Jido.Connect.Nextcloud.Client.{Credentials, Transport}
  alias Jido.Connect.Nextcloud.Normalizer

  def credentials(runtime), do: Credentials.from_runtime(runtime)

  def public_map(value), do: Normalizer.public_map(value)

  def handle_dav_nodes_response(response, opts \\ []) do
    case response do
      {:ok, %{status: status, body: body}} when status in 200..299 and is_binary(body) ->
        Normalizer.dav_nodes(body, opts)

      {:ok, %{status: status, body: body}} when status in 200..299 ->
        Transport.invalid_success_response("Nextcloud WebDAV response was invalid", body)

      other ->
        Transport.handle_error_response(other, message: "Nextcloud WebDAV request failed")
    end
  end

  def handle_ocs_response(response, normalizer, message) do
    case response do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        with {:ok, data} <- Normalizer.ocs_data(body),
             {:ok, normalized} <- normalizer.(data) do
          {:ok, normalized}
        else
          {:error, _reason} = error -> error
        end

      other ->
        Transport.handle_error_response(other, message: message)
    end
  end

  def truthy_status(response, ok_statuses, attrs, message) do
    case response do
      {:ok, %{status: status} = response} ->
        if status in ok_statuses do
          {:ok, Map.merge(attrs, %{etag: header(response, "etag")})}
        else
          Transport.handle_error_response(response, message: message)
        end

      other ->
        Transport.handle_error_response(other, message: message)
    end
  end

  def header(%{headers: headers}, name) do
    headers
    |> Enum.find_value(fn {key, value} ->
      if String.downcase(to_string(key)) == name, do: List.wrap(value) |> List.first()
    end)
  end

  def header(_response, _name), do: nil
end
