defmodule Jido.Connect.HubSpot.Client.Notes do
  @moduledoc "HubSpot CRM v3 API boundary for note creation and association."

  alias Jido.Connect.Data
  alias Jido.Connect.HubSpot.Client.{Response, Transport}
  alias Jido.Connect.HubSpot.Normalizer

  @object_path "/crm/v3/objects/notes"

  @doc "Creates a HubSpot CRM note with optional associations."
  def create_note(params, access_token) when is_map(params) and is_binary(access_token) do
    body = note_write_body(params)

    access_token
    |> Transport.api_request()
    |> Req.post(
      url: @object_path,
      json: body
    )
    |> Response.handle_get_response(&Normalizer.note/1)
  end

  defp note_write_body(params) do
    properties = %{
      "hs_note_body" => Data.get(params, :body)
    }

    properties =
      properties
      |> maybe_put_property("hubspot_owner_id", Data.get(params, :owner_id))

    extra_properties = Data.get(params, :properties, %{}) || %{}
    properties = Map.merge(properties, extra_properties)

    associations = build_associations(params)

    body = %{
      properties: properties
    }

    body = if associations == [], do: body, else: Map.put(body, :associations, associations)
    body
  end

  defp maybe_put_property(map, _key, nil), do: map
  defp maybe_put_property(map, key, value), do: Map.put(map, key, value)

  defp build_associations(params) do
    association_types = [
      {:contact_ids, "contacts", "contact"},
      {:company_ids, "companies", "company"},
      {:deal_ids, "deals", "deal"},
      {:ticket_ids, "tickets", "ticket"}
    ]

    association_types
    |> Enum.flat_map(fn {field, object_type, _to_type} ->
      ids = Data.get(params, field, [])

      Enum.map(ids, fn id ->
        %{
          to: %{"id" => id},
          types: [
            %{
              "associationCategory" => "HUBSPOT_DEFINED",
              "associationTypeId" => association_type_id(object_type)
            }
          ]
        }
      end)
    end)
  end

  # HubSpot-defined default association type IDs for note associations
  defp association_type_id("contacts"), do: 202
  defp association_type_id("companies"), do: 190
  defp association_type_id("deals"), do: 214
  defp association_type_id("tickets"), do: 284
end
