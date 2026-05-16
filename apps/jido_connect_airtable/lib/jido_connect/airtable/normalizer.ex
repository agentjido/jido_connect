defmodule Jido.Connect.Airtable.Normalizer do
  @moduledoc "Normalizes Airtable API payloads into stable package structs."

  alias Jido.Connect.Data
  alias Jido.Connect.Airtable.{Base, Record}

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
end
