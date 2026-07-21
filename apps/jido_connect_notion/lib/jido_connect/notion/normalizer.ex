defmodule Jido.Connect.Notion.Normalizer do
  @moduledoc "Normalizes Notion API payloads into stable package structs."

  alias Jido.Connect.Data

  alias Jido.Connect.Notion.{
    Block,
    Comment,
    Database,
    File,
    Page,
    Pagination,
    ParentRef,
    Property,
    RichText,
    User
  }

  # ---------------------------------------------------------------------------
  # Parent reference
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Notion parent reference into a stable struct."
  @spec parent_ref(map()) :: {:ok, ParentRef.t()} | {:error, term()}
  def parent_ref(payload) when is_map(payload) do
    %{
      type: Data.get(payload, "type"),
      workspace: Data.get(payload, "workspace"),
      page_id: Data.get(payload, "page_id"),
      database_id: Data.get(payload, "database_id"),
      block_id: Data.get(payload, "block_id")
    }
    |> Data.compact()
    |> ParentRef.new()
  end

  def parent_ref(_payload), do: {:error, :invalid_parent_ref_payload}

  # ---------------------------------------------------------------------------
  # Rich text
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Notion rich text segment into a stable struct."
  @spec rich_text(map()) :: {:ok, RichText.t()} | {:error, term()}
  def rich_text(payload) when is_map(payload) do
    %{
      type: Data.get(payload, "type"),
      plain_text: Data.get(payload, "plain_text"),
      href: Data.get(payload, "href"),
      annotations: Data.get(payload, "annotations"),
      text: Data.get(payload, "text"),
      mention: Data.get(payload, "mention"),
      equation: Data.get(payload, "equation")
    }
    |> Data.compact()
    |> RichText.new()
  end

  def rich_text(_payload), do: {:error, :invalid_rich_text_payload}

  @doc "Normalizes a list of rich text segments."
  @spec rich_text_list(list(map())) :: {:ok, [RichText.t()]} | {:error, term()}
  def rich_text_list(payloads) when is_list(payloads) do
    payloads
    |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
      case rich_text(payload) do
        {:ok, segment} -> {:cont, {:ok, [segment | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, segments} -> {:ok, Enum.reverse(segments)}
      {:error, reason} -> {:error, reason}
    end
  end

  def rich_text_list(_payloads), do: {:error, :invalid_rich_text_list_payload}

  # ---------------------------------------------------------------------------
  # File
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Notion file or external file reference into a stable struct."
  @spec file(map()) :: {:ok, File.t()} | {:error, term()}
  def file(payload) when is_map(payload) do
    file_type = Data.get(payload, "type")

    url =
      case file_type do
        "external" -> get_in(payload, ["external", "url"])
        "file" -> get_in(payload, ["file", "url"])
        _ -> nil
      end

    expiry_time =
      case file_type do
        "file" -> get_in(payload, ["file", "expiry_time"])
        _ -> nil
      end

    %{
      type: file_type,
      name: Data.get(payload, "name"),
      url: url,
      expiry_time: expiry_time
    }
    |> Data.compact()
    |> File.new()
  end

  def file(_payload), do: {:error, :invalid_file_payload}

  # ---------------------------------------------------------------------------
  # User
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Notion user (person or bot) into a stable struct."
  @spec user(map()) :: {:ok, User.t()} | {:error, term()}
  def user(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      type: Data.get(payload, "type"),
      name: Data.get(payload, "name"),
      avatar_url: Data.get(payload, "avatar_url"),
      person: Data.get(payload, "person"),
      bot: Data.get(payload, "bot")
    }
    |> Data.compact()
    |> User.new()
  end

  def user(_payload), do: {:error, :invalid_user_payload}

  # ---------------------------------------------------------------------------
  # Property
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Notion property value into a stable struct."
  @spec property(map()) :: {:ok, Property.t()} | {:error, term()}
  def property(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      type: Data.get(payload, "type"),
      name: Data.get(payload, "name"),
      title: Data.get(payload, "title", []),
      rich_text: Data.get(payload, "rich_text", []),
      number: Data.get(payload, "number"),
      select: Data.get(payload, "select"),
      multi_select: Data.get(payload, "multi_select", []),
      date: Data.get(payload, "date"),
      people: Data.get(payload, "people", []),
      files: Data.get(payload, "files", []),
      checkbox: Data.get(payload, "checkbox"),
      url: Data.get(payload, "url"),
      email: Data.get(payload, "email"),
      phone_number: Data.get(payload, "phone_number"),
      formula: Data.get(payload, "formula"),
      relation: Data.get(payload, "relation", []),
      rollup: Data.get(payload, "rollup"),
      status: Data.get(payload, "status")
    }
    |> Data.compact()
    |> Property.new()
  end

  def property(_payload), do: {:error, :invalid_property_payload}

  # ---------------------------------------------------------------------------
  # Block
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Notion content block into a stable struct."
  @spec block(map()) :: {:ok, Block.t()} | {:error, term()}
  def block(payload) when is_map(payload) do
    block_type = Data.get(payload, "type")

    %{
      id: Data.get(payload, "id"),
      type: block_type,
      created_time: Data.get(payload, "created_time"),
      last_edited_time: Data.get(payload, "last_edited_time"),
      has_children: Data.get(payload, "has_children", false),
      archived: Data.get(payload, "archived", false),
      in_trash: Data.get(payload, "in_trash"),
      parent: Data.get(payload, "parent"),
      rich_text: block_rich_text(payload, block_type),
      children: Data.get(payload, "children", []),
      heading: Data.get(payload, "heading"),
      paragraph: Data.get(payload, "paragraph"),
      bulleted_list_item: Data.get(payload, "bulleted_list_item"),
      numbered_list_item: Data.get(payload, "numbered_list_item"),
      to_do: Data.get(payload, "to_do"),
      toggle: Data.get(payload, "toggle"),
      code: Data.get(payload, "code"),
      quote: Data.get(payload, "quote"),
      callout: Data.get(payload, "callout"),
      divider: Data.get(payload, "divider"),
      image: Data.get(payload, "image"),
      file: Data.get(payload, "file"),
      embed: Data.get(payload, "embed"),
      bookmark: Data.get(payload, "bookmark"),
      table: Data.get(payload, "table"),
      table_row: Data.get(payload, "table_row"),
      unsupported: Data.get(payload, "unsupported")
    }
    |> Data.compact()
    |> Block.new()
  end

  def block(_payload), do: {:error, :invalid_block_payload}

  defp block_rich_text(payload, nil), do: Data.get(payload, "rich_text", [])

  defp block_rich_text(payload, block_type) do
    case Data.get(payload, block_type) do
      %{"rich_text" => rich_text} when is_list(rich_text) -> rich_text
      _ -> Data.get(payload, "rich_text", [])
    end
  end

  # ---------------------------------------------------------------------------
  # Page
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Notion page into a stable struct."
  @spec page(map()) :: {:ok, Page.t()} | {:error, term()}
  def page(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      created_time: Data.get(payload, "created_time"),
      last_edited_time: Data.get(payload, "last_edited_time"),
      archived: Data.get(payload, "archived", false),
      in_trash: Data.get(payload, "in_trash"),
      url: Data.get(payload, "url"),
      public_url: Data.get(payload, "public_url"),
      parent: Data.get(payload, "parent"),
      properties: Data.get(payload, "properties", %{}),
      children: Data.get(payload, "children", []),
      cover: Data.get(payload, "cover"),
      icon: Data.get(payload, "icon")
    }
    |> Data.compact()
    |> Page.new()
  end

  def page(_payload), do: {:error, :invalid_page_payload}

  # ---------------------------------------------------------------------------
  # Database
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Notion database into a stable struct."
  @spec database(map()) :: {:ok, Database.t()} | {:error, term()}
  def database(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      created_time: Data.get(payload, "created_time"),
      last_edited_time: Data.get(payload, "last_edited_time"),
      title: Data.get(payload, "title", []),
      description: Data.get(payload, "description", []),
      url: Data.get(payload, "url"),
      public_url: Data.get(payload, "public_url"),
      is_inline: Data.get(payload, "is_inline"),
      parent: Data.get(payload, "parent"),
      properties: Data.get(payload, "properties", %{}),
      cover: Data.get(payload, "cover"),
      icon: Data.get(payload, "icon")
    }
    |> Data.compact()
    |> Database.new()
  end

  def database(_payload), do: {:error, :invalid_database_payload}

  # ---------------------------------------------------------------------------
  # Comment
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Notion discussion comment into a stable struct."
  @spec comment(map()) :: {:ok, Comment.t()} | {:error, term()}
  def comment(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      discussion_id: Data.get(payload, "discussion_id"),
      created_time: Data.get(payload, "created_time"),
      last_edited_time: Data.get(payload, "last_edited_time"),
      created_by: Data.get(payload, "created_by"),
      rich_text: Data.get(payload, "rich_text", []),
      parent: Data.get(payload, "parent")
    }
    |> Data.compact()
    |> Comment.new()
  end

  def comment(_payload), do: {:error, :invalid_comment_payload}

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Notion cursor-based pagination envelope into a stable struct."
  @spec pagination(map()) :: {:ok, Pagination.t()} | {:error, term()}
  def pagination(payload) when is_map(payload) do
    %{
      has_more: Data.get(payload, "has_more", false),
      next_cursor: Data.get(payload, "next_cursor")
    }
    |> Data.compact()
    |> Pagination.new()
  end

  def pagination(_payload), do: {:error, :invalid_pagination_payload}
end
