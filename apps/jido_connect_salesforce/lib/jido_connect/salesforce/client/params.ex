defmodule Jido.Connect.Salesforce.Client.Params do
  @moduledoc "Salesforce REST API request parameter helpers."

  alias Jido.Connect.Data

  @default_contact_fields [
    "Id",
    "FirstName",
    "LastName",
    "Email",
    "Phone",
    "Title",
    "AccountId",
    "CreatedDate",
    "LastModifiedDate"
  ]

  def default_contact_fields, do: @default_contact_fields

  @doc "Builds a SOQL query for contact list requests."
  def contacts_soql(opts \\ []) do
    fields = Data.get(opts, :fields, @default_contact_fields)
    where = Data.get(opts, :where)
    limit = Data.get(opts, :limit)
    offset = Data.get(opts, :offset)

    field_list = Enum.join(fields, ", ")

    query = "SELECT #{field_list} FROM Contact"

    query =
      case where do
        nil -> query
        clause -> "#{query} WHERE #{clause}"
      end

    query =
      case limit do
        nil -> query
        n -> "#{query} LIMIT #{n}"
      end

    query =
      case offset do
        nil -> query
        n -> "#{query} OFFSET #{n}"
      end

    query
  end

  @doc "Builds the JSON body for contact create requests."
  def contact_write_body(params) do
    build_properties(params, %{
      first_name: "FirstName",
      last_name: "LastName",
      email: "Email",
      phone: "Phone",
      title: "Title",
      account_id: "AccountId"
    })
  end

  defp build_properties(params, field_map) do
    extra = Data.get(params, :properties, %{}) || %{}

    mapped =
      field_map
      |> Enum.reduce(%{}, fn {param_key, api_key}, acc ->
        case Data.get(params, param_key) do
          nil -> acc
          value -> Map.put(acc, api_key, to_string(value))
        end
      end)

    Map.merge(mapped, extra)
  end
end
