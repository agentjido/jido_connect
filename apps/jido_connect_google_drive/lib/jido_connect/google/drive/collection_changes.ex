defmodule Jido.Connect.Google.Drive.CollectionChanges do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Checkpoint
  alias Jido.Connect.Google.Drive.CollectionChanges.Config

  def init_checkpoint(client, config, access_token) do
    with {:ok, %{checkpoint: checkpoint}} <- start_checkpoint(client, config, access_token) do
      {:ok, %{signals: [], checkpoint: checkpoint, has_more?: false}}
    end
  end

  def start_checkpoint(client, config, access_token) do
    with {:ok, config} <- Config.resolve(client, config, access_token),
         {:ok, result} <-
           client.get_start_page_token(Config.start_page_token_params(config), access_token),
         {:ok, checkpoint} <- start_page_token(result) do
      {:ok, %{checkpoint: checkpoint, config: config}}
    end
  end

  def list(client, config, checkpoint, access_token) do
    with {:ok, checkpoint} <- normalize_checkpoint(checkpoint),
         {:ok, config} <- Config.resolve(client, config, access_token) do
      params = Map.put(config, :page_token, checkpoint)
      fetch_changes(client, params, checkpoint, access_token)
    end
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

  defp fetch_pages(client, params, access_token, signal_pages, latest_checkpoint, seen) do
    with {:ok, result} <- client.list_changes(Map.delete(params, :collection_id), access_token),
         {:ok, page} <- normalize_page(result) do
      page_signals = normalize_signals(page.changes, Map.fetch!(params, :collection_id))
      signal_pages = [page_signals | signal_pages]
      latest_checkpoint = page.new_start_page_token || latest_checkpoint

      case page.next_page_token do
        nil ->
          finish_pages(signal_pages, latest_checkpoint)

        page_token ->
          if MapSet.member?(seen, page_token) do
            invalid_repeated_page_token(page_token)
          else
            fetch_pages(
              client,
              Map.put(params, :page_token, page_token),
              access_token,
              signal_pages,
              latest_checkpoint,
              MapSet.put(seen, page_token)
            )
          end
      end
    end
  end

  defp finish_pages(signal_pages, checkpoint)
       when is_binary(checkpoint) and checkpoint != "" do
    signals = signal_pages |> Enum.reverse() |> Enum.concat() |> dedupe_signals()

    {:ok, %{signals: signals, checkpoint: checkpoint, has_more?: false}}
  end

  defp finish_pages(_signal_pages, _checkpoint) do
    invalid_page(:new_start_page_token)
  end

  defp normalize_signals(changes, collection_id) do
    changes
    |> Enum.filter(&file_change?/1)
    |> Enum.map(fn change ->
      normalize_signal(change, collection_id, collection_match(change, collection_id))
    end)
  end

  defp collection_match(change, collection_id) do
    file = Map.get(change, :file)
    file_id = Map.get(change, :file_id) || record_id(file)

    cond do
      Map.get(change, :removed?, false) and is_nil(file) ->
        "unknown"

      file_id == collection_id ->
        "yes"

      is_map(file) and collection_id in Map.get(file, :parents, []) ->
        "yes"

      is_nil(file) ->
        "unknown"

      true ->
        "no"
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

  defp change_type(%{removed?: true}), do: "deleted"
  defp change_type(%{change_type: "file"}), do: "updated"
  defp change_type(_change), do: "unknown"

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

  defp dedupe_signals(signals) do
    Enum.uniq_by(signals, fn signal ->
      {
        Map.get(signal, :collection_id),
        Map.get(signal, :change_type),
        Map.get(signal, :provider_record_id),
        Map.get(signal, :changed_at)
      }
    end)
  end

  defp file_change?(%{change_type: "file"}), do: true
  defp file_change?(%{file_id: file_id}) when is_binary(file_id) and file_id != "", do: true
  defp file_change?(_change), do: false

  defp normalize_checkpoint(checkpoint) when is_binary(checkpoint) do
    case String.trim(checkpoint) do
      "" -> invalid_checkpoint()
      normalized -> {:ok, normalized}
    end
  end

  defp normalize_checkpoint(_checkpoint), do: invalid_checkpoint()

  defp start_page_token(%{start_page_token: token})
       when is_binary(token) and token != "",
       do: {:ok, token}

  defp start_page_token(_result), do: invalid_page(:start_page_token)

  defp normalize_page(result) when is_map(result) do
    changes = Map.get(result, :changes, [])

    with true <- is_list(changes),
         {:ok, next_page_token} <- optional_page_token(result, :next_page_token),
         {:ok, new_start_page_token} <- optional_page_token(result, :new_start_page_token) do
      {:ok,
       %{
         changes: changes,
         next_page_token: next_page_token,
         new_start_page_token: new_start_page_token
       }}
    else
      false -> invalid_page(:changes)
      {:error, _error} = error -> error
    end
  end

  defp normalize_page(_result), do: invalid_page(:response)

  defp optional_page_token(result, field) do
    case Map.get(result, field) do
      nil -> {:ok, nil}
      token when is_binary(token) and token != "" -> {:ok, token}
      _token -> invalid_page(field)
    end
  end

  defp invalid_checkpoint do
    {:error,
     Error.validation(
       "A cursor or checkpoint is required to list Google Drive collection changes",
       field: :checkpoint,
       reason: :required
     )}
  end

  defp invalid_page(field) do
    Checkpoint.invalid_response("Google Drive collection changes response was invalid", %{
      field: field
    })
  end

  defp invalid_repeated_page_token(page_token) do
    Checkpoint.invalid_response("Google Drive collection changes repeated nextPageToken", %{
      next_page_token: page_token
    })
  end
end
