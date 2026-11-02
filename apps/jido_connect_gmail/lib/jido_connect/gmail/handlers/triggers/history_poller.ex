defmodule Jido.Connect.Gmail.Handlers.Triggers.HistoryPoller do
  @moduledoc false

  # Shared Gmail history polling for the poll triggers. A trigger handler
  # passes its config, the poll context, the Gmail history types it requests
  # and a function that maps one normalized history record to signals.

  alias Jido.Connect.Error
  alias Jido.Connect.Google.Checkpoint
  alias Jido.Connect.Gmail.Client

  @doc """
  Polls Gmail history for one trigger.

  Without a checkpoint, the poll returns the profile `historyId` as the
  checkpoint and no signals, so history is not replayed. With a checkpoint,
  it requests `users.history.list` from exactly that history ID with
  `config` and `:history_types`, follows `nextPageToken` through the last
  page and returns the newest response `historyId` as the next checkpoint,
  or the checkpoint itself when no page carries one.

  Options:

    * `:history_types` - Gmail `historyTypes` values, sent in this order.
    * `:signals` - function from a normalized history record to a list of
      signals, applied in Gmail's record order.
    * `:dedupe` - signal keys; the poll keeps the first signal per key and
      drops signals without a `:message_id`.

  An expired history ID returns `Jido.Connect.Google.Checkpoint.expired/4`,
  and a repeated `nextPageToken` returns
  `Jido.Connect.Google.Checkpoint.invalid_response/2`. Both carry reset
  guidance. A missing profile `historyId` is an invalid response as well.
  """
  @spec poll(map(), map(), keyword()) ::
          {:ok, %{signals: [map()], checkpoint: String.t()}} | {:error, Error.error()}
  def poll(config, %{credentials: credentials, checkpoint: checkpoint}, opts) do
    client = client(credentials)
    access_token = Map.get(credentials, :access_token)

    if checkpoint in [nil, ""] do
      initialize(client, access_token)
    else
      params =
        config
        |> Map.put(:start_history_id, checkpoint)
        |> Map.put(:history_types, Keyword.fetch!(opts, :history_types))

      params
      |> drain(client, access_token, opts)
      |> map_expired(checkpoint)
    end
  end

  defp initialize(client, access_token) do
    with {:ok, profile} <- client.get_profile(%{}, access_token) do
      case Map.get(profile, :history_id) do
        history_id when is_binary(history_id) and history_id != "" ->
          {:ok, %{signals: [], checkpoint: history_id}}

        _missing ->
          Checkpoint.invalid_response("Gmail profile response was missing historyId", %{
            field: :history_id
          })
      end
    end
  end

  defp drain(params, client, access_token, opts) do
    drain(params, client, access_token, opts, {[], nil, MapSet.new()})
  end

  defp drain(params, client, access_token, opts, {signals, latest_history_id, seen}) do
    with {:ok, result} <- client.list_history(params, access_token) do
      latest_history_id = Map.get(result, :history_id) || latest_history_id
      signals = signals ++ record_signals(Map.get(result, :history, []), opts)

      case Map.get(result, :next_page_token) do
        nil ->
          {:ok,
           %{
             signals: dedupe(signals, Keyword.fetch!(opts, :dedupe)),
             checkpoint: latest_history_id || Map.fetch!(params, :start_history_id)
           }}

        page_token ->
          if MapSet.member?(seen, page_token) do
            Checkpoint.invalid_response("Gmail history response repeated nextPageToken", %{
              next_page_token: page_token
            })
          else
            params
            |> Map.put(:page_token, page_token)
            |> drain(client, access_token, opts, {
              signals,
              latest_history_id,
              MapSet.put(seen, page_token)
            })
          end
      end
    end
  end

  defp record_signals(history, opts) when is_list(history),
    do: Enum.flat_map(history, Keyword.fetch!(opts, :signals))

  defp record_signals(_history, _opts), do: []

  defp map_expired({:error, %Error.ProviderError{} = error}, checkpoint) do
    if Checkpoint.expired_provider_error?(error) do
      Checkpoint.expired("Gmail history ID", checkpoint, error)
    else
      {:error, error}
    end
  end

  defp map_expired(result, _checkpoint), do: result

  defp dedupe(signals, keys) do
    signals
    |> Enum.reject(&is_nil(Map.get(&1, :message_id)))
    |> Enum.uniq_by(fn signal -> Enum.map(keys, &Map.get(signal, &1)) end)
  end

  defp client(%{gmail_client: client}) when is_atom(client), do: client
  defp client(_credentials), do: Client
end
