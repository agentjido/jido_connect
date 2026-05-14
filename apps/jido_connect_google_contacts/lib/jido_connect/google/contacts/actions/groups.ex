defmodule Jido.Connect.Google.Contacts.Actions.Groups do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @contacts_scope "https://www.googleapis.com/auth/contacts"
  @contacts_readonly_scope "https://www.googleapis.com/auth/contacts.readonly"
  @scope_resolver Jido.Connect.Google.Contacts.ScopeResolver

  actions do
    action :get_contact_group do
      id("google.contacts.group.get")
      resource(:group)
      verb(:get)
      data_classification(:personal_data)
      label("Get contact group")
      description("Fetch a Google Contacts contact group by resource name.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.GetContactGroup)
      effect(:read)

      access do
        auth(:user)
        scopes([@contacts_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:resource_name, :string, required?: true, example: "contactGroups/friends")
        field(:max_members, :integer)
        field(:group_fields, :string)
        field(:fields, :string)
      end

      output do
        field(:group, :map)
      end
    end

    action :batch_get_contact_groups do
      id("google.contacts.group.batch_get")
      resource(:group)
      verb(:get)
      data_classification(:personal_data)
      label("Batch get contact groups")
      description("Fetch multiple Google Contacts contact groups by resource name.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.BatchGetContactGroups)
      effect(:read)

      access do
        auth(:user)
        scopes([@contacts_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:resource_names, {:array, :string}, required?: true)
        field(:max_members, :integer)
        field(:group_fields, :string)
        field(:fields, :string)
      end

      output do
        field(:groups, {:array, :map})
        field(:responses, {:array, :map})
      end
    end

    action :delete_contact_group do
      id("google.contacts.group.delete")
      resource(:group)
      verb(:delete)
      data_classification(:personal_data)
      label("Delete contact group")
      description("Delete a Google Contacts contact group.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.DeleteContactGroup)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@contacts_scope], resolver: @scope_resolver)
      end

      input do
        field(:resource_name, :string, required?: true, example: "contactGroups/friends")
        field(:delete_contacts, :boolean, default: false)
      end

      output do
        field(:result, :map)
      end
    end

    action :modify_contact_group_members do
      id("google.contacts.group.member.modify")
      resource(:group_member)
      verb(:update)
      data_classification(:personal_data)
      label("Modify contact group members")
      description("Add or remove Google Contacts people from a contact group.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.ModifyContactGroupMembers)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@contacts_scope], resolver: @scope_resolver)
      end

      input do
        field(:resource_name, :string, required?: true, example: "contactGroups/friends")
        field(:resource_names_to_add, {:array, :string}, default: [])
        field(:resource_names_to_remove, {:array, :string}, default: [])
      end

      output do
        field(:result, :map)
      end
    end
  end
end
