defmodule Jido.Connect.Google.Contacts.Handlers.Triggers.PersonChangedPoller do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Google.Checkpoint
  alias Jido.Connect.Google.Contacts.Client

  def poll(config, %{credentials: credentials, checkpoint: checkpoint}) do
    with {:ok, client} <- fetch_client(credentials) do
      config = normalize_config(config)
      access_token = Map.get(credentials, :access_token)

      if checkpoint in [nil, ""] do
        initialize_checkpoint(client, config, access_token)
      else
        poll_changes(client, config, checkpoint, access_token)
      end
    end
  end

  defp initialize_checkpoint(client, config, access_token) do
    fetch_people_pages(client, config, access_token, [], nil, MapSet.new(), emit?: false)
  end

  defp poll_changes(client, config, checkpoint, access_token) do
    params = Map.put(config, :sync_token, checkpoint)

    case fetch_people_pages(client, params, access_token, [], nil, MapSet.new([checkpoint]),
           emit?: true
         ) do
      {:error, %Error.ProviderError{} = error} ->
        if Checkpoint.expired_provider_error?(error) do
          Checkpoint.expired("Google Contacts people sync token", checkpoint, error)
        else
          {:error, error}
        end

      result ->
        result
    end
  end

  defp fetch_people_pages(client, params, access_token, signals, latest_sync_token, seen, opts) do
    with {:ok, result} <- client.list_people(params, access_token) do
      signals =
        if Keyword.fetch!(opts, :emit?) do
          signals ++ Enum.map(Map.get(result, :people, []), &normalize_signal/1)
        else
          signals
        end

      latest_sync_token = Map.get(result, :next_sync_token) || latest_sync_token

      case Map.get(result, :next_page_token) do
        nil ->
          checkpoint = latest_sync_token || Map.get(params, :sync_token)

          if checkpoint in [nil, ""] do
            invalid_missing_sync_token()
          else
            {:ok, %{signals: dedupe_signals(signals), checkpoint: checkpoint}}
          end

        page_token ->
          if MapSet.member?(seen, page_token) do
            invalid_repeated_page_token(page_token)
          else
            fetch_people_pages(
              client,
              Map.put(params, :page_token, page_token),
              access_token,
              signals,
              latest_sync_token,
              MapSet.put(seen, page_token),
              opts
            )
          end
      end
    end
  end

  defp normalize_config(config) do
    config
    |> Map.put_new(:resource_name, "people/me")
    |> Map.put_new(:page_size, 100)
    |> Map.put(:request_sync_token, true)
  end

  defp normalize_signal(person) do
    %{
      resource_name: Map.get(person, :resource_name),
      person_id: Map.get(person, :person_id) || person_id(Map.get(person, :resource_name)),
      etag: Map.get(person, :etag),
      deleted: deleted?(person),
      display_name: Map.get(person, :display_name),
      person: public_map(person)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp deleted?(%{metadata: metadata}) when is_map(metadata) do
    Map.get(metadata, "deleted") || Map.get(metadata, :deleted) || false
  end

  defp deleted?(_person), do: false

  defp person_id("people/" <> id), do: id
  defp person_id(_resource_name), do: nil

  defp dedupe_signals(signals) do
    {_seen, unique} =
      Enum.reduce(signals, {MapSet.new(), []}, fn signal, {seen, acc} ->
        key = {Map.get(signal, :resource_name), Map.get(signal, :etag)}

        cond do
          key == {nil, nil} ->
            {seen, acc}

          MapSet.member?(seen, key) ->
            {seen, acc}

          true ->
            {MapSet.put(seen, key), [signal | acc]}
        end
      end)

    Enum.reverse(unique)
  end

  defp invalid_missing_sync_token do
    Checkpoint.invalid_response("Google Contacts people list response omitted nextSyncToken")
  end

  defp invalid_repeated_page_token(page_token) do
    Checkpoint.invalid_response("Google Contacts people list response repeated nextPageToken", %{
      next_page_token: page_token
    })
  end

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()

  defp public_map(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key, public_map(value)} end)

  defp public_map(list) when is_list(list), do: Enum.map(list, &public_map/1)
  defp public_map(value), do: value

  defp fetch_client(%{google_contacts_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
