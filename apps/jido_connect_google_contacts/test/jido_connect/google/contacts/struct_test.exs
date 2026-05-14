defmodule Jido.Connect.Google.Contacts.StructTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Contacts.{Email, Group, Organization, Person, Phone}
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "person structs expose nested contact defaults and schemas" do
    person =
      ConnectorContracts.assert_struct_defaults(Person, %{resource_name: "people/c123"},
        names: [],
        email_addresses: [],
        phone_numbers: [],
        organizations: [],
        memberships: [],
        photos: [],
        addresses: [],
        birthdays: [],
        urls: [],
        metadata: %{}
      )

    assert %Person{} = person
    assert {:error, _error} = Person.new(%{})
  end

  test "person structs coerce nested email, phone, and organization maps" do
    person =
      Person.new!(%{
        resource_name: "people/c123",
        display_name: "Ada Lovelace",
        given_name: "Ada",
        family_name: "Lovelace",
        email_addresses: [
          %{value: "ada@example.com", type: "work", display_name: "Ada", primary?: true}
        ],
        phone_numbers: [
          %{value: "+1 555 0100", canonical_form: "+15550100", type: "mobile"}
        ],
        organizations: [
          %{name: "Analytical Engines", title: "Programmer", current?: true}
        ]
      })

    assert [%Email{value: "ada@example.com", primary?: true}] = person.email_addresses
    assert [%Phone{canonical_form: "+15550100"}] = person.phone_numbers
    assert [%Organization{name: "Analytical Engines", current?: true}] = person.organizations
  end

  test "contact group structs expose schema defaults" do
    group =
      ConnectorContracts.assert_struct_defaults(
        Group,
        %{resource_name: "contactGroups/friends"},
        member_resource_names: [],
        client_data: [],
        metadata: %{}
      )

    assert %Group{} = group
    assert {:error, _error} = Group.new(%{})
  end

  test "email, phone, and organization structs validate with Zoi" do
    ConnectorContracts.assert_struct_defaults(Email, %{value: "person@example.com"},
      primary?: false,
      metadata: %{}
    )

    assert {:error, _error} = Email.new(%{})

    ConnectorContracts.assert_struct_defaults(Phone, %{value: "+1 555 0100"},
      primary?: false,
      metadata: %{}
    )

    assert {:error, _error} = Phone.new(%{})

    ConnectorContracts.assert_struct_defaults(Organization, %{name: "Originate"},
      current?: false,
      primary?: false,
      metadata: %{}
    )
  end
end
