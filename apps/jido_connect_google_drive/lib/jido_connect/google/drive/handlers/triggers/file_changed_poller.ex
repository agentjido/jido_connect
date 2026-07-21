defmodule Jido.Connect.Google.Drive.Handlers.Triggers.FileChangedPoller do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Google.Checkpoint
  alias Jido.Connect.Google.Drive.Client

  def poll(config, %{credentials: credentials, checkpoint: checkpoint}) do
    with {:ok, client} <- fetch_client(credentials) do
      poll_changes(
        client,
        normalize_config(config),
        checkpoint,
        Map.get(credentials, :access_token)
      )
    end
  end

  defp poll_changes(client, config, checkpoint, access_token) when checkpoint in [nil, ""] do
    with {:ok, %{start_page_token: start_page_token}} <-
           client.get_start_page_token(config, access_token) do
      {:ok, %{signals: [], checkpoint: start_page_token}}
    end
  end

  defp poll_changes(client, config, checkpoint, access_token) do
    params = Map.put(config, :page_token, checkpoint)

    case fetch_change_pages(client, params, access_token, [], nil, MapSet.new([checkpoint])) do
      {:error, %Error.ProviderError{} = error} ->
        if Checkpoint.expired_provider_error?(error) do
          Checkpoint.expired("Google Drive change token", checkpoint, error)
        else
          {:error, error}
        end

      result ->
        result
    end
  end

  defp fetch_change_pages(client, params, access_token, signals, latest_start_page_token, seen) do
    with {:ok, result} <- client.list_changes(params, access_token) do
      signals = signals ++ Enum.map(Map.get(result, :changes, []), &normalize_signal/1)
      latest_start_page_token = Map.get(result, :new_start_page_token) || latest_start_page_token

      case Map.get(result, :next_page_token) do
        nil ->
          {:ok,
           %{
             signals: dedupe_signals(signals),
             checkpoint: latest_start_page_token || Map.fetch!(params, :page_token)
           }}

        page_token ->
          if MapSet.member?(seen, page_token) do
            invalid_repeated_page_token(page_token)
          else
            fetch_change_pages(
              client,
              Map.put(params, :page_token, page_token),
              access_token,
              signals,
              latest_start_page_token,
              MapSet.put(seen, page_token)
            )
          end
      end
    end
  end

  defp normalize_config(config) do
    config
    |> Map.put_new(:page_size, 100)
    |> Map.put_new(:spaces, "drive")
    |> Map.put_new(:include_items_from_all_drives, false)
    |> Map.put_new(:include_removed, true)
    |> Map.put_new(:restrict_to_my_drive, false)
    |> Map.put_new(:supports_all_drives, false)
  end

  defp normalize_signal(change) do
    %{
      file_id: Map.get(change, :file_id),
      removed: Map.get(change, :removed?, false),
      time: Map.get(change, :time),
      drive_id: Map.get(change, :drive_id),
      change_type: Map.get(change, :change_type),
      file: public_map(Map.get(change, :file))
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp dedupe_signals(signals) do
    {_seen, unique} =
      Enum.reduce(signals, {MapSet.new(), []}, fn signal, {seen, acc} ->
        key =
          {
            Map.get(signal, :change_type),
            Map.get(signal, :file_id),
            Map.get(signal, :drive_id),
            Map.get(signal, :time)
          }

        cond do
          key == {nil, nil, nil, nil} ->
            {seen, acc}

          MapSet.member?(seen, key) ->
            {seen, acc}

          true ->
            {MapSet.put(seen, key), [signal | acc]}
        end
      end)

    Enum.reverse(unique)
  end

  defp invalid_repeated_page_token(page_token) do
    Checkpoint.invalid_response("Google Drive change list response repeated nextPageToken", %{
      next_page_token: page_token
    })
  end

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(list) when is_list(list), do: Enum.map(list, &public_map/1)

  defp public_map(map) when is_map(map) do
    map
    |> Map.update(:owners, [], &public_map/1)
    |> Map.update(:permissions, [], &public_map/1)
    |> Map.update(:file, nil, &public_map/1)
  end

  defp public_map(value), do: value

  defp fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
