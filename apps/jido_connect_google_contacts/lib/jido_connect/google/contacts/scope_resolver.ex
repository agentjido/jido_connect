defmodule Jido.Connect.Google.Contacts.ScopeResolver do
  @moduledoc """
  Resolves Google Contacts scopes.

  Contact reads use `contacts.readonly` by default. The broader `contacts`
  grant is accepted for reads when hosts already have it and required for
  contact or group mutations.
  """

  @contacts_scope "https://www.googleapis.com/auth/contacts"
  @contacts_readonly_scope "https://www.googleapis.com/auth/contacts.readonly"
  @contacts_other_readonly_scope "https://www.googleapis.com/auth/contacts.other.readonly"
  @directory_readonly_scope "https://www.googleapis.com/auth/directory.readonly"
  @profile_scope "profile"

  @write_actions [
    "google.contacts.person.create",
    "google.contacts.person.update",
    "google.contacts.person.delete",
    "google.contacts.person.batch_create",
    "google.contacts.person.batch_update",
    "google.contacts.person.batch_delete",
    "google.contacts.group.create",
    "google.contacts.group.update",
    "google.contacts.group.delete",
    "google.contacts.group.member.modify"
  ]
  @directory_actions [
    "google.contacts.directory.list",
    "google.contacts.directory.search"
  ]
  @other_contacts_actions [
    "google.contacts.other.list",
    "google.contacts.other.search"
  ]
  @other_contact_copy_actions [
    "google.contacts.other.copy"
  ]

  def required_scopes(operation, input, connection) do
    operation
    |> operation_id()
    |> required_for_operation(input, connection)
  end

  defp required_for_operation(operation_id, _input, _connection)
       when operation_id in @write_actions do
    [@contacts_scope]
  end

  defp required_for_operation(operation_id, _input, %{scopes: scopes})
       when operation_id in @directory_actions and is_list(scopes) do
    cond do
      @directory_readonly_scope in scopes -> [@directory_readonly_scope]
      true -> [@directory_readonly_scope]
    end
  end

  defp required_for_operation(operation_id, _input, _connection)
       when operation_id in @directory_actions do
    [@directory_readonly_scope]
  end

  defp required_for_operation(operation_id, _input, %{scopes: scopes})
       when operation_id in @other_contacts_actions and is_list(scopes) do
    cond do
      @contacts_other_readonly_scope in scopes -> [@contacts_other_readonly_scope]
      true -> [@contacts_other_readonly_scope]
    end
  end

  defp required_for_operation(operation_id, _input, _connection)
       when operation_id in @other_contacts_actions do
    [@contacts_other_readonly_scope]
  end

  defp required_for_operation(operation_id, _input, %{scopes: scopes})
       when operation_id in @other_contact_copy_actions and is_list(scopes) do
    cond do
      @contacts_scope in scopes -> [@contacts_scope]
      @contacts_other_readonly_scope in scopes -> [@contacts_other_readonly_scope]
      true -> [@contacts_other_readonly_scope]
    end
  end

  defp required_for_operation(operation_id, _input, _connection)
       when operation_id in @other_contact_copy_actions do
    [@contacts_other_readonly_scope]
  end

  defp required_for_operation("google.contacts.person.get", input, %{scopes: scopes})
       when is_list(scopes) do
    if self_profile_request?(input) do
      self_profile_scopes(scopes)
    else
      read_scopes(scopes)
    end
  end

  defp required_for_operation("google.contacts.person.get", input, _connection) do
    if self_profile_request?(input), do: [@profile_scope], else: [@contacts_readonly_scope]
  end

  defp required_for_operation(_operation_id, _input, %{scopes: scopes}) when is_list(scopes) do
    read_scopes(scopes)
  end

  defp required_for_operation(_operation_id, _input, _connection), do: [@contacts_readonly_scope]

  defp read_scopes(scopes) do
    cond do
      @contacts_scope in scopes -> [@contacts_scope]
      @contacts_readonly_scope in scopes -> [@contacts_readonly_scope]
      true -> [@contacts_readonly_scope]
    end
  end

  defp self_profile_scopes(scopes) do
    cond do
      @contacts_scope in scopes -> [@contacts_scope]
      @contacts_readonly_scope in scopes -> [@contacts_readonly_scope]
      @profile_scope in scopes -> [@profile_scope]
      true -> [@profile_scope]
    end
  end

  defp self_profile_request?(input) when is_map(input) do
    Map.get(input, :resource_name) == "people/me" or
      Map.get(input, "resource_name") == "people/me"
  end

  defp self_profile_request?(_input), do: false

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(_operation), do: nil
end
