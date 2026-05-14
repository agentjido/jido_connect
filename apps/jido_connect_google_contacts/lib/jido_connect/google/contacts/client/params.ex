defmodule Jido.Connect.Google.Contacts.Client.Params do
  @moduledoc "Google People API request parameter helpers for Contacts."

  alias Jido.Connect.Data

  @default_person_fields [
    "names",
    "emailAddresses",
    "phoneNumbers",
    "organizations",
    "memberships",
    "photos",
    "addresses",
    "birthdays",
    "urls",
    "metadata"
  ]

  @default_update_person_fields [
    "names",
    "emailAddresses",
    "phoneNumbers",
    "organizations"
  ]

  @default_group_fields [
    "metadata",
    "groupType",
    "memberCount",
    "name"
  ]

  @default_directory_sources [
    "DIRECTORY_SOURCE_TYPE_DOMAIN_PROFILE",
    "DIRECTORY_SOURCE_TYPE_DOMAIN_CONTACT"
  ]

  @default_other_contact_fields [
    "names",
    "emailAddresses",
    "phoneNumbers",
    "photos",
    "metadata"
  ]

  @default_other_contact_search_fields [
    "names",
    "emailAddresses",
    "phoneNumbers",
    "metadata"
  ]

  @default_other_contact_copy_fields [
    "names",
    "emailAddresses",
    "phoneNumbers"
  ]

  @doc "Default People API person fields used by Contacts read actions."
  def default_person_fields, do: Enum.join(@default_person_fields, ",")

  @doc "Default People API update mask for Contacts mutation actions."
  def default_update_person_fields, do: Enum.join(@default_update_person_fields, ",")

  @doc "Default People API contact group fields used by Contacts group actions."
  def default_group_fields, do: Enum.join(@default_group_fields, ",")

  @doc "Default People API directory source types for directory actions."
  def default_directory_sources, do: @default_directory_sources

  @doc "Default People API other-contact read fields."
  def default_other_contact_fields, do: Enum.join(@default_other_contact_fields, ",")

  @doc "Default People API other-contact search fields."
  def default_other_contact_search_fields,
    do: Enum.join(@default_other_contact_search_fields, ",")

  @doc "Default People API other-contact copy fields."
  def default_other_contact_copy_fields, do: Enum.join(@default_other_contact_copy_fields, ",")

  @doc "Builds query params for `people.connections.list`."
  def list_people_params(params) do
    %{
      pageSize: Data.get(params, :page_size, 100),
      pageToken: Data.get(params, :page_token),
      personFields: Data.get(params, :person_fields, default_person_fields()),
      fields: Data.get(params, :fields, people_list_fields()),
      sortOrder: Data.get(params, :sort_order),
      sources: Data.get(params, :sources),
      requestSyncToken: Data.get(params, :request_sync_token),
      syncToken: Data.get(params, :sync_token)
    }
    |> query_params()
  end

  @doc "Builds query params for `people.get`."
  def get_person_params(params) do
    %{
      personFields: Data.get(params, :person_fields, default_person_fields()),
      fields: Data.get(params, :fields, person_response_fields()),
      sources: Data.get(params, :sources)
    }
    |> query_params()
  end

  @doc "Builds query params for `people.getBatchGet`."
  def batch_get_people_params(params) do
    %{
      resourceNames: Data.get(params, :resource_names, []),
      personFields: Data.get(params, :person_fields, default_person_fields()),
      fields: Data.get(params, :fields, person_batch_response_fields()),
      sources: Data.get(params, :sources)
    }
    |> query_params()
  end

  @doc "Builds query params for `people.searchContacts`."
  def search_people_params(params) do
    %{
      query: Data.get(params, :query),
      pageSize: Data.get(params, :page_size, 10),
      readMask: Data.get(params, :read_mask, default_person_fields()),
      fields: Data.get(params, :fields, people_search_fields()),
      sources: Data.get(params, :sources)
    }
    |> query_params()
  end

  @doc "Builds query params for `people.listDirectoryPeople`."
  def list_directory_people_params(params) do
    %{
      readMask: Data.get(params, :read_mask, default_person_fields()),
      sources: Data.get(params, :sources, default_directory_sources()),
      mergeSources: Data.get(params, :merge_sources),
      pageSize: Data.get(params, :page_size, 100),
      pageToken: Data.get(params, :page_token),
      requestSyncToken: Data.get(params, :request_sync_token),
      syncToken: Data.get(params, :sync_token),
      fields: Data.get(params, :fields, directory_list_fields())
    }
    |> query_params()
  end

  @doc "Builds query params for `people.searchDirectoryPeople`."
  def search_directory_people_params(params) do
    %{
      query: Data.get(params, :query),
      readMask: Data.get(params, :read_mask, default_person_fields()),
      sources: Data.get(params, :sources, default_directory_sources()),
      mergeSources: Data.get(params, :merge_sources),
      pageSize: Data.get(params, :page_size, 10),
      pageToken: Data.get(params, :page_token),
      fields: Data.get(params, :fields, directory_search_fields())
    }
    |> query_params()
  end

  @doc "Builds query params for `otherContacts.list`."
  def list_other_contacts_params(params) do
    %{
      readMask: Data.get(params, :read_mask, default_other_contact_fields()),
      sources: Data.get(params, :sources),
      pageSize: Data.get(params, :page_size, 100),
      pageToken: Data.get(params, :page_token),
      requestSyncToken: Data.get(params, :request_sync_token),
      syncToken: Data.get(params, :sync_token),
      fields: Data.get(params, :fields, other_contacts_list_fields())
    }
    |> query_params()
  end

  @doc "Builds query params for `otherContacts.search`."
  def search_other_contacts_params(params) do
    %{
      query: Data.get(params, :query),
      readMask: Data.get(params, :read_mask, default_other_contact_search_fields()),
      pageSize: Data.get(params, :page_size, 10),
      fields: Data.get(params, :fields, people_search_fields())
    }
    |> query_params()
  end

  @doc "Builds a copy request body for `otherContacts.copyOtherContactToMyContactsGroup`."
  def copy_other_contact_body(params) do
    %{
      copyMask: Data.get(params, :copy_mask, default_other_contact_copy_fields()),
      readMask: Data.get(params, :read_mask),
      sources: Data.get(params, :sources)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `people.createContact`."
  def create_contact_params(params) do
    %{
      personFields: Data.get(params, :person_fields, default_person_fields()),
      fields: Data.get(params, :fields, person_response_fields())
    }
    |> query_params()
  end

  @doc "Builds a Google People API batch contact create body."
  def batch_create_contacts_body(params) do
    %{
      contacts: batch_contacts_to_create(Data.get(params, :contacts, [])),
      readMask: Data.get(params, :person_fields, default_person_fields()),
      sources: Data.get(params, :sources)
    }
    |> Data.compact()
  end

  @doc "Builds a Google People API batch contact update body."
  def batch_update_contacts_body(params) do
    %{
      contacts: batch_contacts_to_update(Data.get(params, :contacts, [])),
      updateMask: Data.get(params, :update_person_fields, default_update_person_fields()),
      readMask: Data.get(params, :person_fields, default_person_fields()),
      sources: Data.get(params, :sources)
    }
    |> Data.compact()
  end

  @doc "Builds a Google People API batch contact delete body."
  def batch_delete_contacts_body(params) do
    %{
      resourceNames: Data.get(params, :resource_names, [])
    }
    |> Data.compact()
  end

  @doc "Builds query params for `people.updateContact`."
  def update_contact_params(params) do
    %{
      updatePersonFields: Data.get(params, :update_person_fields, default_update_person_fields()),
      personFields: Data.get(params, :person_fields, default_person_fields()),
      fields: Data.get(params, :fields, person_response_fields())
    }
    |> query_params()
  end

  @doc "Builds a Google People API contact mutation body."
  def contact_body(params) do
    %{
      resourceName: Data.get(params, :resource_name),
      etag: Data.get(params, :etag),
      names: names_body(params),
      emailAddresses: contact_detail_body(params, :email_addresses, &email_body/1),
      phoneNumbers: contact_detail_body(params, :phone_numbers, &phone_body/1),
      organizations: contact_detail_body(params, :organizations, &organization_body/1)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `contactGroups.list`."
  def list_contact_groups_params(params) do
    %{
      pageSize: Data.get(params, :page_size, 30),
      pageToken: Data.get(params, :page_token),
      syncToken: Data.get(params, :sync_token),
      groupFields: Data.get(params, :group_fields, default_group_fields()),
      fields: Data.get(params, :fields, contact_group_list_fields())
    }
    |> query_params()
  end

  @doc "Builds query params for `contactGroups.create`."
  def create_contact_group_params(params) do
    %{
      fields: Data.get(params, :fields, contact_group_response_fields())
    }
    |> query_params()
  end

  @doc "Builds query params for `contactGroups.update`."
  def update_contact_group_params(params) do
    %{
      updateGroupFields: Data.get(params, :update_group_fields, "name"),
      fields: Data.get(params, :fields, contact_group_response_fields())
    }
    |> query_params()
  end

  @doc "Builds a Google People API contact group mutation body."
  def contact_group_body(params) do
    %{
      contactGroup:
        %{
          resourceName: Data.get(params, :resource_name),
          etag: Data.get(params, :etag),
          name: Data.get(params, :name)
        }
        |> Data.compact()
    }
  end

  defp query_params(params) do
    params
    |> Data.compact()
    |> Enum.flat_map(fn
      {_key, []} ->
        []

      {key, values} when is_list(values) ->
        Enum.map(values, &{key, &1})

      pair ->
        [pair]
    end)
  end

  defp people_list_fields do
    "nextPageToken,nextSyncToken,totalItems,connections(#{person_response_fields()})"
  end

  defp people_search_fields do
    "results(person(#{person_response_fields()}))"
  end

  defp directory_list_fields do
    "nextPageToken,nextSyncToken,people(#{person_response_fields()})"
  end

  defp directory_search_fields do
    "nextPageToken,totalSize,people(#{person_response_fields()})"
  end

  defp other_contacts_list_fields do
    "nextPageToken,nextSyncToken,totalSize,otherContacts(#{person_response_fields()})"
  end

  defp person_batch_response_fields do
    "responses(person(#{person_response_fields()}),status)"
  end

  defp person_response_fields do
    "resourceName,etag,#{default_person_fields()}"
  end

  defp contact_group_list_fields do
    "nextPageToken,nextSyncToken,contactGroups(#{contact_group_response_fields()})"
  end

  defp contact_group_response_fields do
    "resourceName,etag,metadata,groupType,memberCount,name,formattedName"
  end

  defp batch_contacts_to_create(contacts) when is_list(contacts) do
    Enum.map(contacts, fn contact ->
      %{contactPerson: contact_body(contact)}
    end)
  end

  defp batch_contacts_to_create(_contacts), do: []

  defp batch_contacts_to_update(contacts) when is_list(contacts) do
    contacts
    |> Enum.map(fn contact ->
      resource_name = Data.get(contact, :resource_name)
      {resource_name, contact_body(contact)}
    end)
    |> Enum.reject(fn {resource_name, _body} -> is_nil(resource_name) end)
    |> Map.new()
  end

  defp batch_contacts_to_update(_contacts), do: %{}

  defp names_body(params) do
    case Data.get(params, :names) do
      names when is_list(names) ->
        Enum.map(names, &name_body/1)

      _missing ->
        inferred_name_body(params)
    end
  end

  defp inferred_name_body(params) do
    name =
      %{
        displayName: Data.get(params, :display_name),
        givenName: Data.get(params, :given_name),
        familyName: Data.get(params, :family_name)
      }
      |> Data.compact()

    if map_size(name) == 0, do: nil, else: [name]
  end

  defp name_body(name) do
    %{
      displayName: Data.get(name, :display_name),
      givenName: Data.get(name, :given_name),
      familyName: Data.get(name, :family_name),
      middleName: Data.get(name, :middle_name),
      honorificPrefix: Data.get(name, :honorific_prefix),
      honorificSuffix: Data.get(name, :honorific_suffix)
    }
    |> Data.compact()
  end

  defp contact_detail_body(params, field, mapper) do
    case Data.get(params, field) do
      details when is_list(details) -> Enum.map(details, mapper)
      _missing -> nil
    end
  end

  defp email_body(email) do
    %{
      value: Data.get(email, :value),
      type: Data.get(email, :type),
      displayName: Data.get(email, :display_name)
    }
    |> Data.compact()
  end

  defp phone_body(phone) do
    %{
      value: Data.get(phone, :value),
      canonicalForm: Data.get(phone, :canonical_form),
      type: Data.get(phone, :type)
    }
    |> Data.compact()
  end

  defp organization_body(organization) do
    %{
      name: Data.get(organization, :name),
      title: Data.get(organization, :title),
      department: Data.get(organization, :department),
      symbol: Data.get(organization, :symbol),
      domain: Data.get(organization, :domain),
      type: Data.get(organization, :type),
      current: Data.get(organization, :current)
    }
    |> Data.compact()
  end
end
