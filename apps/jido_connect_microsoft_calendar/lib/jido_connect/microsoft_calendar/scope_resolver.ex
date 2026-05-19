defmodule Jido.Connect.MicrosoftCalendar.ScopeResolver do
  @moduledoc """
  Resolves Microsoft Calendar scopes for dynamic least-privilege checks.

  Maps action ids to the narrowest required Microsoft Graph calendar scope,
  accepting broader already-granted scopes when the host connection includes
  them.
  """

  @calendars_read "Calendars.Read"
  @calendars_read_shared "Calendars.Read.Shared"
  @calendars_read_write "Calendars.ReadWrite"
  @calendars_read_write_shared "Calendars.ReadWrite.Shared"

  @read_actions [
    "microsoft.calendar.calendars.list",
    "microsoft.calendar.calendar.get",
    "microsoft.calendar.events.list",
    "microsoft.calendar.event.get",
    "microsoft.calendar.schedule.get",
    "microsoft.calendar.meeting_times.find"
  ]

  @write_actions [
    "microsoft.calendar.event.create",
    "microsoft.calendar.event.update",
    "microsoft.calendar.event.accept",
    "microsoft.calendar.event.decline",
    "microsoft.calendar.event.tentatively_accept"
  ]

  @destructive_actions [
    "microsoft.calendar.event.delete",
    "microsoft.calendar.event.cancel"
  ]

  @doc "Returns the required Microsoft Graph scopes for the given operation."
  @spec required_scopes(map(), map(), map()) :: [String.t()]
  def required_scopes(operation, _input, connection) do
    operation
    |> operation_id()
    |> required_for_operation(connection)
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @write_actions and is_list(scopes) do
    cond do
      @calendars_read_write in scopes -> [@calendars_read_write]
      @calendars_read_write_shared in scopes -> [@calendars_read_write_shared]
      true -> [@calendars_read_write]
    end
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @destructive_actions and is_list(scopes) do
    cond do
      @calendars_read_write in scopes -> [@calendars_read_write]
      @calendars_read_write_shared in scopes -> [@calendars_read_write_shared]
      true -> [@calendars_read_write]
    end
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @read_actions and is_list(scopes) do
    cond do
      @calendars_read in scopes -> [@calendars_read]
      @calendars_read_write in scopes -> [@calendars_read_write]
      @calendars_read_shared in scopes -> [@calendars_read_shared]
      @calendars_read_write_shared in scopes -> [@calendars_read_write_shared]
      true -> [@calendars_read]
    end
  end

  defp required_for_operation(operation_id, _connection)
       when operation_id in @write_actions,
       do: [@calendars_read_write]

  defp required_for_operation(operation_id, _connection)
       when operation_id in @destructive_actions,
       do: [@calendars_read_write]

  defp required_for_operation(_operation_id, _connection),
    do: [@calendars_read]

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(operation), do: Map.get(operation, :id)
end
