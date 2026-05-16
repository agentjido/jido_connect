defmodule Jido.Connect.HubSpot.Handlers.Triggers.DealChangedPoller do
  @moduledoc false

  alias Jido.Connect.HubSpot.Checkpoint
  alias Jido.Connect.HubSpot.Client

  @doc """
  Polls for changed HubSpot deals.

  Uses the same `lastmodifieddate` checkpoint pattern as
  `ContactChangedPoller`. The search request filters deals with
  `lastmodifieddate >= checkpoint`. Each deal produces a signal.
  Deduplication by `deal_id + updated_at` prevents double-emission.
  """
  def poll(config, %{credentials: credentials, checkpoint: checkpoint}) do
    with {:ok, client} <- fetch_client(credentials) do
      config = normalize_config(config)
      access_token = credential_token(credentials)

      if checkpoint in [nil, ""] do
        initialize_checkpoint(client, config, access_token)
      else
        poll_changes(client, config, checkpoint, access_token)
      end
    end
  end

  defp initialize_checkpoint(client, config, access_token) do
    fetch_deal_pages(client, config, access_token, [], nil, MapSet.new(), emit?: false)
  end

  defp poll_changes(client, config, checkpoint, access_token) do
    params =
      build_search_params(config, checkpoint)
      |> Map.put(:updated_min, checkpoint)

    fetch_deal_pages(client, params, access_token, [], nil, MapSet.new(), emit?: true)
  end

  defp build_search_params(config, checkpoint) do
    %{
      filter_groups: [
        %{
          filters: [
            %{
              propertyName: "lastmodifieddate",
              operator: "GTE",
              value: checkpoint
            }
          ]
        }
      ],
      properties: Map.get(config, :properties),
      limit: Map.get(config, :limit, 100)
    }
  end

  defp fetch_deal_pages(client, params, access_token, signals, latest_updated, seen, opts) do
    request_fn = if Map.has_key?(params, :filter_groups), do: :search, else: :list

    result =
      case request_fn do
        :search -> client.search_deals(params, access_token)
        :list -> client.list_deals(params, access_token)
      end

    with {:ok, resp} <- result do
      items = Map.get(resp, :items, [])
      emit? = Keyword.fetch!(opts, :emit?)

      signals =
        if emit? do
          signals ++ Enum.map(items, &normalize_signal/1)
        else
          signals
        end

      latest_updated = latest_updated_from_items(items) || latest_updated

      after_cursor = get_in(resp, [:pagination, :after])

      case after_cursor do
        nil ->
          checkpoint = latest_updated || Map.get(params, :updated_min)

          if checkpoint in [nil, ""] do
            Checkpoint.invalid_response(
              "HubSpot deal list response contained no deals with updated timestamps"
            )
          else
            {:ok, %{signals: dedupe_signals(signals), checkpoint: checkpoint}}
          end

        cursor ->
          if MapSet.member?(seen, cursor) do
            Checkpoint.invalid_response("HubSpot deal list response repeated paging cursor", %{
              after: cursor
            })
          else
            fetch_deal_pages(
              client,
              Map.put(params, :after, cursor),
              access_token,
              signals,
              latest_updated,
              MapSet.put(seen, cursor),
              opts
            )
          end
      end
    end
  end

  defp normalize_config(config) do
    config
    |> Map.put_new(:limit, 100)
    |> Map.put_new(:archived, false)
  end

  defp normalize_signal(deal) do
    %{
      deal_id: Map.get(deal, :deal_id),
      deal_name: Map.get(deal, :deal_name),
      amount: Map.get(deal, :amount),
      deal_stage: Map.get(deal, :deal_stage),
      pipeline: Map.get(deal, :pipeline),
      change_type: change_type(deal),
      updated_at: Map.get(deal, :updated_at),
      archived?: Map.get(deal, :archived?, false),
      deal: public_map(deal)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp change_type(%{archived?: true}), do: "archived"
  defp change_type(_deal), do: "updated"

  defp latest_updated_from_items(items) when is_list(items) do
    items
    |> Enum.map(&Map.get(&1, :updated_at))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort(:desc)
    |> List.first()
  end

  defp dedupe_signals(signals) do
    {_seen, unique} =
      Enum.reduce(signals, {MapSet.new(), []}, fn signal, {seen, acc} ->
        key = {Map.get(signal, :deal_id), Map.get(signal, :updated_at)}

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

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value

  defp fetch_client(%{hubspot_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp credential_token(credentials) do
    Map.get(credentials, :api_key) || Map.get(credentials, :access_token)
  end
end
