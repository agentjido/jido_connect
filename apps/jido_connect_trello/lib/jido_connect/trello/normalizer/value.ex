defmodule Jido.Connect.Trello.Normalizer.Value do
  @moduledoc false

  def payload!(%{"structuredContent" => content}) when is_map(content) and map_size(content) > 0,
    do: content

  def payload!(%{structuredContent: content}) when is_map(content) and map_size(content) > 0,
    do: content

  def payload!(result) when is_map(result) do
    case result["content"] || result[:content] do
      content when is_list(content) -> text_payload!(content)
      _other -> invalid!(:unsupported_envelope)
    end
  end

  def payload!(_result), do: invalid!(:unsupported_envelope)

  def required_string!(map, key, reason) do
    case map[key] do
      value when is_binary(value) and value != "" -> value
      _other -> invalid!(reason)
    end
  end

  def optional_string!(map, key, reason) do
    case map[key] do
      nil -> nil
      value when is_binary(value) -> value
      _other -> invalid!(reason)
    end
  end

  def required_boolean!(map, key, reason) do
    case map[key] do
      value when is_boolean(value) -> value
      _other -> invalid!(reason)
    end
  end

  def optional_boolean!(map, key, reason) do
    case map[key] do
      nil -> nil
      value when is_boolean(value) -> value
      _other -> invalid!(reason)
    end
  end

  def optional_number!(map, key, reason) do
    case map[key] do
      nil -> nil
      value when is_number(value) -> value
      _other -> invalid!(reason)
    end
  end

  def embedded!(nil, _normalizer, _reason), do: []

  def embedded!(values, normalizer, _reason) when is_list(values),
    do: Enum.map(values, normalizer)

  def embedded!(_values, _normalizer, reason), do: invalid!(reason)

  def cursor_page!(payload) do
    %{
      hasNextPage: required_boolean!(payload, "hasMore", :page_state),
      endCursor: optional_string!(payload, "nextCursor", :page_cursor)
    }
  end

  def invalid!(reason), do: throw({:trello_normalization_error, reason})

  defp text_payload!(content) do
    texts =
      for %{"type" => "text", "text" => text} <- content,
          is_binary(text) and text != "",
          do: text

    case texts do
      [text] -> decode_text!(text)
      _other -> invalid!(:text_envelope)
    end
  end

  defp decode_text!(text) do
    case Jason.decode(text) do
      {:ok, value} when is_map(value) -> value
      {:ok, _value} -> invalid!(:json_object)
      {:error, _error} -> invalid!(:json)
    end
  end
end
