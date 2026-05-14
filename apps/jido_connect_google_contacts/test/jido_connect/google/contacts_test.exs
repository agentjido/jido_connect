defmodule Jido.Connect.Google.ContactsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Google.Contacts
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @contacts_action_modules [
    Jido.Connect.Google.Contacts.Actions.ListPeople,
    Jido.Connect.Google.Contacts.Actions.GetPerson,
    Jido.Connect.Google.Contacts.Actions.SearchPeople,
    Jido.Connect.Google.Contacts.Actions.ListContactGroups,
    Jido.Connect.Google.Contacts.Actions.BatchGetPeople,
    Jido.Connect.Google.Contacts.Actions.BatchCreateContacts,
    Jido.Connect.Google.Contacts.Actions.BatchUpdateContacts,
    Jido.Connect.Google.Contacts.Actions.BatchDeleteContacts,
    Jido.Connect.Google.Contacts.Actions.ListDirectoryPeople,
    Jido.Connect.Google.Contacts.Actions.SearchDirectoryPeople,
    Jido.Connect.Google.Contacts.Actions.ListOtherContacts,
    Jido.Connect.Google.Contacts.Actions.SearchOtherContacts,
    Jido.Connect.Google.Contacts.Actions.CopyOtherContact,
    Jido.Connect.Google.Contacts.Actions.GetContactGroup,
    Jido.Connect.Google.Contacts.Actions.BatchGetContactGroups,
    Jido.Connect.Google.Contacts.Actions.DeleteContactGroup,
    Jido.Connect.Google.Contacts.Actions.ModifyContactGroupMembers,
    Jido.Connect.Google.Contacts.Actions.CreateContact,
    Jido.Connect.Google.Contacts.Actions.UpdateContact,
    Jido.Connect.Google.Contacts.Actions.DeleteContact,
    Jido.Connect.Google.Contacts.Actions.CreateContactGroup,
    Jido.Connect.Google.Contacts.Actions.UpdateContactGroup
  ]

  @contacts_dsl_fragments [
    Jido.Connect.Google.Contacts.Actions.Read,
    Jido.Connect.Google.Contacts.Actions.Batch,
    Jido.Connect.Google.Contacts.Actions.Directory,
    Jido.Connect.Google.Contacts.Actions.OtherContacts,
    Jido.Connect.Google.Contacts.Actions.Groups,
    Jido.Connect.Google.Contacts.Actions.Write,
    Jido.Connect.Google.Contacts.Triggers.People
  ]

  @contacts_sensor_specs [
    %{
      module: Jido.Connect.Google.Contacts.Sensors.PersonChanged,
      name: "google_contacts_person_changed",
      trigger_id: "google.contacts.person.changed",
      signal_type: "google.contacts.person.changed"
    }
  ]

  defmodule FakeContactsClient do
    def list_people(
          %{resource_name: "people/me", page_size: 100, request_sync_token: false},
          "token"
        ) do
      {:ok,
       %{
         people: [
           Contacts.Person.new!(%{
             resource_name: "people/c123",
             display_name: "Ada Lovelace",
             email_addresses: [%{value: "ada@example.com"}]
           })
         ],
         next_page_token: "contacts-next",
         total_items: 1
       }}
    end

    def list_people(%{sync_token: "contacts-sync-1", request_sync_token: true}, "token") do
      {:ok,
       %{
         people: [
           Contacts.Person.new!(%{
             resource_name: "people/c123",
             etag: "etag123",
             display_name: "Ada Lovelace"
           })
         ],
         next_sync_token: "contacts-sync-2"
       }}
    end

    def list_people(%{resource_name: "people/me", request_sync_token: true}, "token") do
      {:ok, %{people: [], next_sync_token: "contacts-sync-1"}}
    end

    def get_person(%{resource_name: "people/me"}, "token") do
      {:ok,
       Contacts.Person.new!(%{
         resource_name: "people/me",
         display_name: "Ada Lovelace"
       })}
    end

    def search_people(%{query: "Ada", page_size: 10}, "token") do
      {:ok,
       %{
         people: [
           Contacts.Person.new!(%{
             resource_name: "people/c123",
             display_name: "Ada Lovelace"
           })
         ]
       }}
    end

    def batch_get_people(%{resource_names: ["people/c123", "people/me"]}, "token") do
      {:ok,
       %{
         people: [
           Contacts.Person.new!(%{
             resource_name: "people/c123",
             display_name: "Ada Lovelace"
           }),
           Contacts.Person.new!(%{
             resource_name: "people/me",
             display_name: "Mike Hostetler"
           })
         ]
       }}
    end

    def batch_create_contacts(%{contacts: [%{given_name: "Ada"}]}, "token") do
      {:ok,
       %{
         people: [
           Contacts.Person.new!(%{
             resource_name: "people/c123",
             display_name: "Ada Lovelace"
           })
         ]
       }}
    end

    def batch_update_contacts(
          %{contacts: [%{resource_name: "people/c123", etag: "etag123", given_name: "Ada"}]},
          "token"
        ) do
      {:ok,
       %{
         people: [
           Contacts.Person.new!(%{
             resource_name: "people/c123",
             etag: "etag456",
             given_name: "Ada"
           })
         ],
         responses: %{
           "people/c123" => %{
             person:
               Contacts.Person.new!(%{
                 resource_name: "people/c123",
                 etag: "etag456",
                 given_name: "Ada"
               })
           }
         }
       }}
    end

    def batch_delete_contacts(%{resource_names: ["people/c123", "people/c456"]}, "token") do
      {:ok, %{resource_names: ["people/c123", "people/c456"], deleted?: true}}
    end

    def list_directory_people(%{page_size: 100, request_sync_token: false}, "token") do
      {:ok,
       %{
         people: [
           Contacts.Person.new!(%{
             resource_name: "people/directory-123",
             display_name: "Ada Directory"
           })
         ],
         next_page_token: "directory-next"
       }}
    end

    def search_directory_people(%{query: "Ada", page_size: 10}, "token") do
      {:ok,
       %{
         people: [
           Contacts.Person.new!(%{
             resource_name: "people/directory-123",
             display_name: "Ada Directory"
           })
         ],
         total_size: 1
       }}
    end

    def list_other_contacts(%{page_size: 100, request_sync_token: false}, "token") do
      {:ok,
       %{
         people: [
           Contacts.Person.new!(%{
             resource_name: "otherContacts/c123",
             display_name: "Ada Other"
           })
         ],
         next_sync_token: "other-sync",
         total_size: 1
       }}
    end

    def search_other_contacts(%{query: "Ada", page_size: 10}, "token") do
      {:ok,
       %{
         people: [
           Contacts.Person.new!(%{
             resource_name: "otherContacts/c123",
             display_name: "Ada Other"
           })
         ]
       }}
    end

    def search_other_contacts(%{query: "", page_size: 10}, "token") do
      {:ok, %{people: []}}
    end

    def copy_other_contact(%{resource_name: "otherContacts/c123"}, "token") do
      {:ok,
       Contacts.Person.new!(%{
         resource_name: "people/c123",
         display_name: "Ada Other"
       })}
    end

    def create_contact(
          %{
            given_name: "Ada",
            family_name: "Lovelace",
            email_addresses: [%{value: "ada@example.com"}],
            phone_numbers: [%{value: "+1 555 0100"}],
            organizations: [%{name: "Analytical Engines"}]
          },
          "token"
        ) do
      {:ok,
       Contacts.Person.new!(%{
         resource_name: "people/c123",
         display_name: "Ada Lovelace"
       })}
    end

    def update_contact(
          %{
            resource_name: "people/c123",
            etag: "etag123",
            given_name: "Ada"
          },
          "token"
        ) do
      {:ok,
       Contacts.Person.new!(%{
         resource_name: "people/c123",
         etag: "etag456",
         given_name: "Ada"
       })}
    end

    def delete_contact(%{resource_name: "people/c123"}, "token") do
      {:ok, %{resource_name: "people/c123", deleted?: true}}
    end

    def list_contact_groups(%{page_size: 30}, "token") do
      {:ok,
       %{
         groups: [
           Contacts.Group.new!(%{
             resource_name: "contactGroups/friends",
             name: "Friends",
             member_count: 2
           })
         ],
         next_sync_token: "groups-sync"
       }}
    end

    def get_contact_group(%{resource_name: "contactGroups/friends"}, "token") do
      {:ok,
       Contacts.Group.new!(%{
         resource_name: "contactGroups/friends",
         name: "Friends",
         member_count: 2,
         member_resource_names: ["people/c123", "people/c456"]
       })}
    end

    def batch_get_contact_groups(
          %{resource_names: ["contactGroups/friends", "contactGroups/coworkers"]},
          "token"
        ) do
      {:ok,
       %{
         groups: [
           Contacts.Group.new!(%{
             resource_name: "contactGroups/friends",
             name: "Friends"
           }),
           Contacts.Group.new!(%{
             resource_name: "contactGroups/coworkers",
             name: "Coworkers"
           })
         ]
       }}
    end

    def create_contact_group(%{name: "Leads"}, "token") do
      {:ok,
       Contacts.Group.new!(%{
         resource_name: "contactGroups/leads",
         name: "Leads"
       })}
    end

    def update_contact_group(
          %{resource_name: "contactGroups/leads", name: "Prospects"},
          "token"
        ) do
      {:ok,
       Contacts.Group.new!(%{
         resource_name: "contactGroups/leads",
         name: "Prospects"
       })}
    end

    def delete_contact_group(%{resource_name: "contactGroups/leads"}, "token") do
      {:ok, %{resource_name: "contactGroups/leads", delete_contacts?: false, deleted?: true}}
    end

    def modify_contact_group_members(
          %{
            resource_name: "contactGroups/leads",
            resource_names_to_add: ["people/c123"],
            resource_names_to_remove: []
          },
          "token"
        ) do
      {:ok,
       %{
         resource_name: "contactGroups/leads",
         resource_names_to_add: ["people/c123"],
         resource_names_to_remove: [],
         not_found_resource_names: []
       }}
    end
  end

  test "declares Google Contacts provider metadata" do
    spec = Contacts.integration()

    assert spec.id == :google_contacts
    assert spec.package == :jido_connect_google_contacts
    assert spec.name == "Google Contacts"
    assert spec.tags == [:google, :workspace, :contacts, :productivity]
    assert spec.status == :experimental

    ConnectorContracts.assert_google_naming_and_catalog_conventions(Contacts,
      id_prefix: "google.contacts.",
      pack_id_prefix: "google_contacts_",
      module_namespace: Jido.Connect.Google.Contacts
    )

    assert Enum.map(spec.actions, & &1.id) == [
             "google.contacts.person.list",
             "google.contacts.person.get",
             "google.contacts.person.search",
             "google.contacts.group.list",
             "google.contacts.person.batch_get",
             "google.contacts.person.batch_create",
             "google.contacts.person.batch_update",
             "google.contacts.person.batch_delete",
             "google.contacts.directory.list",
             "google.contacts.directory.search",
             "google.contacts.other.list",
             "google.contacts.other.search",
             "google.contacts.other.copy",
             "google.contacts.group.get",
             "google.contacts.group.batch_get",
             "google.contacts.group.delete",
             "google.contacts.group.member.modify",
             "google.contacts.person.create",
             "google.contacts.person.update",
             "google.contacts.person.delete",
             "google.contacts.group.create",
             "google.contacts.group.update"
           ]

    assert Enum.map(spec.triggers, & &1.id) == ["google.contacts.person.changed"]

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "email" in profile.default_scopes
    assert "profile" in profile.default_scopes
    assert "https://www.googleapis.com/auth/contacts.readonly" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/contacts" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/contacts.other.readonly" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/directory.readonly" in profile.optional_scopes
  end

  test "compiles generated Jido plugin surface" do
    ConnectorContracts.assert_generated_surface(Contacts,
      otp_app: :jido_connect_google_contacts,
      action_modules: @contacts_action_modules,
      sensor_specs: @contacts_sensor_specs,
      plugin_module: Jido.Connect.Google.Contacts.Plugin,
      plugin_name: "google_contacts"
    )

    ConnectorContracts.assert_catalog_pack_delegates(Contacts,
      readonly_pack: :google_contacts_readonly,
      manager_pack: :google_contacts_manager
    )

    ConnectorContracts.assert_plugin_tool_availability(Contacts)
  end

  test "loads Contacts Spark DSL fragments" do
    ConnectorContracts.assert_spark_fragments(@contacts_dsl_fragments)
  end

  test "invokes Contacts person read and search actions through the runtime" do
    {context, lease} = context_and_lease()

    assert {:ok, %{people: [%{display_name: "Ada Lovelace"}], next_page_token: "contacts-next"}} =
             Connect.invoke(Contacts, "google.contacts.person.list", %{},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{person: %{resource_name: "people/me", display_name: "Ada Lovelace"}}} =
             Connect.invoke(Contacts, "google.contacts.person.get", %{resource_name: "people/me"},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{people: [%{resource_name: "people/c123"}]}} =
             Connect.invoke(Contacts, "google.contacts.person.search", %{query: "Ada"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes Contacts batch actions through the runtime" do
    {context, lease} = context_and_lease(scopes: ["https://www.googleapis.com/auth/contacts"])

    assert {:ok, %{people: [%{resource_name: "people/c123"}, %{resource_name: "people/me"}]}} =
             Connect.invoke(
               Contacts,
               "google.contacts.person.batch_get",
               %{resource_names: ["people/c123", "people/me"]},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{people: [%{resource_name: "people/c123"}]}} =
             Connect.invoke(
               Contacts,
               "google.contacts.person.batch_create",
               %{contacts: [%{given_name: "Ada"}]},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{people: [%{etag: "etag456"}], responses: %{"people/c123" => response}}} =
             Connect.invoke(
               Contacts,
               "google.contacts.person.batch_update",
               %{contacts: [%{resource_name: "people/c123", etag: "etag123", given_name: "Ada"}]},
               context: context,
               credential_lease: lease
             )

    assert response.person.resource_name == "people/c123"

    assert {:ok, %{result: %{resource_names: ["people/c123", "people/c456"], deleted?: true}}} =
             Connect.invoke(
               Contacts,
               "google.contacts.person.batch_delete",
               %{resource_names: ["people/c123", "people/c456"]},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes Contacts directory and other-contact actions through the runtime" do
    {directory_context, directory_lease} =
      context_and_lease(scopes: ["https://www.googleapis.com/auth/directory.readonly"])

    assert {:ok,
            %{
              people: [%{resource_name: "people/directory-123"}],
              next_page_token: "directory-next"
            }} =
             Connect.invoke(Contacts, "google.contacts.directory.list", %{},
               context: directory_context,
               credential_lease: directory_lease
             )

    assert {:ok, %{people: [%{display_name: "Ada Directory"}], total_size: 1}} =
             Connect.invoke(Contacts, "google.contacts.directory.search", %{query: "Ada"},
               context: directory_context,
               credential_lease: directory_lease
             )

    {other_context, other_lease} =
      context_and_lease(scopes: ["https://www.googleapis.com/auth/contacts.other.readonly"])

    assert {:ok,
            %{people: [%{resource_name: "otherContacts/c123"}], next_sync_token: "other-sync"}} =
             Connect.invoke(Contacts, "google.contacts.other.list", %{},
               context: other_context,
               credential_lease: other_lease
             )

    assert {:ok, %{people: [%{display_name: "Ada Other"}]}} =
             Connect.invoke(Contacts, "google.contacts.other.search", %{query: "Ada"},
               context: other_context,
               credential_lease: other_lease
             )

    assert {:ok, %{people: []}} =
             Connect.invoke(Contacts, "google.contacts.other.search", %{query: ""},
               context: other_context,
               credential_lease: other_lease
             )

    assert {:ok, %{person: %{resource_name: "people/c123", display_name: "Ada Other"}}} =
             Connect.invoke(
               Contacts,
               "google.contacts.other.copy",
               %{resource_name: "otherContacts/c123"},
               context: other_context,
               credential_lease: other_lease
             )
  end

  test "invokes Contacts contact mutation actions through the runtime" do
    {context, lease} = context_and_lease(scopes: ["https://www.googleapis.com/auth/contacts"])

    assert {:ok, %{person: %{resource_name: "people/c123", display_name: "Ada Lovelace"}}} =
             Connect.invoke(
               Contacts,
               "google.contacts.person.create",
               %{
                 given_name: "Ada",
                 family_name: "Lovelace",
                 email_addresses: [%{value: "ada@example.com"}],
                 phone_numbers: [%{value: "+1 555 0100"}],
                 organizations: [%{name: "Analytical Engines"}]
               },
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{person: %{resource_name: "people/c123", etag: "etag456"}}} =
             Connect.invoke(
               Contacts,
               "google.contacts.person.update",
               %{resource_name: "people/c123", etag: "etag123", given_name: "Ada"},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{result: %{resource_name: "people/c123", deleted?: true}}} =
             Connect.invoke(
               Contacts,
               "google.contacts.person.delete",
               %{resource_name: "people/c123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes Contacts contact group actions through the runtime" do
    {context, lease} = context_and_lease(scopes: ["https://www.googleapis.com/auth/contacts"])

    assert {:ok, %{groups: [%{name: "Friends"}], next_sync_token: "groups-sync"}} =
             Connect.invoke(Contacts, "google.contacts.group.list", %{},
               context: context,
               credential_lease: lease
             )

    assert {:ok,
            %{group: %{resource_name: "contactGroups/friends", member_resource_names: members}}} =
             Connect.invoke(
               Contacts,
               "google.contacts.group.get",
               %{resource_name: "contactGroups/friends"},
               context: context,
               credential_lease: lease
             )

    assert members == ["people/c123", "people/c456"]

    assert {:ok, %{groups: [%{name: "Friends"}, %{name: "Coworkers"}]}} =
             Connect.invoke(
               Contacts,
               "google.contacts.group.batch_get",
               %{resource_names: ["contactGroups/friends", "contactGroups/coworkers"]},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{group: %{resource_name: "contactGroups/leads", name: "Leads"}}} =
             Connect.invoke(Contacts, "google.contacts.group.create", %{name: "Leads"},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{group: %{resource_name: "contactGroups/leads", name: "Prospects"}}} =
             Connect.invoke(
               Contacts,
               "google.contacts.group.update",
               %{resource_name: "contactGroups/leads", name: "Prospects"},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{result: %{resource_name: "contactGroups/leads", deleted?: true}}} =
             Connect.invoke(
               Contacts,
               "google.contacts.group.delete",
               %{resource_name: "contactGroups/leads"},
               context: context,
               credential_lease: lease
             )

    assert {:ok,
            %{result: %{resource_names_to_add: ["people/c123"], not_found_resource_names: []}}} =
             Connect.invoke(
               Contacts,
               "google.contacts.group.member.modify",
               %{
                 resource_name: "contactGroups/leads",
                 resource_names_to_add: ["people/c123"],
                 resource_names_to_remove: []
               },
               context: context,
               credential_lease: lease
             )
  end

  test "contact change poll initializes checkpoint without replaying contacts" do
    {context, lease} = context_and_lease()

    assert {:ok, %{signals: [], checkpoint: "contacts-sync-1"}} =
             Connect.poll(
               Contacts.integration(),
               "google.contacts.person.changed",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "contact change poll emits normalized people and advances checkpoint" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              signals: [
                %{
                  resource_name: "people/c123",
                  person_id: "c123",
                  etag: "etag123",
                  deleted: false,
                  display_name: "Ada Lovelace",
                  person: %{resource_name: "people/c123"}
                }
              ],
              checkpoint: "contacts-sync-2"
            }} =
             Connect.poll(
               Contacts.integration(),
               "google.contacts.person.changed",
               %{},
               context: context,
               credential_lease: lease,
               checkpoint: "contacts-sync-1"
             )
  end

  defp context_and_lease(opts \\ []) do
    scopes =
      [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/contacts.readonly"
      ] ++ Keyword.get(opts, :scopes, [])

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token", google_contacts_client: FakeContactsClient},
        scopes: scopes
      })

    {context, lease}
  end
end
