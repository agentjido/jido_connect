defmodule Jido.Connect.MicrosoftOnedrive.Normalizer do
  @moduledoc """
  Normalizes Microsoft Graph OneDrive API payloads into stable, body-safe
  package structs.

  This module is read/shape only. It accepts decoded JSON maps (typically from
  fixtures or Transport responses) and produces validated Zoi structs for
  drive items and drive metadata.

  No HTTP actions are performed here — all input is fixture-driven.
  """

  alias Jido.Connect.Data

  # ── Drive Item ────────────────────────────────────────────────────────

  @doc "Normalizes a Microsoft Graph `driveItem` payload."
  @spec drive_item(map()) :: {:ok, map()} | {:error, term()}
  def drive_item(payload) when is_map(payload) do
    {:ok,
     %{
       item_id: Data.get(payload, "id"),
       name: Data.get(payload, "name"),
       size: Data.get(payload, "size"),
       web_url: Data.get(payload, "webUrl"),
       created_date_time: Data.get(payload, "createdDateTime"),
       last_modified_date_time: Data.get(payload, "lastModifiedDateTime"),
       folder: Data.get(payload, "folder"),
       file: Data.get(payload, "file"),
       parent_reference: Data.get(payload, "parentReference")
     }
     |> Data.compact()}
  end

  def drive_item(_payload), do: {:error, :invalid_drive_item_payload}

  # ── Drive ─────────────────────────────────────────────────────────────

  @doc "Normalizes a Microsoft Graph `drive` payload."
  @spec drive(map()) :: {:ok, map()} | {:error, term()}
  def drive(payload) when is_map(payload) do
    {:ok,
     %{
       drive_id: Data.get(payload, "id"),
       drive_type: Data.get(payload, "driveType"),
       name: Data.get(payload, "name"),
       web_url: Data.get(payload, "webUrl"),
       quota: Data.get(payload, "quota")
     }
     |> Data.compact()}
  end

  def drive(_payload), do: {:error, :invalid_drive_payload}

  # ── Paging envelope ───────────────────────────────────────────────────

  @doc """
  Extracts the normalized page of items and next-link from a Microsoft Graph
  OData list envelope.

  Returns `{:ok, %{items: [...], next_link: nil | binary()}}`.
  """
  @spec page(map(), (map() -> {:ok, struct()} | {:error, term()})) ::
          {:ok, %{items: [struct()], next_link: String.t() | nil}}
          | {:error, term()}
  def page(envelope, normalizer) when is_map(envelope) and is_function(normalizer, 1) do
    values = Data.get(envelope, "value", [])
    next = Data.get(envelope, "@odata.nextLink")

    case normalize_list(values, normalizer) do
      {:ok, items} -> {:ok, %{items: items, next_link: next}}
      {:error, reason} -> {:error, reason}
    end
  end

  def page(_envelope, _normalizer), do: {:error, :invalid_page_envelope}

  # ── Batch helpers ─────────────────────────────────────────────────────

  @doc "Normalizes a list of payloads using the given normalizer function."
  @spec normalize_list([map()], (map() -> {:ok, struct()} | {:error, term()})) ::
          {:ok, [struct()]} | {:error, term()}
  def normalize_list(payloads, normalizer)
      when is_list(payloads) and is_function(normalizer, 1) do
    Enum.reduce_while(payloads, {:ok, []}, fn payload, {:ok, acc} ->
      case normalizer.(payload) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      {:error, reason} -> {:error, reason}
    end
  end

  def normalize_list(_payloads, _normalizer), do: {:error, :invalid_list_payloads}
end
