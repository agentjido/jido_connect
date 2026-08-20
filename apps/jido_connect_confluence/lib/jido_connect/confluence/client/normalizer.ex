defmodule Jido.Connect.Confluence.Client.Normalizer do
  @moduledoc "Strict normalization for Confluence Cloud space, page, and effect responses."

  alias Jido.Connect.Data
  alias Jido.Connect.Confluence.{ADF, Contract}

  @identifier_max Contract.maximum_identifier_length()
  @title_max Contract.maximum_title_length()
  @cursor_max Contract.maximum_cursor_length()

  @spec space(map(), String.t(), map()) :: {:ok, map()} | {:error, :not_found} | :error
  def space(body, expected_key, context) when is_map(body) and is_map(context) do
    with {:ok, raw} <- matching_space(body, expected_key),
         {:ok, space} <- normalize_space(raw, expected_key, context) do
      {:ok, space}
    end
  end

  def space(_body, _expected_key, _context), do: :error

  @spec space_ref(map(), String.t()) :: {:ok, map()} | {:error, :not_found} | :error
  def space_ref(body, expected_key) when is_map(body) do
    with {:ok, raw} <- matching_space(body, expected_key),
         {:ok, id} <- required_string(raw, :id, @identifier_max),
         {:ok, ^expected_key} <- required_string(raw, :key, @identifier_max) do
      {:ok, %{id: id, key: expected_key}}
    else
      {:error, :not_found} = error -> error
      _invalid -> :error
    end
  end

  def space_ref(_body, _expected_key), do: :error

  @spec page_list(map(), map(), map()) :: {:ok, map()} | :error
  def page_list(body, space, context)
      when is_map(body) and is_map(space) and is_map(context) do
    results = Data.get(body, :results)
    links = Data.get(body, :_links)

    with true <- is_list(results),
         true <- is_map(links),
         true <- valid_account?(context.account),
         true <- is_integer(context.limit) and context.limit in 1..Contract.maximum_limit(),
         true <- length(results) <= context.limit,
         {:ok, items} <- normalize_page_items(results, space.id, context.site_url),
         {:ok, next_cursor} <- next_cursor(Data.get(links, :next)) do
      {:ok,
       %{
         kind: "confluence_pages",
         account: context.account,
         space: %{id: space.id, key: space.key},
         count: length(items),
         limit: context.limit,
         next_cursor: next_cursor,
         items: items
       }}
    else
      _invalid -> :error
    end
  end

  def page_list(_body, _space, _context), do: :error

  @spec page(map(), String.t(), pos_integer(), map()) :: {:ok, map()} | :error
  def page(body, expected_id, max_characters, context)
      when is_map(body) and is_map(context) do
    with {:ok, metadata} <- page_metadata(body, expected_id),
         {:ok, adf} <- adf_body(body),
         {:ok, text} <- ADF.to_text(adf),
         true <- valid_account?(context.account),
         true <-
           is_integer(max_characters) and
             max_characters in 1..Contract.maximum_max_characters() do
      character_count = String.length(text)

      {:ok,
       %{
         kind: "confluence_page",
         account: context.account,
         id: metadata.id,
         title: metadata.title,
         revision_id: Integer.to_string(metadata.version),
         version: metadata.version,
         space_id: metadata.space_id,
         text: String.slice(text, 0, max_characters),
         character_count: character_count,
         truncated: character_count > max_characters
       }}
    else
      _invalid -> :error
    end
  end

  def page(_body, _expected_id, _max_characters, _context), do: :error

  @spec page_metadata(map(), String.t() | nil) :: {:ok, map()} | :error
  def page_metadata(body, expected_id \\ nil)

  def page_metadata(body, expected_id) when is_map(body) do
    with {:ok, id} <- required_string(body, :id, @identifier_max),
         true <- is_nil(expected_id) or id == expected_id,
         {:ok, title} <- required_string(body, :title, @title_max),
         {:ok, space_id} <- required_string(body, :spaceId, @identifier_max),
         {:ok, version} <- version(body) do
      {:ok, %{id: id, title: title, space_id: space_id, version: version}}
    else
      _invalid -> :error
    end
  end

  def page_metadata(_body, _expected_id), do: :error

  @spec page_effect(map(), String.t(), String.t() | nil, pos_integer() | nil, String.t()) ::
          {:ok, map()} | :error
  def page_effect(body, effect, expected_id, expected_version, expected_space_id)
      when effect in ["create", "update"] do
    with {:ok, page} <- page_metadata(body, expected_id),
         true <- is_nil(expected_version) or page.version == expected_version,
         true <- page.space_id == expected_space_id do
      {:ok,
       %{
         kind: "confluence_page_effect",
         effect: effect,
         submitted: true,
         page: %{
           id: page.id,
           title: page.title,
           space_id: page.space_id,
           version: page.version
         }
       }}
    else
      _invalid -> :error
    end
  end

  def page_effect(_body, _effect, _expected_id, _expected_version, _expected_space_id),
    do: :error

  @spec delete_effect(String.t()) :: {:ok, map()} | :error
  def delete_effect(id) when is_binary(id) and id != "" do
    {:ok,
     %{
       kind: "confluence_page_effect",
       effect: "delete",
       submitted: true,
       page: %{id: id}
     }}
  end

  def delete_effect(_id), do: :error

  defp matching_space(body, expected_key) do
    case Data.get(body, :results) do
      results when is_list(results) ->
        matches = Enum.filter(results, &(is_map(&1) and Data.get(&1, :key) == expected_key))

        case matches do
          [space] -> {:ok, space}
          [] -> {:error, :not_found}
          _matches -> :error
        end

      _results ->
        :error
    end
  end

  defp normalize_space(raw, expected_key, context) do
    links = Data.get(raw, :_links)

    with true <- valid_account?(context.account),
         {:ok, id} <- required_string(raw, :id, @identifier_max),
         {:ok, ^expected_key} <- required_string(raw, :key, @identifier_max),
         {:ok, name} <- required_string(raw, :name, 255),
         {:ok, type} <- required_string(raw, :type, 64),
         {:ok, status} <- required_string(raw, :status, 64),
         {:ok, homepage_id} <- optional_string(Data.get(raw, :homepageId), @identifier_max),
         true <- is_map(links),
         {:ok, url} <- web_url(context.site_url, Data.get(links, :webui)) do
      {:ok,
       %{
         kind: "confluence_space",
         account: context.account,
         id: id,
         key: expected_key,
         name: name,
         type: type,
         status: status,
         homepage_id: homepage_id,
         url: url
       }}
    else
      _invalid -> :error
    end
  end

  defp normalize_page_items(results, expected_space_id, site_url) do
    Enum.reduce_while(results, {:ok, []}, fn raw, {:ok, items} ->
      case normalize_page_item(raw, expected_space_id, site_url) do
        {:ok, item} -> {:cont, {:ok, [item | items]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      :error -> :error
    end
  end

  defp normalize_page_item(raw, expected_space_id, site_url) when is_map(raw) do
    links = Data.get(raw, :_links)

    with {:ok, id} <- required_string(raw, :id, @identifier_max),
         {:ok, title} <- required_string(raw, :title, @title_max),
         {:ok, status} <- required_string(raw, :status, 64),
         {:ok, ^expected_space_id} <- required_string(raw, :spaceId, @identifier_max),
         {:ok, parent_id} <- optional_string(Data.get(raw, :parentId), @identifier_max),
         {:ok, created_at} <- optional_iso8601(Data.get(raw, :createdAt)),
         {:ok, page_version} <- version(raw),
         true <- is_map(links),
         {:ok, url} <- web_url(site_url, Data.get(links, :webui)) do
      {:ok,
       %{
         id: id,
         title: title,
         status: status,
         space_id: expected_space_id,
         parent_id: parent_id,
         version: page_version,
         created_at: created_at,
         url: url
       }}
    else
      _invalid -> :error
    end
  end

  defp normalize_page_item(_raw, _expected_space_id, _site_url), do: :error

  defp adf_body(raw) do
    with body when is_map(body) <- Data.get(raw, :body),
         adf_container when is_map(adf_container) <- Data.get(body, :atlas_doc_format) do
      decode_adf(Data.get(adf_container, :value))
    else
      _invalid -> :error
    end
  end

  defp decode_adf(value) when is_map(value), do: {:ok, value}

  defp decode_adf(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, adf} when is_map(adf) -> {:ok, adf}
      _invalid -> :error
    end
  end

  defp decode_adf(_value), do: :error

  defp version(raw) do
    case Data.get(raw, :version) do
      version when is_map(version) ->
        case Data.get(version, :number) do
          number when is_integer(number) and number >= 1 -> {:ok, number}
          _number -> :error
        end

      _version ->
        :error
    end
  end

  defp next_cursor(nil), do: {:ok, nil}

  defp next_cursor(next) when is_binary(next) and next != "" do
    uri = URI.parse(next)

    with query when is_binary(query) <- uri.query,
         %{"cursor" => cursor} <- URI.decode_query(query),
         true <- cursor != "" and String.length(cursor) <= @cursor_max do
      {:ok, cursor}
    else
      _invalid -> :error
    end
  rescue
    ArgumentError -> :error
  end

  defp next_cursor(_next), do: :error

  defp web_url(site_url, webui) when is_binary(site_url) and is_binary(webui) do
    uri = URI.parse(webui)

    if String.starts_with?(webui, "/") and String.length(webui) <= 4_096 and is_nil(uri.scheme) and
         is_nil(uri.host) and is_nil(uri.userinfo) and is_nil(uri.query) and is_nil(uri.fragment) do
      {:ok, String.trim_trailing(site_url, "/") <> "/" <> String.trim_leading(webui, "/")}
    else
      :error
    end
  end

  defp web_url(_site_url, _webui), do: :error

  defp required_string(map, key, maximum) do
    case Data.get(map, key) do
      value when is_binary(value) ->
        if value != "" and String.length(value) <= maximum, do: {:ok, value}, else: :error

      _value ->
        :error
    end
  end

  defp optional_string(nil, _maximum), do: {:ok, nil}

  defp optional_string(value, maximum) when is_binary(value) do
    if value != "" and String.length(value) <= maximum, do: {:ok, value}, else: :error
  end

  defp optional_string(_value, _maximum), do: :error

  defp optional_iso8601(nil), do: {:ok, nil}

  defp optional_iso8601(value) when is_binary(value) and byte_size(value) <= 64 do
    if match?({:ok, _datetime, _offset}, DateTime.from_iso8601(value)),
      do: {:ok, value},
      else: :error
  end

  defp optional_iso8601(_value), do: :error

  defp valid_account?(value), do: is_binary(value) and value != "" and String.length(value) <= 255
end
