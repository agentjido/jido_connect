defmodule Jido.Connect.Slack.Client.Presence do
  @moduledoc "Slack presence, profile-status, and custom-emoji API boundary."

  alias Jido.Connect.Data
  alias Jido.Connect.Slack.Client.{Response, Transport}

  def get_presence(access_token) when is_binary(access_token) do
    with {:ok, presence} <- get("/users.getPresence", %{}, access_token),
         {:ok, profile_response} <- get("/users.profile.get", %{}, access_token),
         {:ok, availability} <- normalize_availability(presence),
         {:ok, status} <- profile_response |> Data.get("profile") |> normalize_status() do
      {:ok, %{availability: availability, status: status}}
    end
  end

  def set_presence(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    with {:ok, _response} <- post("/users.setPresence", attrs, access_token) do
      {:ok, %{presence: Data.get(attrs, :presence)}}
    end
  end

  def set_status(attrs, access_token) when is_map(attrs) and is_binary(access_token),
    do: update_status(attrs, access_token)

  def clear_status(attrs, access_token) when is_map(attrs) and is_binary(access_token),
    do: update_status(attrs, access_token)

  def list_emoji(access_token) when is_binary(access_token) do
    with {:ok, response} <- get("/emoji.list", %{}, access_token),
         emoji when is_map(emoji) <- Data.get(response, "emoji"),
         {:ok, items} <- normalize_emoji(emoji) do
      {:ok, %{emoji: items}}
    else
      nil -> Transport.invalid_success_response("Slack emoji response was invalid", %{})
      {:error, _error} = error -> error
      _other -> Transport.invalid_success_response("Slack emoji response was invalid", %{})
    end
  end

  defp update_status(attrs, access_token) do
    with {:ok, response} <- post("/users.profile.set", attrs, access_token),
         {:ok, status} <- response |> Data.get("profile") |> normalize_status() do
      {:ok, %{status: status}}
    end
  end

  defp get(path, params, access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: path, params: params)
    |> Response.handle_map_response()
  end

  defp post(path, body, access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: path, json: body)
    |> Response.handle_map_response()
  end

  defp normalize_availability(response) when is_map(response) do
    presence = Data.get(response, "presence")

    if presence in ["active", "away"] and
         valid_optional_boolean?(response, "online") and
         valid_optional_boolean?(response, "auto_away") and
         valid_optional_boolean?(response, "manual_away") and
         valid_optional_non_negative_integer?(response, "connection_count") and
         valid_optional_unix_time?(response, "last_activity") do
      {:ok,
       %{
         state: presence,
         online: optional_boolean(response, "online"),
         automatic_away: optional_boolean(response, "auto_away"),
         manual_away: optional_boolean(response, "manual_away"),
         connection_count: optional_non_negative_integer(response, "connection_count"),
         last_activity_at:
           response |> optional_non_negative_integer("last_activity") |> unix_time()
       }
       |> Data.compact()}
    else
      Transport.invalid_success_response("Slack presence response was invalid", response)
    end
  end

  defp normalize_availability(response),
    do: Transport.invalid_success_response("Slack presence response was invalid", response)

  defp normalize_status(profile) when is_map(profile) do
    expiration = Data.get(profile, "status_expiration")

    if valid_optional_string?(profile, "status_text") and
         valid_optional_string?(profile, "status_emoji") and valid_unix_time?(expiration) do
      {:ok,
       %{
         text: Data.get(profile, "status_text", ""),
         emoji: Data.get(profile, "status_emoji", ""),
         expires_at: expiration |> nonzero() |> unix_time()
       }}
    else
      Transport.invalid_success_response("Slack profile status response was invalid", profile)
    end
  end

  defp normalize_status(profile),
    do: Transport.invalid_success_response("Slack profile status response was invalid", profile)

  defp normalize_emoji(emoji) do
    Enum.reduce_while(emoji, {:ok, []}, fn
      {name, "alias:" <> alias_for}, {:ok, items}
      when is_binary(name) and name != "" and alias_for != "" ->
        item = %{name: name, code: ":#{name}:", type: "alias", alias_for: alias_for}
        {:cont, {:ok, [item | items]}}

      {name, url}, {:ok, items} when is_binary(name) and name != "" and is_binary(url) ->
        case URI.new(url) do
          {:ok, %URI{scheme: scheme, host: host}}
          when scheme in ["http", "https"] and is_binary(host) and host != "" ->
            item = %{name: name, code: ":#{name}:", type: "image", image_url: url}
            {:cont, {:ok, [item | items]}}

          _error ->
            {:halt, Transport.invalid_success_response("Slack emoji response was invalid", emoji)}
        end

      _item, _result ->
        {:halt, Transport.invalid_success_response("Slack emoji response was invalid", emoji)}
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.sort_by(items, & &1.name)}
      {:error, _error} = error -> error
    end
  end

  defp valid_optional_string?(map, key),
    do: is_nil(Data.get(map, key)) or is_binary(Data.get(map, key))

  defp valid_optional_boolean?(map, key),
    do: is_nil(Data.get(map, key)) or is_boolean(Data.get(map, key))

  defp valid_optional_non_negative_integer?(map, key) do
    is_nil(Data.get(map, key)) or
      (is_integer(Data.get(map, key)) and Data.get(map, key) >= 0)
  end

  defp valid_optional_unix_time?(map, key), do: valid_unix_time?(Data.get(map, key))

  defp optional_boolean(map, key) do
    case Data.get(map, key) do
      value when is_boolean(value) -> value
      _value -> nil
    end
  end

  defp optional_non_negative_integer(map, key) do
    case Data.get(map, key) do
      value when is_integer(value) and value >= 0 -> value
      _value -> nil
    end
  end

  defp valid_unix_time?(nil), do: true
  defp valid_unix_time?(0), do: true

  defp valid_unix_time?(value) when is_integer(value) and value > 0,
    do: match?({:ok, _datetime}, DateTime.from_unix(value))

  defp valid_unix_time?(_value), do: false
  defp nonzero(0), do: nil
  defp nonzero(value), do: value
  defp unix_time(nil), do: nil

  defp unix_time(value) when is_integer(value) do
    case DateTime.from_unix(value) do
      {:ok, datetime} -> DateTime.to_iso8601(datetime)
      _error -> nil
    end
  end
end
