defmodule Jido.Connect.Things.Handlers.Actions.CommitTodo do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Things.{Client, Runtime, Writer}
  alias Jido.Connect.Things.Writer.Plan

  def run(input, %{
        action: action,
        context: context,
        credential_lease: lease,
        execution: %{prepared_action_id: prepared_action_id}
      }) do
    runtime = Runtime.runtime_context(context)
    plan = Map.get(runtime, :provider_plan)

    with :ok <- validate_execution(action.id, prepared_action_id, plan, runtime),
         {:ok, client} <- Client.from_runtime(context, lease, runtime) do
      Writer.commit(plan, input, client, context.connection, runtime)
    end
  end

  def run(_input, _runtime) do
    {:error,
     Error.auth("Direct Things mutation is denied",
       reason: :direct_mutation_denied
     )}
  end

  defp validate_execution(action_id, prepared_action_id, %Plan{} = plan, runtime) do
    cond do
      Map.get(runtime, :commit?) != true ->
        commit_error(:commit_option_required)

      Map.get(runtime, :prepared_action_id) != prepared_action_id ->
        commit_error(:prepared_action_mismatch)

      plan.action_id != action_id ->
        commit_error(:prepared_action_mismatch)

      true ->
        :ok
    end
  end

  defp validate_execution(_action_id, _prepared_action_id, _plan, _runtime),
    do: commit_error(:prepared_plan_required)

  defp commit_error(reason) do
    {:error, Error.auth("Guarded Things prepared commit is required", reason: reason)}
  end
end
