defmodule Jido.Connect.Catalog.ItemLookup do
  @moduledoc false

  alias Jido.Connect.Catalog.Item
  alias Jido.Connect.Error

  @spec lookup([Item.t()], term()) :: {:ok, Item.t()} | {:error, Error.error()}
  def lookup(items, %Item{} = item), do: lookup(items, item.ref)

  def lookup(items, {provider, type, item_id}) when type in [:action, :trigger] do
    provider = provider_key(provider)
    item_id = item_id_key(item_id)

    items
    |> Enum.filter(fn item ->
      provider_key(item.provider) == provider and item.type == type and item.id == item_id
    end)
    |> normalize_matches({provider, type, item_id})
  end

  def lookup(items, {provider, item_id}) do
    provider = provider_key(provider)
    item_id = item_id_key(item_id)

    items
    |> Enum.filter(&(provider_key(&1.provider) == provider and &1.id == item_id))
    |> normalize_matches({provider, item_id})
  end

  def lookup(items, item_ref) when is_binary(item_ref) or is_atom(item_ref) do
    item_ref = item_id_key(item_ref)

    case Enum.filter(items, &(&1.ref == item_ref)) do
      [] ->
        case Enum.filter(items, &(&1.id == item_ref)) do
          [] -> provider_prefixed_matches(items, item_ref)
          matches -> matches
        end

      matches ->
        matches
    end
    |> normalize_matches(item_ref)
  end

  def lookup(_items, item_ref) do
    {:error,
     Error.validation("Invalid catalog item reference",
       reason: :invalid_item_ref,
       subject: item_ref
     )}
  end

  defp provider_prefixed_matches(items, item_ref) do
    case String.split(item_ref, ".", parts: 2) do
      [provider, id] ->
        Enum.filter(items, &(provider_key(&1.provider) == provider and &1.id == id))

      _other ->
        []
    end
  end

  defp normalize_matches([item], _item_ref), do: {:ok, item}

  defp normalize_matches([], item_ref) do
    {:error,
     Error.validation("Unknown catalog item",
       reason: :unknown_item,
       subject: item_ref
     )}
  end

  defp normalize_matches(matches, item_ref) do
    {:error,
     Error.validation("Catalog item reference is ambiguous",
       reason: :ambiguous_item,
       subject: item_ref,
       details: %{
         matches:
           Enum.map(matches, &%{ref: &1.ref, provider: &1.provider, type: &1.type, id: &1.id})
       }
     )}
  end

  def key(%Item{} = item), do: {provider_key(item.provider), item.type, item.id}
  def provider_key(provider), do: provider |> to_string() |> String.trim()
  def item_id_key(item_id), do: item_id |> to_string() |> String.trim()
end
