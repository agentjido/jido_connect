defmodule Jido.Connect.Nextcloud.Normalizer do
  @moduledoc "Normalizes Nextcloud WebDAV and OCS payloads."

  alias Jido.Connect.Data
  alias Jido.Connect.Nextcloud.{FileNode, Share, Sharee}
  alias Jido.Connect.Nextcloud.Client.XML

  @doc "Normalizes a WebDAV multistatus XML response into file nodes."
  def dav_nodes(xml, opts \\ [])

  def dav_nodes(xml, opts) when is_binary(xml) do
    with {:ok, doc} <- XML.parse_document(xml),
         responses when is_list(responses) <- XML.elements_by_name(doc, "response") do
      nodes =
        responses
        |> Enum.map(&dav_node(&1, opts))
        |> Enum.reject(&is_nil/1)

      {:ok, nodes}
    end
  end

  def dav_nodes(_xml, _opts), do: {:error, :invalid_dav_response}

  @doc "Normalizes one WebDAV response node."
  def dav_node(response, opts \\ []) do
    href = XML.child_text(response, "href", "")
    prop = response |> XML.find_deep("prop") || %{}
    base_path = Keyword.get(opts, :base_path)
    path = normalize_dav_href(href, Keyword.get(opts, :login_name))

    if base_path && path == base_path && Keyword.get(opts, :skip_base?, false) do
      nil
    else
      attrs =
        %{
          path: path,
          name: XML.child_text(prop, "displayname") || basename(path),
          file_id: XML.child_text(prop, "fileid"),
          type: node_type(prop),
          content_type: XML.child_text(prop, "getcontenttype"),
          size:
            parse_integer(
              XML.child_text(prop, "size") || XML.child_text(prop, "getcontentlength")
            ),
          etag: trim_quotes(XML.child_text(prop, "getetag")),
          last_modified: XML.child_text(prop, "getlastmodified"),
          permissions: XML.child_text(prop, "permissions"),
          owner_id: XML.child_text(prop, "owner-id"),
          owner_display_name: XML.child_text(prop, "owner-display-name"),
          favorite?: truthy?(XML.child_text(prop, "favorite")),
          share_types: share_types(prop),
          share_permissions: parse_integer(XML.child_text(prop, "share-permissions")),
          has_preview?: maybe_boolean(XML.child_text(prop, "has-preview")),
          note: XML.child_text(prop, "note")
        }
        |> Data.compact()

      FileNode.new(attrs)
      |> case do
        {:ok, node} -> node
        {:error, _reason} -> nil
      end
    end
  end

  @doc "Normalizes a Nextcloud OCS response body and returns the data payload."
  def ocs_data(%{"ocs" => %{"meta" => meta, "data" => data}}) do
    if successful_ocs?(meta), do: {:ok, data}, else: {:error, {:ocs_error, meta}}
  end

  def ocs_data(%{"ocs" => %{"data" => data}}), do: {:ok, data}

  def ocs_data(xml) when is_binary(xml) do
    with {:ok, doc} <- XML.parse_document(xml),
         meta <- XML.find_deep(doc, "meta"),
         true <- meta == nil || successful_ocs_xml?(meta),
         data <- XML.find_deep(doc, "data") do
      {:ok, ocs_xml_value(data)}
    else
      false -> {:error, :ocs_error}
      {:error, _reason} = error -> error
    end
  end

  def ocs_data(_body), do: {:error, :invalid_ocs_response}

  @doc "Normalizes one or many shares from OCS data."
  def shares(data) do
    data
    |> listish()
    |> normalize_list(&share/1)
  end

  def share(data) when is_map(data) do
    %{
      share_id: string(Data.get(data, "id") || Data.get(data, "share_id")),
      path: Data.get(data, "path"),
      item_type: Data.get(data, "item_type"),
      item_source: string(Data.get(data, "item_source")),
      file_source: string(Data.get(data, "file_source")),
      file_target: Data.get(data, "file_target"),
      share_type: parse_integer(Data.get(data, "share_type")),
      share_with: Data.get(data, "share_with"),
      share_with_display_name: Data.get(data, "share_with_displayname"),
      permissions: parse_integer(Data.get(data, "permissions")),
      url: Data.get(data, "url"),
      token: Data.get(data, "token"),
      expiration: Data.get(data, "expiration"),
      note: Data.get(data, "note"),
      label: Data.get(data, "label"),
      created_at: string(Data.get(data, "stime"))
    }
    |> Data.compact()
    |> Share.new()
  end

  def share(_data), do: {:error, :invalid_share}

  @doc "Normalizes sharees from OCS sharee data."
  def sharees(data) when is_map(data) do
    data
    |> Map.values()
    |> List.flatten()
    |> normalize_list(&sharee/1)
  end

  def sharees(data) when is_list(data), do: normalize_list(data, &sharee/1)
  def sharees(_data), do: {:error, :invalid_sharees}

  def sharee(data) when is_map(data) do
    value = Data.get(data, "value", %{})

    attrs = %{
      id:
        string(
          Data.get(value, "shareWith") || Data.get(data, "shareWith") || Data.get(data, "id")
        ),
      label: Data.get(data, "label"),
      name: Data.get(value, "name") || Data.get(data, "name"),
      type: parse_integer(Data.get(data, "shareType") || Data.get(value, "shareType")),
      value: if(is_map(value), do: value, else: %{})
    }

    attrs
    |> Data.compact()
    |> Sharee.new()
  end

  def sharee(_data), do: {:error, :invalid_sharee}

  @doc "Derives Office availability from a capabilities map."
  def office_capabilities(capabilities) when is_map(capabilities) do
    capability_root =
      Data.get(capabilities, "capabilities") ||
        Data.get(capabilities, :capabilities) ||
        capabilities

    apps = Data.get(capability_root, "richdocuments", %{})

    %{
      available?: apps != %{} and apps != nil,
      richdocuments: apps,
      supports_external_apps?: truthy?(Data.get(apps, "external_apps"))
    }
  end

  def office_capabilities(_capabilities), do: %{available?: false}

  @doc "Normalizes richdocuments launch metadata."
  def office_launch(data) when is_map(data) do
    data
    |> Data.compact()
    |> then(&{:ok, &1})
  end

  def office_launch(_data), do: {:error, :invalid_office_launch}

  def public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  def public_map(list) when is_list(list), do: Enum.map(list, &public_map/1)

  def public_map(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key, public_map(value)} end)

  def public_map(value), do: value

  defp normalize_list(items, normalizer) when is_list(items) do
    Enum.reduce_while(items, {:ok, []}, fn item, {:ok, acc} ->
      case normalizer.(item) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      {:error, _reason} = error -> error
    end
  end

  defp normalize_list(_items, _normalizer), do: {:error, :invalid_list}

  defp listish(%{"element" => items}) when is_list(items), do: items
  defp listish(%{"element" => item}) when is_map(item), do: [item]
  defp listish(items) when is_list(items), do: items
  defp listish(item) when is_map(item), do: [item]
  defp listish(_other), do: []

  defp successful_ocs?(%{"statuscode" => code}) when code in [100, 200, "100", "200"],
    do: true

  defp successful_ocs?(%{"status" => "ok"}), do: true

  defp successful_ocs?(%{statuscode: code}) when code in [100, 200, "100", "200"],
    do: true

  defp successful_ocs?(%{status: "ok"}), do: true
  defp successful_ocs?(_meta), do: false

  defp successful_ocs_xml?(meta) do
    XML.child_text(meta, "status") == "ok" ||
      XML.child_text(meta, "statuscode") in ["100", "200"]
  end

  defp ocs_xml_value(nil), do: nil

  defp ocs_xml_value(element) do
    child_elements =
      Enum.filter(element.children, fn
        %{local_name: _} -> true
        _other -> false
      end)

    cond do
      child_elements == [] ->
        XML.text(element)

      repeated_element_children?(child_elements) ->
        Enum.map(child_elements, &ocs_xml_value/1)

      true ->
        Map.new(child_elements, fn child -> {child.local_name, ocs_xml_value(child)} end)
    end
  end

  defp repeated_element_children?(children) do
    names = Enum.map(children, & &1.local_name)
    Enum.uniq(names) == ["element"]
  end

  defp normalize_dav_href(href, login_name) do
    href = URI.decode(href || "")

    cond do
      is_binary(login_name) and String.contains?(href, "/remote.php/dav/files/#{login_name}") ->
        href
        |> String.split("/remote.php/dav/files/#{login_name}", parts: 2)
        |> List.last()
        |> normalize_path()

      is_binary(login_name) and String.contains?(href, "/files/#{login_name}") ->
        href
        |> String.split("/files/#{login_name}", parts: 2)
        |> List.last()
        |> normalize_path()

      true ->
        normalize_path(href)
    end
  end

  defp normalize_path(nil), do: "/"
  defp normalize_path(""), do: "/"

  defp normalize_path(path) when is_binary(path),
    do: if(String.starts_with?(path, "/"), do: path, else: "/" <> path)

  defp basename("/"), do: "/"

  defp basename(path) do
    path
    |> String.trim_trailing("/")
    |> Path.basename()
  end

  defp node_type(prop) do
    case XML.find_deep(prop, "collection") do
      nil -> :file
      _collection -> :folder
    end
  end

  defp share_types(prop) do
    prop
    |> XML.children("share-types")
    |> Enum.flat_map(&XML.children(&1, "share-type"))
    |> Enum.map(&(XML.text(&1) |> parse_integer()))
    |> Enum.reject(&is_nil/1)
  end

  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, _rest} -> integer
      :error -> nil
    end
  end

  defp parse_integer(_value), do: nil

  defp truthy?(value) when value in [true, 1, "1", "true", "yes"], do: true
  defp truthy?(_value), do: false

  defp maybe_boolean(nil), do: nil
  defp maybe_boolean(value), do: truthy?(value)

  defp trim_quotes(nil), do: nil
  defp trim_quotes(value) when is_binary(value), do: String.trim(value, "\"")

  defp string(nil), do: nil
  defp string(value) when is_binary(value), do: value
  defp string(value), do: to_string(value)
end
