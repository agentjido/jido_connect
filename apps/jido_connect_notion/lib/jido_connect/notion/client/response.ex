defmodule Jido.Connect.Notion.Client.Response do
  @moduledoc "Notion REST API success and error response handling."

  alias Jido.Connect.Data
  alias Jido.Connect.Notion.Client.Transport
  alias Jido.Connect.Notion.Normalizer

  # ---------------------------------------------------------------------------
  # Search
  # ---------------------------------------------------------------------------

  def handle_search_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    results = Data.get(body, "results", [])

    with {:ok, normalized} <- normalize_search_results(results) do
      {:ok,
       %{
         results: normalized,
         has_more: Data.get(body, "has_more", false),
         next_cursor: Data.get(body, "next_cursor")
       }}
    end
  end

  def handle_search_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    Transport.invalid_success_response("Notion search response was invalid", body)
  end

  def handle_search_response(response), do: Transport.handle_error_response(response)

  # ---------------------------------------------------------------------------
  # Page
  # ---------------------------------------------------------------------------

  def handle_page_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    Normalizer.page(body)
  end

  def handle_page_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    Transport.invalid_success_response("Notion page response was invalid", body)
  end

  def handle_page_response(response), do: Transport.handle_error_response(response)

  # ---------------------------------------------------------------------------
  # Database
  # ---------------------------------------------------------------------------

  def handle_database_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    Normalizer.database(body)
  end

  def handle_database_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    Transport.invalid_success_response("Notion database response was invalid", body)
  end

  def handle_database_response(response), do: Transport.handle_error_response(response)

  def handle_query_database_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    results = Data.get(body, "results", [])

    with {:ok, normalized} <- normalize_pages(results) do
      {:ok,
       %{
         results: normalized,
         has_more: Data.get(body, "has_more", false),
         next_cursor: Data.get(body, "next_cursor")
       }}
    end
  end

  def handle_query_database_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Notion query database response was invalid", body)
  end

  def handle_query_database_response(response), do: Transport.handle_error_response(response)

  # ---------------------------------------------------------------------------
  # Blocks
  # ---------------------------------------------------------------------------

  def handle_block_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    Normalizer.block(body)
  end

  def handle_block_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    Transport.invalid_success_response("Notion block response was invalid", body)
  end

  def handle_block_response(response), do: Transport.handle_error_response(response)

  def handle_block_children_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    results = Data.get(body, "results", [])

    with {:ok, normalized} <- normalize_blocks(results) do
      {:ok,
       %{
         results: normalized,
         has_more: Data.get(body, "has_more", false),
         next_cursor: Data.get(body, "next_cursor")
       }}
    end
  end

  def handle_block_children_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Notion block children response was invalid", body)
  end

  def handle_block_children_response(response), do: Transport.handle_error_response(response)

  # ---------------------------------------------------------------------------
  # Comments
  # ---------------------------------------------------------------------------

  def handle_comment_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    results = Data.get(body, "results", [])

    with {:ok, normalized} <- normalize_comments(results) do
      {:ok,
       %{
         results: normalized,
         has_more: Data.get(body, "has_more", false),
         next_cursor: Data.get(body, "next_cursor")
       }}
    end
  end

  def handle_comment_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Notion comment list response was invalid", body)
  end

  def handle_comment_list_response(response), do: Transport.handle_error_response(response)

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp normalize_search_results(results) when is_list(results) do
    results
    |> Enum.reduce_while({:ok, []}, fn result, {:ok, acc} ->
      case Data.get(result, "object") do
        "page" ->
          case Normalizer.page(result) do
            {:ok, page} -> {:cont, {:ok, [{:page, page} | acc]}}
            {:error, reason} -> {:halt, {:error, reason}}
          end

        "database" ->
          case Normalizer.database(result) do
            {:ok, db} -> {:cont, {:ok, [{:database, db} | acc]}}
            {:error, reason} -> {:halt, {:error, reason}}
          end

        _other ->
          {:cont, {:ok, acc}}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_pages(results) when is_list(results) do
    results
    |> Enum.reduce_while({:ok, []}, fn result, {:ok, acc} ->
      case Normalizer.page(result) do
        {:ok, page} -> {:cont, {:ok, [page | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_blocks(results) when is_list(results) do
    results
    |> Enum.reduce_while({:ok, []}, fn result, {:ok, acc} ->
      case Normalizer.block(result) do
        {:ok, block} -> {:cont, {:ok, [block | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_comments(results) when is_list(results) do
    results
    |> Enum.reduce_while({:ok, []}, fn result, {:ok, acc} ->
      case Normalizer.comment(result) do
        {:ok, comment} -> {:cont, {:ok, [comment | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      {:error, reason} -> {:error, reason}
    end
  end
end
