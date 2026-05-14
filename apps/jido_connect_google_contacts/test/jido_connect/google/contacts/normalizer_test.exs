defmodule Jido.Connect.Google.Contacts.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Contacts.{Email, Group, Normalizer, Organization, Person, Phone}

  test "normalizes People API person payloads" do
    assert {:ok, %Person{} = person} =
             Normalizer.person(%{
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
                 %{
                   "value" => "ada@example.com",
                   "type" => "work",
                   "metadata" => %{"primary" => true}
                 }
               ],
               "phoneNumbers" => [
                 %{"value" => "+1 555 0100", "canonicalForm" => "+15550100", "type" => "mobile"}
               ],
               "organizations" => [
                 %{
                   "name" => "Analytical Engines",
                   "title" => "Programmer",
                   "department" => "Research",
                   "current" => true
                 }
               ],
               "memberships" => [%{"contactGroupMembership" => %{"contactGroupId" => "friends"}}],
               "photos" => [%{"url" => "https://example.com/photo"}],
               "metadata" => %{"sources" => [%{"type" => "CONTACT"}]}
             })

    assert person.resource_name == "people/c123"
    assert person.person_id == "c123"
    assert person.display_name == "Ada Lovelace"
    assert person.given_name == "Ada"
    assert [%Email{value: "ada@example.com", primary?: true}] = person.email_addresses
    assert [%Phone{canonical_form: "+15550100"}] = person.phone_numbers
    assert [%Organization{name: "Analytical Engines", current?: true}] = person.organizations
    assert [%{"contactGroupMembership" => %{"contactGroupId" => "friends"}}] = person.memberships
  end

  test "returns errors for malformed nested contact details" do
    assert {:error, _error} =
             Normalizer.person(%{
               "resourceName" => "people/c123",
               "emailAddresses" => [%{"type" => "work"}]
             })
  end

  test "normalizes nil contact detail lists as empty lists" do
    assert {:ok, %Person{} = person} =
             Normalizer.person(%{
               "resourceName" => "people/c123",
               "emailAddresses" => nil,
               "phoneNumbers" => nil,
               "organizations" => nil
             })

    assert person.email_addresses == []
    assert person.phone_numbers == []
    assert person.organizations == []
  end

  test "normalizes standalone contact detail payloads" do
    assert {:ok, %Email{value: "ada@example.com"}} =
             Normalizer.email(%{"value" => "ada@example.com"})

    assert {:ok, %Phone{value: "+1 555 0100"}} =
             Normalizer.phone(%{"value" => "+1 555 0100"})

    assert {:ok, %Organization{name: "Analytical Engines"}} =
             Normalizer.organization(%{"name" => "Analytical Engines"})
  end

  test "normalizes contact group payloads" do
    assert {:ok, %Group{} = group} =
             Normalizer.group(%{
               "resourceName" => "contactGroups/friends",
               "etag" => "etag123",
               "name" => "Friends",
               "formattedName" => "Friends",
               "groupType" => "USER_CONTACT_GROUP",
               "memberCount" => 2,
               "memberResourceNames" => ["people/c123", "people/c456"],
               "clientData" => [%{"key" => "source", "value" => "jido"}],
               "metadata" => %{"deleted" => false}
             })

    assert group.group_id == "friends"
    assert group.member_count == 2
    assert group.member_resource_names == ["people/c123", "people/c456"]
    assert group.client_data == [%{"key" => "source", "value" => "jido"}]
  end

  test "rejects non-map contact detail payloads" do
    assert {:error, :invalid_person} = Normalizer.person([])
    assert {:error, :invalid_email} = Normalizer.email([])
    assert {:error, :invalid_phone} = Normalizer.phone([])
    assert {:error, :invalid_organization} = Normalizer.organization([])
    assert {:error, :invalid_group} = Normalizer.group([])
  end
end
