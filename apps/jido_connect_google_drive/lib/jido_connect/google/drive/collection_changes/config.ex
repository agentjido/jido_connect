defmodule Jido.Connect.Google.Drive.CollectionChanges.Config do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  @folder_mime_type "application/vnd.google-apps.folder"
  @collection_lookup_fields "id,mimeType,driveId"
  @default_page_size 100
  @max_page_size 1000
  @derived_fields [
    :fields,
    :spaces,
    :drive_id,
    :include_corpus_removals,
    :include_items_from_all_drives,
    :include_removed,
    :restrict_to_my_drive,
    :include_permissions_for_view,
    :include_labels,
    :supports_all_drives
  ]

  def resolve(client, config, access_token) when is_map(config) do
    config = normalize(config)

    with {:ok, collection_id} <- collection_id(config),
         :ok <- validate_page_size(config),
         {:ok, drive_id} <- collection_drive_id(client, collection_id, access_token) do
      {:ok, change_log_config(config, collection_id, drive_id)}
    end
  end

  def resolve(_client, _config, _access_token), do: invalid_collection_id()

  def start_page_token_params(config) do
    config
    |> Map.take([:drive_id, :supports_all_drives])
    |> Map.put_new(:supports_all_drives, false)
  end

  defp normalize(config) do
    config
    |> Data.atomize_existing_keys()
    |> Map.drop([:cursor, :checkpoint] ++ @derived_fields)
    |> Map.put_new(:page_size, @default_page_size)
    |> trim_string(:collection_id)
  end

  defp collection_id(config) do
    case Map.get(config, :collection_id) do
      collection_id when is_binary(collection_id) and collection_id != "" ->
        {:ok, collection_id}

      _other ->
        invalid_collection_id()
    end
  end

  defp validate_page_size(config) do
    case Map.get(config, :page_size) do
      value when is_integer(value) and value >= 1 and value <= @max_page_size ->
        :ok

      value ->
        {:error,
         Error.validation("Google Drive collection page_size is invalid",
           reason: :invalid_drive_collection,
           details: %{field: :page_size, value: value, min: 1, max: @max_page_size}
         )}
    end
  end

  defp collection_drive_id(client, collection_id, access_token) do
    with {:ok, file} <-
           client.get_file(
             %{
               file_id: collection_id,
               fields: @collection_lookup_fields,
               supports_all_drives: true
             },
             access_token
           ),
         :ok <- validate_collection(file, collection_id) do
      {:ok, Map.get(file, :drive_id)}
    end
  end

  defp validate_collection(file, collection_id) when is_map(file) do
    file_id = Map.get(file, :file_id)
    mime_type = Map.get(file, :mime_type)

    if file_id == collection_id and mime_type == @folder_mime_type do
      :ok
    else
      {:error,
       Error.validation("Google Drive collection_id must identify a folder",
         reason: :invalid_drive_collection,
         details:
           Data.compact(%{
             field: :collection_id,
             value: collection_id,
             returned_id: file_id,
             mime_type: mime_type
           })
       )}
    end
  end

  defp validate_collection(_file, collection_id) do
    {:error,
     Error.validation("Google Drive collection_id must identify a folder",
       reason: :invalid_drive_collection,
       details: %{field: :collection_id, value: collection_id}
     )}
  end

  defp change_log_config(config, collection_id, nil) do
    Map.merge(config, %{
      collection_id: collection_id,
      spaces: "drive",
      include_items_from_all_drives: false,
      include_removed: true,
      restrict_to_my_drive: false,
      supports_all_drives: false
    })
  end

  defp change_log_config(config, collection_id, drive_id) do
    Map.merge(config, %{
      collection_id: collection_id,
      drive_id: drive_id,
      spaces: "drive",
      include_items_from_all_drives: true,
      include_removed: true,
      restrict_to_my_drive: false,
      supports_all_drives: true
    })
  end

  defp trim_string(config, field) do
    case Map.get(config, field) do
      value when is_binary(value) -> Map.put(config, field, String.trim(value))
      _other -> config
    end
  end

  defp invalid_collection_id do
    {:error,
     Error.validation("Google Drive collection_id must be a non-empty string",
       reason: :invalid_drive_collection,
       details: %{field: :collection_id}
     )}
  end
end
