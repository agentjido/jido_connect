defmodule Jido.Connect.Google.Drive.CollectionChanges do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Checkpoint

  @folder_mime_type "application/vnd.google-apps.folder"
  @collection_lookup_fields "id,name,mimeType,driveId"

  def init_checkpoint(client, config, access_token) do
    with {:ok, config} <- resolve_config(client, config, access_token),
         {:ok, %{start_page_token: start_page_token}} <-
           client.get_start_page_token(token_params(config), access_token) do
      {:ok, %{signals: [], checkpoint: start_page_token, has_more?: false}}
    end
  end

  def list(client, config, checkpoint, access_token) when is_binary(checkpoint) do
    with {:ok, config} <- resolve_config(client, config, access_token) do
      params = Map.put(config, :page_token, checkpoint)
      fetch_changes(client, params, checkpoint, access_token)
    end
  end

  def resolve_config(client, config, access_token) do
    config = normalize_config(config)

    with {:ok, collection_id} <- collection_id(config),
         {:ok, drive_id} <- resolve_drive_id(client, config, collection_id, access_token) do
      {:ok, configure_change_log(config, collection_id, drive_id)}
    end
  end

  def normalize_config(config) do
    config
    |> Data.atomize_existing_keys()
    |> Map.drop([:cursor, :checkpoint, :fields])
    |> Map.put_new(:page_size, 100)
    |> Map.put_new(:spaces, "drive")
    |> Map.put_new(:include_items_from_all_drives, false)
    |> Map.put_new(:include_removed, true)
    |> Map.put_new(:restrict_to_my_drive, false)
    |> Map.put_new(:supports_all_drives, false)
    |> trim_string(:collection_id)
    |> trim_string(:drive_id)
  end

  defp fetch_changes(client, params, checkpoint, access_token) do
    case fetch_pages(client, params, access_token, [], nil, MapSet.new([checkpoint])) do
      {:error, %Error.ProviderError{} = error} ->
        if Checkpoint.expired_provider_error?(error) do
          Checkpoint.expired("Google Drive collection changes", checkpoint, error)
        else
          {:error, error}
        end

      result ->
        result
    end
  end

  defp token_params(config) do
    config
    |> Map.take([:drive_id, :supports_all_drives])
    |> Map.put_new(:supports_all_drives, false)
  end

  defp fetch_pages(client, params, access_token, signals, latest_checkpoint, seen) do
    with {:ok, result} <- client.list_changes(Map.delete(params, :collection_id), access_token) do
      collection_id = Map.get(params, :collection_id)
      page_signals = normalize_signals(Map.get(result, :changes, []), collection_id)
      signals = signals ++ page_signals
      latest_checkpoint = Map.get(result, :new_start_page_token) || latest_checkpoint

      case Map.get(result, :next_page_token) do
        nil ->
          {:ok,
           %{
             signals: dedupe_signals(signals),
             checkpoint: latest_checkpoint || Map.fetch!(params, :page_token),
             has_more?: false
           }}

        page_token ->
          if MapSet.member?(seen, page_token) do
            invalid_repeated_page_token(page_token)
          else
            fetch_pages(
              client,
              Map.put(params, :page_token, page_token),
              access_token,
              signals,
              latest_checkpoint,
              MapSet.put(seen, page_token)
            )
          end
      end
    end
  end

  defp normalize_signals(changes, nil),
    do: Enum.map(changes, &normalize_signal(&1, nil, :unknown))

  defp normalize_signals(changes, ""), do: Enum.map(changes, &normalize_signal(&1, nil, :unknown))

  defp normalize_signals(changes, collection_id) do
    changes
    |> Enum.map(&{&1, collection_match(&1, collection_id)})
    |> Enum.map(fn {change, match} -> normalize_signal(change, collection_id, match) end)
  end

  defp collection_id(config) do
    case Map.get(config, :collection_id) do
      collection_id when is_binary(collection_id) and collection_id != "" ->
        {:ok, collection_id}

      _other ->
        {:error,
         Error.validation("Google Drive collection_id must be a non-empty string",
           reason: :invalid_drive_collection,
           details: %{field: :collection_id}
         )}
    end
  end

  defp resolve_drive_id(_client, %{drive_id: drive_id}, _collection_id, _access_token)
       when is_binary(drive_id) and drive_id != "",
       do: {:ok, drive_id}

  defp resolve_drive_id(client, _config, collection_id, access_token) do
    with {:ok, file} <-
           client.get_file(
             %{
               file_id: collection_id,
               fields: @collection_lookup_fields,
               supports_all_drives: true
             },
             access_token
           ) do
      {:ok, Map.get(file, :drive_id)}
    end
  end

  defp configure_change_log(config, collection_id, nil) do
    config
    |> Map.put(:collection_id, collection_id)
    |> Map.delete(:drive_id)
  end

  defp configure_change_log(config, collection_id, drive_id) do
    config
    |> Map.put(:collection_id, collection_id)
    |> Map.put(:drive_id, drive_id)
    |> Map.put(:include_items_from_all_drives, true)
    |> Map.put(:restrict_to_my_drive, false)
    |> Map.put(:supports_all_drives, true)
  end

  defp trim_string(config, field) do
    case Map.get(config, field) do
      value when is_binary(value) -> Map.put(config, field, String.trim(value))
      _other -> config
    end
  end

  defp collection_match(change, collection_id) do
    file = Map.get(change, :file)

    cond do
      Map.get(change, :removed?, false) and is_nil(file) ->
        :unknown

      Map.get(change, :file_id) == collection_id ->
        :yes

      folder?(file) and Map.get(file, :file_id) == collection_id ->
        :yes

      is_map(file) and collection_id in Map.get(file, :parents, []) ->
        :yes

      is_nil(file) ->
        :unknown

      true ->
        :no
    end
  end

  defp normalize_signal(change, collection_id, collection_match) do
    file = Map.get(change, :file)

    %{
      collection_id: collection_id,
      collection_match: collection_match,
      provider: "google_drive",
      provider_record_id: Map.get(change, :file_id) || record_id(file),
      change_type: change_type(change),
      removed?: Map.get(change, :removed?, false),
      changed_at: Map.get(change, :time),
      record: record(file)
    }
    |> Data.compact()
  end

  defp change_type(%{removed?: true}), do: :deleted
  defp change_type(%{change_type: "file"}), do: :updated
  defp change_type(%{change_type: "drive"}), do: :updated
  defp change_type(_change), do: :unknown

  defp record(file) when is_map(file) do
    %{
      id: Map.get(file, :file_id),
      name: Map.get(file, :name),
      mime_type: Map.get(file, :mime_type),
      parents: Map.get(file, :parents, []),
      created_at: Map.get(file, :created_time),
      modified_at: Map.get(file, :modified_time),
      trashed?: Map.get(file, :trashed?),
      web_url: Map.get(file, :web_view_link)
    }
    |> Data.compact()
  end

  defp record(_file), do: nil

  defp record_id(file) when is_map(file), do: Map.get(file, :file_id)
  defp record_id(_file), do: nil

  defp folder?(%{mime_type: @folder_mime_type}), do: true
  defp folder?(_file), do: false

  defp dedupe_signals(signals) do
    {_seen, unique} =
      Enum.reduce(signals, {MapSet.new(), []}, fn signal, {seen, acc} ->
        key = {
          Map.get(signal, :collection_id),
          Map.get(signal, :change_type),
          Map.get(signal, :provider_record_id),
          Map.get(signal, :changed_at)
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
    Checkpoint.invalid_response("Google Drive collection changes repeated nextPageToken", %{
      next_page_token: page_token
    })
  end
end
