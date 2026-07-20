defmodule Jido.Connect.Google.Drive.CollectionChanges do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Checkpoint

  @folder_mime_type "application/vnd.google-apps.folder"

  def init_checkpoint(client, config, access_token) do
    with {:ok, %{start_page_token: start_page_token}} <-
           client.get_start_page_token(token_params(config), access_token) do
      {:ok, %{signals: [], checkpoint: start_page_token, has_more?: false}}
    end
  end

  def list(client, config, checkpoint, access_token) when is_binary(checkpoint) do
    params = normalize_config(config) |> Map.put(:page_token, checkpoint)

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

  def normalize_config(config) do
    config
    |> Map.delete(:cursor)
    |> Map.delete(:checkpoint)
    |> Map.put_new(:page_size, 100)
    |> Map.put_new(:spaces, "drive")
    |> Map.put_new(:include_items_from_all_drives, false)
    |> Map.put_new(:include_removed, true)
    |> Map.put_new(:restrict_to_my_drive, false)
    |> Map.put_new(:supports_all_drives, false)
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
    |> Enum.reject(fn {_change, match} -> match == :no end)
    |> Enum.map(fn {change, match} -> normalize_signal(change, collection_id, match) end)
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
