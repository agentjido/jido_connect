defmodule Jido.Connect.X.Normalizer do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.X.{Contract, Identity}

  @identifier ~r/^[A-Za-z0-9_-]+$/

  def account(result) do
    try do
      account = result |> payload!() |> account_payload!()
      {:ok, account_data(account)}
    catch
      {:x_normalization_error, reason} -> invalid_response(reason)
    end
  end

  def list(action, input, account, result) do
    try do
      payload = payload!(result)
      {:ok, list_payload!(action, input, account, payload)}
    catch
      {:x_normalization_error, reason} -> invalid_response(reason)
    end
  end

  defp payload!(result) when is_map(result) do
    cond do
      has_key?(result, :structuredContent) ->
        case Data.get(result, :structuredContent) do
          content when is_map(content) and map_size(content) > 0 -> content
          _other -> invalid!(:structured_content)
        end

      has_key?(result, :content) ->
        text_payload!(Data.get(result, :content))

      true ->
        invalid!(:unsupported_envelope)
    end
  end

  defp payload!(_result), do: invalid!(:unsupported_envelope)

  defp text_payload!([block]) when is_map(block) do
    case {Data.get(block, :type), Data.get(block, :text)} do
      {"text", text} when is_binary(text) and text != "" -> decode_text!(text)
      _other -> invalid!(:text_envelope)
    end
  end

  defp text_payload!(_content), do: invalid!(:text_envelope)

  defp decode_text!(text) do
    case Jason.decode(text) do
      {:ok, value} when is_map(value) -> value
      {:ok, _value} -> invalid!(:json_object)
      {:error, _error} -> invalid!(:json)
    end
  end

  defp account_payload!(payload) do
    account = Data.get(payload, :data, payload)
    if is_map(account), do: account_fields!(account), else: invalid!(:account)
  end

  defp account_fields!(account) do
    username = required_string!(account, :username, 15, :account_username)

    case Identity.normalize_username(username) do
      {:ok, _normalized} -> :ok
      {:error, _error} -> invalid!(:account_username)
    end

    %{
      id: identifier!(account, :id, 256, :account_id),
      username: username,
      name: required_string!(account, :name, 256, :account_name)
    }
  end

  defp account_data(account), do: Map.put(account, :kind, "social_account")

  defp list_payload!(action, input, account, payload)
       when action in ["x.bookmark.list", "x.post.list"] do
    items = Data.get(payload, :data)
    meta = Data.get(payload, :meta, %{})

    unless is_list(items), do: invalid!(:items)
    unless is_map(meta), do: invalid!(:metadata)

    items = Enum.map(items, &item!/1)

    %{
      kind: list_kind(action),
      account: account_data(Map.take(account, [:id, :username, :name])),
      count: length(items),
      limit: input.max_results,
      next_cursor:
        optional_string!(
          meta,
          :next_token,
          Contract.pagination_token_max(),
          :next_cursor
        ),
      items: items
    }
  end

  defp list_payload!(_action, _input, _account, _payload), do: invalid!(:unknown_action)

  defp list_kind("x.bookmark.list"), do: "social_bookmarks"
  defp list_kind("x.post.list"), do: "social_posts"

  defp item!(item) when is_map(item) do
    id = identifier!(item, :id, 256, :post_id)

    %{
      id: id,
      text: required_string!(item, :text, 100_000, :post_text),
      url: "https://x.com/i/web/status/#{id}",
      author_id: optional_identifier!(item, :author_id, 256, :author_id),
      created_at: optional_datetime!(item, :created_at)
    }
  end

  defp item!(_item), do: invalid!(:post_item)

  defp identifier!(map, key, maximum, reason) do
    value = required_string!(map, key, maximum, reason)
    if Regex.match?(@identifier, value), do: value, else: invalid!(reason)
  end

  defp optional_identifier!(map, key, maximum, reason) do
    case optional_string!(map, key, maximum, reason) do
      nil -> nil
      value -> if Regex.match?(@identifier, value), do: value, else: invalid!(reason)
    end
  end

  defp required_string!(map, key, maximum, reason) do
    case Data.get(map, key) do
      value when is_binary(value) ->
        if value != "" and String.length(value) <= maximum, do: value, else: invalid!(reason)

      _other ->
        invalid!(reason)
    end
  end

  defp optional_string!(map, key, maximum, reason) do
    case Data.get(map, key) do
      nil ->
        nil

      value when is_binary(value) ->
        if value != "" and String.length(value) <= maximum, do: value, else: invalid!(reason)

      _other ->
        invalid!(reason)
    end
  end

  defp optional_datetime!(map, key) do
    case optional_string!(map, key, 64, :created_at) do
      nil ->
        nil

      value ->
        case DateTime.from_iso8601(value) do
          {:ok, _datetime, _offset} -> value
          _error -> invalid!(:created_at)
        end
    end
  end

  defp has_key?(map, key), do: Map.has_key?(map, key) or Map.has_key?(map, to_string(key))

  defp invalid!(reason), do: throw({:x_normalization_error, reason})

  defp invalid_response(reason) do
    {:error,
     Error.provider("X MCP returned an invalid response",
       provider: :x,
       reason: :invalid_response,
       delivery: :response_received,
       mutation?: false,
       provider_idempotency?: false,
       details: %{family: reason}
     )}
  end
end
