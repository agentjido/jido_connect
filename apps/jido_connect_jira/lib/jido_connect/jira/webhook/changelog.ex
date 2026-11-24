defmodule Jido.Connect.Jira.Webhook.Changelog do
  @moduledoc """
  Normalizes the `changelog` of a Jira issue delivery.

  The changelog keeps its `id` and its `items` in Jira's order. Each item
  keeps `field`, `fieldId` as `field_id` and `fieldtype` as `field_type` when
  Jira sends them. `from`, `fromString`, `to` and `toString` keep their
  presence: a key that Jira sends as `null` stays as `nil`, and a key that
  Jira leaves out stays absent. Values pass through unchanged, so status IDs
  and date-only due dates such as `"2026-12-15"` are not converted.

  A changelog that is neither an object nor `null`, `items` that is neither a
  list nor `null`, and an item that is not an object, `null` included, fail
  with `:invalid_webhook_event`.
  """

  alias Jido.Connect.Data
  alias Jido.Connect.Jira.Webhook.Payload

  @value_keys [
    {"from", :from},
    {"fromString", :from_string},
    {"to", :to},
    {"toString", :to_string}
  ]

  @doc "Returns the normalized changelog of `payload`, or `nil` when it has none."
  @spec normalize(map(), String.t()) :: Payload.result(map() | nil)
  def normalize(payload, event_type) do
    case Payload.object(payload, "changelog", event_type, "changelog") do
      {:ok, %{} = changelog} -> changelog(changelog, event_type)
      other -> other
    end
  end

  defp changelog(changelog, event_type) do
    with {:ok, items} <- items(Data.get(changelog, "items"), event_type) do
      {:ok, Data.compact(%{id: Data.get(changelog, "id"), items: items})}
    end
  end

  defp items(nil, _event_type), do: {:ok, nil}

  defp items(items, event_type) when is_list(items) do
    if Enum.all?(items, &is_map/1),
      do: {:ok, Enum.map(items, &item/1)},
      else: {:error, Payload.invalid(event_type, "changelog.items")}
  end

  defp items(_items, event_type), do: {:error, Payload.invalid(event_type, "changelog.items")}

  defp item(item) do
    identity =
      Data.compact(%{
        field: Data.get(item, "field"),
        field_id: Data.get(item, "fieldId"),
        field_type: Data.get(item, "fieldtype")
      })

    Enum.reduce(@value_keys, identity, fn {key, name}, normalized ->
      case Map.fetch(item, key) do
        {:ok, value} -> Map.put(normalized, name, value)
        :error -> normalized
      end
    end)
  end
end
