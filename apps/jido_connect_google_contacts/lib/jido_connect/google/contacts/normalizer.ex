defmodule Jido.Connect.Google.Contacts.Normalizer do
  @moduledoc "Normalizes Google People API payloads into Contacts structs."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.Contacts.{Email, Group, Organization, Person, Phone}

  def person(payload) when is_map(payload) do
    with {:ok, email_addresses} <- normalize_list(payload, "emailAddresses", &email/1),
         {:ok, phone_numbers} <- normalize_list(payload, "phoneNumbers", &phone/1),
         {:ok, organizations} <- normalize_list(payload, "organizations", &organization/1) do
      %{
        resource_name: Data.get(payload, "resourceName"),
        person_id: person_id(Data.get(payload, "resourceName")),
        etag: Data.get(payload, "etag"),
        display_name: primary_name_value(payload, "displayName"),
        given_name: primary_name_value(payload, "givenName"),
        family_name: primary_name_value(payload, "familyName"),
        names: Data.get(payload, "names", []),
        email_addresses: email_addresses,
        phone_numbers: phone_numbers,
        organizations: organizations,
        memberships: Data.get(payload, "memberships", []),
        photos: Data.get(payload, "photos", []),
        addresses: Data.get(payload, "addresses", []),
        birthdays: Data.get(payload, "birthdays", []),
        urls: Data.get(payload, "urls", []),
        metadata: Data.get(payload, "metadata", %{})
      }
      |> Data.compact()
      |> Person.new()
    end
  end

  def person(_payload), do: {:error, :invalid_person}

  def email(payload) when is_map(payload) do
    %{
      value: Data.get(payload, "value"),
      type: Data.get(payload, "type"),
      formatted_type: Data.get(payload, "formattedType"),
      display_name: Data.get(payload, "displayName"),
      primary?: primary?(payload),
      metadata: Data.get(payload, "metadata", %{})
    }
    |> Data.compact()
    |> Email.new()
  end

  def email(_payload), do: {:error, :invalid_email}

  def phone(payload) when is_map(payload) do
    %{
      value: Data.get(payload, "value"),
      canonical_form: Data.get(payload, "canonicalForm"),
      type: Data.get(payload, "type"),
      formatted_type: Data.get(payload, "formattedType"),
      primary?: primary?(payload),
      metadata: Data.get(payload, "metadata", %{})
    }
    |> Data.compact()
    |> Phone.new()
  end

  def phone(_payload), do: {:error, :invalid_phone}

  def organization(payload) when is_map(payload) do
    %{
      name: Data.get(payload, "name"),
      title: Data.get(payload, "title"),
      department: Data.get(payload, "department"),
      symbol: Data.get(payload, "symbol"),
      domain: Data.get(payload, "domain"),
      type: Data.get(payload, "type"),
      formatted_type: Data.get(payload, "formattedType"),
      start_date: Data.get(payload, "startDate"),
      end_date: Data.get(payload, "endDate"),
      current?: Data.get(payload, "current", false),
      primary?: primary?(payload),
      metadata: Data.get(payload, "metadata", %{})
    }
    |> Data.compact()
    |> Organization.new()
  end

  def organization(_payload), do: {:error, :invalid_organization}

  def group(payload) when is_map(payload) do
    %{
      resource_name: Data.get(payload, "resourceName"),
      group_id: group_id(Data.get(payload, "resourceName")),
      name: Data.get(payload, "name"),
      formatted_name: Data.get(payload, "formattedName"),
      group_type: Data.get(payload, "groupType"),
      member_count: Data.get(payload, "memberCount"),
      member_resource_names: Data.get(payload, "memberResourceNames", []),
      client_data: Data.get(payload, "clientData", []),
      etag: Data.get(payload, "etag"),
      metadata: Data.get(payload, "metadata", %{})
    }
    |> Data.compact()
    |> Group.new()
  end

  def group(_payload), do: {:error, :invalid_group}

  defp normalize_list(payload, key, normalizer) do
    case Data.get(payload, key, []) do
      nil ->
        {:ok, []}

      items when is_list(items) ->
        items
        |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
          case normalizer.(item) do
            {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
            {:error, error} -> {:halt, {:error, error}}
          end
        end)
        |> case do
          {:ok, items} -> {:ok, Enum.reverse(items)}
          {:error, error} -> {:error, error}
        end

      _invalid ->
        {:error, {:invalid_list, key}}
    end
  end

  defp primary_name_value(payload, key) do
    payload
    |> Data.get("names", [])
    |> primary_entry()
    |> Data.get(key)
  end

  defp primary_entry(entries) when is_list(entries) do
    Enum.find(entries, &primary?/1) || List.first(entries) || %{}
  end

  defp primary_entry(_entries), do: %{}

  defp primary?(payload) when is_map(payload) do
    payload
    |> Data.get("metadata", %{})
    |> Data.get("primary", false)
  end

  defp primary?(_payload), do: false

  defp person_id("people/" <> id), do: id
  defp person_id(_resource_name), do: nil

  defp group_id("contactGroups/" <> id), do: id
  defp group_id(_resource_name), do: nil
end
