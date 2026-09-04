defmodule Jido.Connect.MicrosoftSharepoint.Normalizer do
  @moduledoc "Normalizes SharePoint Microsoft Graph payloads into stable structs."

  alias Jido.Connect.Data
  alias Jido.Connect.MicrosoftSharepoint.{Column, ListItem, Site, SiteList}

  @column_facets [
    "boolean",
    "calculated",
    "choice",
    "currency",
    "dateTime",
    "geolocation",
    "hyperlinkOrPicture",
    "lookup",
    "number",
    "personOrGroup",
    "text",
    "term",
    "thumbnail"
  ]

  @spec site(map()) :: {:ok, Site.t()} | {:error, term()}
  def site(payload) when is_map(payload) do
    %{
      site_id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      display_name: Data.get(payload, "displayName"),
      description: Data.get(payload, "description"),
      web_url: Data.get(payload, "webUrl"),
      created_date_time: Data.get(payload, "createdDateTime"),
      last_modified_date_time: Data.get(payload, "lastModifiedDateTime"),
      is_personal_site: Data.get(payload, "isPersonalSite"),
      site_collection: Data.get(payload, "siteCollection"),
      sharepoint_ids: Data.get(payload, "sharepointIds")
    }
    |> Data.compact()
    |> Site.new()
  end

  def site(_payload), do: {:error, :invalid_site_payload}

  @spec site_list(map()) :: {:ok, SiteList.t()} | {:error, term()}
  def site_list(payload) when is_map(payload) do
    %{
      list_id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      display_name: Data.get(payload, "displayName"),
      description: Data.get(payload, "description"),
      web_url: Data.get(payload, "webUrl"),
      created_date_time: Data.get(payload, "createdDateTime"),
      last_modified_date_time: Data.get(payload, "lastModifiedDateTime"),
      list: Data.get(payload, "list"),
      system: Data.get(payload, "system"),
      sharepoint_ids: Data.get(payload, "sharepointIds")
    }
    |> Data.compact()
    |> SiteList.new()
  end

  def site_list(_payload), do: {:error, :invalid_list_payload}

  @spec column(map()) :: {:ok, Column.t()} | {:error, term()}
  def column(payload) when is_map(payload) do
    {column_type, settings} = column_facet(payload)

    %{
      column_id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      display_name: Data.get(payload, "displayName"),
      description: Data.get(payload, "description"),
      column_type: column_type,
      settings: settings,
      required: Data.get(payload, "required"),
      read_only: Data.get(payload, "readOnly"),
      hidden: Data.get(payload, "hidden"),
      indexed: Data.get(payload, "indexed"),
      enforce_unique_values: Data.get(payload, "enforceUniqueValues")
    }
    |> Data.compact()
    |> Column.new()
  end

  def column(_payload), do: {:error, :invalid_column_payload}

  @spec list_item(map()) :: {:ok, ListItem.t()} | {:error, term()}
  def list_item(payload) when is_map(payload) do
    %{
      item_id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      web_url: Data.get(payload, "webUrl"),
      etag: Data.get(payload, "eTag"),
      created_date_time: Data.get(payload, "createdDateTime"),
      last_modified_date_time: Data.get(payload, "lastModifiedDateTime"),
      created_by: normalize_identity_set(Data.get(payload, "createdBy")),
      last_modified_by: normalize_identity_set(Data.get(payload, "lastModifiedBy")),
      content_type: Data.get(payload, "contentType"),
      fields: Data.get(payload, "fields", %{}),
      sharepoint_ids: Data.get(payload, "sharepointIds"),
      deleted: deleted?(payload)
    }
    |> Data.compact()
    |> ListItem.new()
  end

  def list_item(_payload), do: {:error, :invalid_list_item_payload}

  @spec page(map(), (map() -> {:ok, struct()} | {:error, term()})) ::
          {:ok, %{items: [struct()], next_link: String.t() | nil}} | {:error, term()}
  def page(envelope, normalizer) when is_map(envelope) and is_function(normalizer, 1) do
    envelope
    |> Data.get("value", [])
    |> normalize_list(normalizer)
    |> case do
      {:ok, items} -> {:ok, %{items: items, next_link: Data.get(envelope, "@odata.nextLink")}}
      {:error, _reason} = error -> error
    end
  end

  def page(_envelope, _normalizer), do: {:error, :invalid_page_envelope}

  @spec normalize_list([map()], (map() -> {:ok, struct()} | {:error, term()})) ::
          {:ok, [struct()]} | {:error, term()}
  def normalize_list(payloads, normalizer)
      when is_list(payloads) and is_function(normalizer, 1) do
    Enum.reduce_while(payloads, {:ok, []}, fn payload, {:ok, items} ->
      case normalizer.(payload) do
        {:ok, item} -> {:cont, {:ok, [item | items]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      {:error, reason} -> {:error, reason}
    end
  end

  def normalize_list(_payloads, _normalizer), do: {:error, :invalid_list_payloads}

  defp column_facet(payload) do
    Enum.find_value(@column_facets, {nil, %{}}, fn facet ->
      case Data.get(payload, facet) do
        settings when is_map(settings) -> {facet, settings}
        _missing -> nil
      end
    end)
  end

  defp normalize_identity_set(identity_set) when is_map(identity_set) do
    ["user", "application", "group", "siteUser"]
    |> Enum.reduce(%{}, fn kind, acc ->
      case Data.get(identity_set, kind) do
        identity when is_map(identity) ->
          Map.put(acc, identity_key(kind), normalize_identity(identity))

        _missing ->
          acc
      end
    end)
  end

  defp normalize_identity_set(_identity_set), do: nil

  defp normalize_identity(identity) do
    %{
      id: Data.get(identity, "id"),
      display_name: Data.get(identity, "displayName"),
      email: Data.get(identity, "email")
    }
    |> Data.compact()
  end

  defp identity_key("siteUser"), do: :site_user
  defp identity_key(kind), do: String.to_existing_atom(kind)

  defp deleted?(payload) do
    is_map(Data.get(payload, "deleted")) or is_map(Data.get(payload, "@removed"))
  end
end
