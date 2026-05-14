defmodule Jido.Connect.Google.Contacts.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Google.Contacts
  alias Jido.Connect.Google.Contacts.{Client, Person}

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(
      :jido_connect_google_contacts,
      :google_contacts_api_base_url,
      "https://people.test"
    )

    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_google_contacts, :google_contacts_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  test "lists people connections" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/people/me/connections"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]
      assert conn.query_params["pageSize"] == "50"
      assert conn.query_params["requestSyncToken"] == "true"
      assert conn.query_params["sortOrder"] == "LAST_MODIFIED_DESCENDING"
      assert conn.query_params["personFields"] =~ "emailAddresses"
      assert conn.query_params["fields"] =~ "nextSyncToken"

      Req.Test.json(conn, %{
        "connections" => [
          person_payload()
        ],
        "nextPageToken" => "contacts-next",
        "nextSyncToken" => "contacts-sync",
        "totalItems" => 1
      })
    end)

    assert {:ok,
            %{
              people: [%Person{} = person],
              next_page_token: "contacts-next",
              next_sync_token: "contacts-sync",
              total_items: 1
            }} =
             Client.list_people(
               %{
                 resource_name: "people/me",
                 page_size: 50,
                 request_sync_token: true,
                 sort_order: "LAST_MODIFIED_DESCENDING"
               },
               "token"
             )

    assert person.resource_name == "people/c123"
    assert person.display_name == "Ada Lovelace"
    assert [%{value: "ada@example.com"}] = person.email_addresses
  end

  test "gets a person by resource name" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/people/c123"
      assert conn.query_params["personFields"] =~ "names"
      assert conn.query_params["fields"] =~ "emailAddresses"

      Req.Test.json(conn, person_payload())
    end)

    assert {:ok, %Person{} = person} =
             Client.get_person(%{resource_name: "people/c123"}, "token")

    assert person.person_id == "c123"
    assert person.given_name == "Ada"
  end

  test "searches people contacts" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/people:searchContacts"
      assert conn.query_params["query"] == "Ada"
      assert conn.query_params["pageSize"] == "10"
      assert conn.query_params["readMask"] =~ "phoneNumbers"
      assert conn.query_params["fields"] =~ "results"

      Req.Test.json(conn, %{
        "results" => [
          %{"person" => person_payload()}
        ]
      })
    end)

    assert {:ok, %{people: [%Person{} = person]}} =
             Client.search_people(%{query: "Ada", page_size: 10}, "token")

    assert person.resource_name == "people/c123"
  end

  test "batch gets people by resource names" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/people:batchGet"
      assert conn.query_string =~ "resourceNames"
      assert conn.query_string =~ "people%2Fc123"
      assert conn.query_string =~ "people%2Fc456"
      assert conn.query_params["personFields"] =~ "emailAddresses"
      assert conn.query_params["fields"] =~ "responses"

      Req.Test.json(conn, %{
        "responses" => [
          %{"person" => person_payload(), "status" => %{"code" => 0}}
        ]
      })
    end)

    assert {:ok, %{people: [%Person{} = person], responses: [%{person: %Person{}}]}} =
             Client.batch_get_people(
               %{resource_names: ["people/c123", "people/c456"]},
               "token"
             )

    assert person.resource_name == "people/c123"
  end

  test "lists directory people" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/people:listDirectoryPeople"
      assert conn.query_params["pageSize"] == "100"
      assert conn.query_params["readMask"] =~ "emailAddresses"
      assert conn.query_string =~ "DIRECTORY_SOURCE_TYPE_DOMAIN_PROFILE"
      assert conn.query_string =~ "DIRECTORY_SOURCE_TYPE_DOMAIN_CONTACT"
      assert conn.query_params["fields"] =~ "nextSyncToken"

      Req.Test.json(conn, %{
        "people" => [person_payload()],
        "nextPageToken" => "directory-next",
        "nextSyncToken" => "directory-sync"
      })
    end)

    assert {:ok,
            %{
              people: [%Person{} = person],
              next_page_token: "directory-next",
              next_sync_token: "directory-sync"
            }} = Client.list_directory_people(%{}, "token")

    assert person.resource_name == "people/c123"
  end

  test "searches directory people" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/people:searchDirectoryPeople"
      assert conn.query_params["query"] == "Ada"
      assert conn.query_params["pageSize"] == "10"
      assert conn.query_string =~ "DIRECTORY_SOURCE_TYPE_DOMAIN_PROFILE"
      assert conn.query_params["fields"] =~ "totalSize"

      Req.Test.json(conn, %{
        "people" => [person_payload()],
        "nextPageToken" => "directory-next",
        "totalSize" => 1
      })
    end)

    assert {:ok, %{people: [%Person{} = person], total_size: 1}} =
             Client.search_directory_people(%{query: "Ada"}, "token")

    assert person.resource_name == "people/c123"
  end

  test "lists other contacts" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/otherContacts"
      assert conn.query_params["pageSize"] == "100"
      assert conn.query_params["readMask"] == "names,emailAddresses,phoneNumbers,photos,metadata"
      refute conn.query_params["readMask"] =~ "organizations"
      assert conn.query_params["fields"] =~ "otherContacts"

      Req.Test.json(conn, %{
        "otherContacts" => [person_payload()],
        "nextPageToken" => "other-next",
        "nextSyncToken" => "other-sync",
        "totalSize" => 1
      })
    end)

    assert {:ok,
            %{
              people: [%Person{} = person],
              next_page_token: "other-next",
              next_sync_token: "other-sync",
              total_size: 1
            }} = Client.list_other_contacts(%{}, "token")

    assert person.resource_name == "people/c123"
  end

  test "searches other contacts" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/otherContacts:search"
      assert conn.query_params["query"] == "Ada"
      assert conn.query_params["readMask"] == "names,emailAddresses,phoneNumbers,metadata"
      refute conn.query_params["readMask"] =~ "organizations"

      Req.Test.json(conn, %{
        "results" => [
          %{"person" => person_payload()}
        ]
      })
    end)

    assert {:ok, %{people: [%Person{} = person]}} =
             Client.search_other_contacts(%{query: "Ada"}, "token")

    assert person.resource_name == "people/c123"
  end

  test "creates contacts" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/people:createContact"
      assert conn.query_params["personFields"] =~ "organizations"
      assert conn.query_params["fields"] =~ "resourceName"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "names" => [
                 %{"givenName" => "Ada", "familyName" => "Lovelace"}
               ],
               "emailAddresses" => [
                 %{"value" => "ada@example.com", "type" => "work"}
               ],
               "phoneNumbers" => [
                 %{"value" => "+1 555 0100", "type" => "mobile"}
               ],
               "organizations" => [
                 %{"name" => "Analytical Engines", "title" => "Programmer"}
               ]
             }

      Req.Test.json(conn, person_payload())
    end)

    assert {:ok, %Person{} = person} =
             Client.create_contact(
               %{
                 given_name: "Ada",
                 family_name: "Lovelace",
                 email_addresses: [%{value: "ada@example.com", type: "work"}],
                 phone_numbers: [%{value: "+1 555 0100", type: "mobile"}],
                 organizations: [%{name: "Analytical Engines", title: "Programmer"}]
               },
               "token"
             )

    assert person.resource_name == "people/c123"
  end

  test "batch creates contacts" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/people:batchCreateContacts"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      decoded = Jason.decode!(body)

      assert decoded["contacts"] == [
               %{"contactPerson" => %{"names" => [%{"givenName" => "Ada"}]}}
             ]

      assert decoded["readMask"] =~ "emailAddresses"

      Req.Test.json(conn, %{
        "createdPeople" => [
          %{"person" => person_payload(), "status" => %{"code" => 0}}
        ]
      })
    end)

    assert {:ok, %{people: [%Person{} = person]}} =
             Client.batch_create_contacts(%{contacts: [%{given_name: "Ada"}]}, "token")

    assert person.resource_name == "people/c123"
  end

  test "updates contacts" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/v1/people/c123:updateContact"
      assert conn.query_params["updatePersonFields"] == "names,emailAddresses"
      assert conn.query_params["personFields"] =~ "emailAddresses"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "resourceName" => "people/c123",
               "etag" => "etag123",
               "names" => [
                 %{"givenName" => "Ada"}
               ],
               "emailAddresses" => [
                 %{"value" => "ada@example.com"}
               ]
             }

      Req.Test.json(conn, Map.put(person_payload(), "etag", "etag456"))
    end)

    assert {:ok, %Person{} = person} =
             Client.update_contact(
               %{
                 resource_name: "people/c123",
                 etag: "etag123",
                 given_name: "Ada",
                 email_addresses: [%{value: "ada@example.com"}],
                 update_person_fields: "names,emailAddresses"
               },
               "token"
             )

    assert person.etag == "etag456"
  end

  test "batch updates contacts" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/people:batchUpdateContacts"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "contacts" => %{
                 "people/c123" => %{
                   "resourceName" => "people/c123",
                   "etag" => "etag123",
                   "names" => [
                     %{"givenName" => "Ada"}
                   ]
                 }
               },
               "updateMask" => "names,emailAddresses,phoneNumbers,organizations",
               "readMask" =>
                 "names,emailAddresses,phoneNumbers,organizations,memberships,photos,addresses,birthdays,urls,metadata"
             }

      Req.Test.json(conn, %{
        "updateResult" => %{
          "people/c123" => %{"person" => Map.put(person_payload(), "etag", "etag456")}
        }
      })
    end)

    assert {:ok,
            %{people: [%Person{} = person], responses: %{"people/c123" => %{person: %Person{}}}}} =
             Client.batch_update_contacts(
               %{contacts: [%{resource_name: "people/c123", etag: "etag123", given_name: "Ada"}]},
               "token"
             )

    assert person.etag == "etag456"
  end

  test "deletes contacts" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v1/people/c123:deleteContact"

      Plug.Conn.resp(conn, 200, "")
    end)

    assert {:ok, %{resource_name: "people/c123", deleted?: true}} =
             Client.delete_contact(%{resource_name: "people/c123"}, "token")
  end

  test "batch deletes contacts" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/people:batchDeleteContacts"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "resourceNames" => ["people/c123", "people/c456"]
             }

      Plug.Conn.resp(conn, 200, "")
    end)

    assert {:ok, %{resource_names: ["people/c123", "people/c456"], deleted?: true}} =
             Client.batch_delete_contacts(
               %{resource_names: ["people/c123", "people/c456"]},
               "token"
             )
  end

  test "copies other contacts to my contacts" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/otherContacts/c123:copyOtherContactToMyContactsGroup"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "copyMask" => "names,emailAddresses,phoneNumbers"
             }

      Req.Test.json(conn, person_payload())
    end)

    assert {:ok, %Person{} = person} =
             Client.copy_other_contact(%{resource_name: "otherContacts/c123"}, "token")

    assert person.resource_name == "people/c123"
  end

  test "lists contact groups" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/contactGroups"
      assert conn.query_params["pageSize"] == "20"
      assert conn.query_params["groupFields"] =~ "memberCount"
      assert conn.query_params["fields"] =~ "contactGroups"

      Req.Test.json(conn, %{
        "contactGroups" => [group_payload()],
        "nextPageToken" => "groups-next",
        "nextSyncToken" => "groups-sync"
      })
    end)

    assert {:ok,
            %{
              groups: [%Contacts.Group{} = group],
              next_page_token: "groups-next",
              next_sync_token: "groups-sync"
            }} = Client.list_contact_groups(%{page_size: 20}, "token")

    assert group.resource_name == "contactGroups/friends"
    assert group.name == "Friends"
  end

  test "gets contact groups" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/contactGroups/friends"
      assert conn.query_params["maxMembers"] == "10"
      assert conn.query_params["groupFields"] =~ "memberCount"
      assert conn.query_params["fields"] =~ "memberResourceNames"

      Req.Test.json(conn, group_payload())
    end)

    assert {:ok, %Contacts.Group{} = group} =
             Client.get_contact_group(
               %{resource_name: "contactGroups/friends", max_members: 10},
               "token"
             )

    assert group.group_id == "friends"
    assert group.member_resource_names == ["people/c123", "people/c456"]
  end

  test "batch gets contact groups" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/contactGroups:batchGet"
      assert conn.query_string =~ "resourceNames=contactGroups%2Ffriends"
      assert conn.query_string =~ "resourceNames=contactGroups%2Fcoworkers"
      assert conn.query_params["fields"] =~ "responses"

      Req.Test.json(conn, %{
        "responses" => [
          %{
            "requestedResourceName" => "contactGroups/friends",
            "contactGroup" => group_payload(),
            "status" => %{"code" => 0}
          }
        ]
      })
    end)

    assert {:ok,
            %{
              groups: [%Contacts.Group{} = group],
              responses: [%{requested_resource_name: "contactGroups/friends"}]
            }} =
             Client.batch_get_contact_groups(
               %{resource_names: ["contactGroups/friends", "contactGroups/coworkers"]},
               "token"
             )

    assert group.resource_name == "contactGroups/friends"
  end

  test "creates contact groups" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/contactGroups"
      assert conn.query_params["fields"] =~ "formattedName"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"contactGroup" => %{"name" => "Friends"}}

      Req.Test.json(conn, group_payload())
    end)

    assert {:ok, %Contacts.Group{} = group} =
             Client.create_contact_group(%{name: "Friends"}, "token")

    assert group.group_id == "friends"
  end

  test "updates contact groups" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/v1/contactGroups/friends"
      assert conn.query_params["updateGroupFields"] == "name"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "contactGroup" => %{
                 "resourceName" => "contactGroups/friends",
                 "etag" => "etag123",
                 "name" => "Close Friends"
               }
             }

      Req.Test.json(conn, Map.put(group_payload(), "name", "Close Friends"))
    end)

    assert {:ok, %Contacts.Group{} = group} =
             Client.update_contact_group(
               %{resource_name: "contactGroups/friends", etag: "etag123", name: "Close Friends"},
               "token"
             )

    assert group.name == "Close Friends"
  end

  test "deletes contact groups" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v1/contactGroups/friends"
      assert conn.query_params["deleteContacts"] == "false"

      Plug.Conn.resp(conn, 200, "")
    end)

    assert {:ok,
            %{resource_name: "contactGroups/friends", delete_contacts?: false, deleted?: true}} =
             Client.delete_contact_group(%{resource_name: "contactGroups/friends"}, "token")
  end

  test "modifies contact group members" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/contactGroups/friends/members:modify"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "resourceNamesToAdd" => ["people/c123"],
               "resourceNamesToRemove" => ["people/c456"]
             }

      Req.Test.json(conn, %{
        "notFoundResourceNames" => [],
        "canNotRemoveLastContactGroupResourceNames" => ["people/c456"]
      })
    end)

    assert {:ok,
            %{
              resource_name: "contactGroups/friends",
              resource_names_to_add: ["people/c123"],
              resource_names_to_remove: ["people/c456"],
              not_found_resource_names: [],
              cannot_remove_last_contact_group_resource_names: ["people/c456"]
            }} =
             Client.modify_contact_group_members(
               %{
                 resource_name: "contactGroups/friends",
                 resource_names_to_add: ["people/c123"],
                 resource_names_to_remove: ["people/c456"]
               },
               "token"
             )
  end

  test "returns provider errors for malformed people list items" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/people/me/connections"

      Req.Test.json(conn, %{
        "connections" => [
          %{"names" => [%{"displayName" => "Missing resource"}]}
        ]
      })
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} = Client.list_people(%{resource_name: "people/me"}, "token")
  end

  test "returns provider errors for malformed person get responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/people/c123"

      Req.Test.json(conn, %{"names" => [%{"displayName" => "Missing resource"}]})
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} = Client.get_person(%{resource_name: "people/c123"}, "token")
  end

  test "returns provider errors for malformed search results" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/people:searchContacts"

      Req.Test.json(conn, %{"results" => [%{"metadata" => %{}}]})
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} = Client.search_people(%{query: "Ada"}, "token")
  end

  defp person_payload do
    %{
      "resourceName" => "people/c123",
      "etag" => "etag123",
      "names" => [
        %{
          "displayName" => "Ada Lovelace",
          "givenName" => "Ada",
          "familyName" => "Lovelace",
          "metadata" => %{"primary" => true}
        }
      ],
      "emailAddresses" => [
        %{"value" => "ada@example.com", "type" => "work", "metadata" => %{"primary" => true}}
      ],
      "phoneNumbers" => [
        %{"value" => "+1 555 0100", "canonicalForm" => "+15550100"}
      ],
      "organizations" => [
        %{"name" => "Analytical Engines", "title" => "Programmer", "current" => true}
      ],
      "metadata" => %{"sources" => [%{"type" => "CONTACT"}]}
    }
  end

  defp group_payload do
    %{
      "resourceName" => "contactGroups/friends",
      "etag" => "etag123",
      "name" => "Friends",
      "formattedName" => "Friends",
      "groupType" => "USER_CONTACT_GROUP",
      "memberCount" => 2,
      "memberResourceNames" => ["people/c123", "people/c456"],
      "clientData" => [%{"key" => "source", "value" => "jido"}],
      "metadata" => %{"deleted" => false}
    }
  end
end
