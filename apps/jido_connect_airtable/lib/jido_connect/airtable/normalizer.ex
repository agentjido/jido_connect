defmodule Jido.Connect.Airtable.Normalizer do
  @moduledoc "Normalizes Airtable API payloads into stable package structs."

  alias Jido.Connect.Data

  alias Jido.Connect.Airtable.{
    Attachment,
    Base,
    Comment,
    Field,
    Pagination,
    Record,
    Table,
    View
  }

  @doc "Normalizes an Airtable base payload."
  @spec base(map()) :: {:ok, Base.t()} | {:error, term()}
  def base(payload) when is_map(payload) do
    %{
      base_id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      permission_level: Data.get(payload, "permissionLevel"),
      description: Data.get(payload, "description"),
      metadata:
        %{
          color: Data.get(payload, "color"),
          icon: Data.get(payload, "icon"),
          tables: Data.get(payload, "tables")
        }
        |> Data.compact()
    }
    |> Data.compact()
    |> Base.new()
  end

  def base(_payload), do: {:error, :invalid_base_payload}

  @doc "Normalizes an Airtable record payload."
  @spec record(map()) :: {:ok, Record.t()} | {:error, term()}
  def record(payload) when is_map(payload) do
    %{
      record_id: Data.get(payload, "id"),
      fields: Data.get(payload, "fields", %{}),
      created_time: Data.get(payload, "createdTime"),
      metadata:
        %{
          comment_count: Data.get(payload, "commentCount"),
          created_time: Data.get(payload, "createdTime")
        }
        |> Data.compact()
    }
    |> Data.compact()
    |> Record.new()
  end

  def record(_payload), do: {:error, :invalid_record_payload}

  # ---------------------------------------------------------------------------
  # Table
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Airtable table payload."
  @spec table(map()) :: {:ok, Table.t()} | {:error, term()}
  def table(payload) when is_map(payload) do
    %{
      table_id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      description: Data.get(payload, "description"),
      primary_field_id: Data.get(payload, "primaryFieldId"),
      metadata:
        %{
          fields: Data.get(payload, "fields"),
          views: Data.get(payload, "views")
        }
        |> Data.compact()
    }
    |> Data.compact()
    |> Table.new()
  end

  def table(_payload), do: {:error, :invalid_table_payload}

  # ---------------------------------------------------------------------------
  # Field
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Airtable field (column) payload."
  @spec field(map()) :: {:ok, Field.t()} | {:error, term()}
  def field(payload) when is_map(payload) do
    %{
      field_id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      type: Data.get(payload, "type"),
      description: Data.get(payload, "description"),
      metadata:
        %{
          options: Data.get(payload, "options")
        }
        |> Data.compact()
    }
    |> Data.compact()
    |> Field.new()
  end

  def field(_payload), do: {:error, :invalid_field_payload}

  # ---------------------------------------------------------------------------
  # View
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Airtable view payload."
  @spec view(map()) :: {:ok, View.t()} | {:error, term()}
  def view(payload) when is_map(payload) do
    %{
      view_id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      type: Data.get(payload, "type"),
      description: Data.get(payload, "description"),
      metadata: %{}
    }
    |> Data.compact()
    |> View.new()
  end

  def view(_payload), do: {:error, :invalid_view_payload}

  # ---------------------------------------------------------------------------
  # Attachment
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Airtable attachment payload."
  @spec attachment(map()) :: {:ok, Attachment.t()} | {:error, term()}
  def attachment(payload) when is_map(payload) do
    %{
      attachment_id: Data.get(payload, "id"),
      filename: Data.get(payload, "filename"),
      mime_type: Data.get(payload, "type"),
      size: Data.get(payload, "size"),
      url: Data.get(payload, "url"),
      metadata:
        %{
          width: Data.get(payload, "width"),
          height: Data.get(payload, "height"),
          thumbnails: Data.get(payload, "thumbnails")
        }
        |> Data.compact()
    }
    |> Data.compact()
    |> Attachment.new()
  end

  def attachment(_payload), do: {:error, :invalid_attachment_payload}

  # ---------------------------------------------------------------------------
  # Comment
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Airtable record comment payload."
  @spec comment(map()) :: {:ok, Comment.t()} | {:error, term()}
  def comment(payload) when is_map(payload) do
    %{
      comment_id: Data.get(payload, "id"),
      text: Data.get(payload, "text"),
      author:
        case Data.get(payload, "author") do
          nil -> nil
          author -> author
        end,
      created_time: Data.get(payload, "createdTime"),
      metadata:
        %{
          mentioned: Data.get(payload, "mentioned")
        }
        |> Data.compact()
    }
    |> Data.compact()
    |> Comment.new()
  end

  def comment(_payload), do: {:error, :invalid_comment_payload}

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Airtable API pagination envelope."
  @spec pagination(map()) :: {:ok, Pagination.t()} | {:error, term()}
  def pagination(payload) when is_map(payload) do
    %{
      offset: Data.get(payload, "offset")
    }
    |> Data.compact()
    |> Pagination.new()
  end

  def pagination(_payload), do: {:error, :invalid_pagination_payload}
end
