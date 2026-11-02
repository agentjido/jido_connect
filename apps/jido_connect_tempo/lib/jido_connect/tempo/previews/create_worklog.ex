defmodule Jido.Connect.Tempo.Previews.CreateWorklog do
  @moduledoc false

  # Pure: no request. It checks the input with the rule of the handler and
  # the client, so prepare/4 already refuses a worklog that commit/4 would
  # refuse, and shows the booking without the description text or the
  # attribute values. The author is checked against the connection's
  # subject.account_id when the connection has one; without it, commit/4
  # fails on the connection contract.

  @behaviour Jido.Connect.ActionPreview

  alias Jido.Connect.Data
  alias Jido.Connect.Tempo.Input.NewWorklog

  @impl true
  def preview(input, %{connection: connection}) do
    with {:ok, worklog} <- NewWorklog.parse(input),
         {:ok, worklog} <- check_author(worklog, connection) do
      {:ok,
       %{
         operation: "create",
         issue_id: worklog.issue_id,
         start_date: worklog.start_date,
         start_time: Map.get(worklog, :start_time),
         time_spent_seconds: worklog.time_spent_seconds,
         billable_seconds: Map.get(worklog, :billable_seconds),
         description_bytes: description_bytes(worklog),
         attribute_count: worklog |> Map.get(:attributes, []) |> length()
       }}
    end
  end

  defp check_author(worklog, connection) do
    case Data.get(Data.get(connection, :subject) || %{}, :account_id) do
      account_id when is_binary(account_id) ->
        NewWorklog.check_author(worklog, account_id, Data.get(connection, :id))

      _missing ->
        {:ok, worklog}
    end
  end

  defp description_bytes(%{description: description}), do: byte_size(description)
  defp description_bytes(_worklog), do: nil
end
