defmodule Jido.Connect.Jira.ExpandedActionsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Error
  alias Jido.Connect.Jira

  defmodule NoCallClient do
  end

  @new_actions %{
    "jira.board.list" => {:read, :none, []},
    "jira.board.get" => {:read, :none, []},
    "jira.board.create" => {:write, :required_for_ai, []},
    "jira.filter.list" => {:read, :none, []},
    "jira.filter.get" => {:read, :none, []},
    "jira.filter.create" => {:write, :required_for_ai, []},
    "jira.filter.update" => {:write, :required_for_ai, []},
    "jira.filter.columns.get" => {:read, :none, []},
    "jira.filter.columns.update" => {:write, :required_for_ai, []},
    "jira.filter.share.update" => {:external_write, :required_for_ai, []},
    "jira.issue.transition.list" => {:read, :none, [:project_access]},
    "jira.issue.delete" => {:destructive, :always, [:project_access]},
    "jira.plan.list" => {:read, :none, [:jira_admin_access]},
    "jira.plan.get" => {:read, :none, [:jira_admin_access]},
    "jira.plan.create" => {:write, :required_for_ai, [:jira_admin_access]},
    "jira.plan.update" => {:write, :required_for_ai, [:jira_admin_access]},
    "jira.plan.duplicate" => {:write, :required_for_ai, [:jira_admin_access]},
    "jira.plan.archive" => {:destructive, :always, [:jira_admin_access]},
    "jira.plan.trash" => {:destructive, :always, [:jira_admin_access]}
  }

  test "adds the reviewed Jira actions without changing the existing action set" do
    actions = Map.new(Jira.integration().actions, &{&1.id, &1})

    assert map_size(actions) == 29

    for {id, {risk, confirmation, required_policies}} <- @new_actions do
      assert %{risk: ^risk, confirmation: ^confirmation} = action = Map.fetch!(actions, id)
      assert Enum.all?(required_policies, &(&1 in action.policies))

      if risk in [:write, :external_write, :destructive] do
        assert is_atom(action.preview)
      end
    end
  end

  test "declares bounded paging and identifier fields" do
    actions = Map.new(Jira.integration().actions, &{&1.id, &1})

    for id <- ["jira.board.list", "jira.filter.list"] do
      fields = fields(actions[id])
      assert fields.limit.minimum == 1
      assert fields.limit.maximum == 100
      assert fields.offset.minimum == 0
    end

    fields = fields(actions["jira.plan.list"])
    assert fields.limit.minimum == 1
    assert fields.limit.maximum == 100
    assert fields.cursor.max_length == 1_000

    for id <- [
          "jira.board.get",
          "jira.filter.get",
          "jira.filter.columns.get",
          "jira.plan.get",
          "jira.plan.archive",
          "jira.plan.trash"
        ] do
      assert Enum.any?(actions[id].input, fn field ->
               field.name == :id and field.required? and field.minimum == 1
             end)
    end

    issue_delete = fields(actions["jira.issue.delete"])
    assert issue_delete.issue_key.required?
    assert issue_delete.issue_key.min_length == 1
    assert issue_delete.issue_key.max_length == 255
  end

  test "keeps destructive actions out of ordinary editor packs" do
    packs = Jira.catalog_packs()
    editor = Enum.find(packs, &(&1.id == :jira_editor))

    refute "jira.issue.delete" in editor.allowed_tools
    refute "jira.plan.archive" in editor.allowed_tools
    refute "jira.plan.trash" in editor.allowed_tools
  end

  test "runtime validation rejects out-of-range paging before the client runs" do
    runtime = Jido.Connect.Jira.TestRuntime.build(provider_client: NoCallClient)

    assert {:error, %Error.ValidationError{}} =
             Connect.invoke(Jira, "jira.board.list", %{limit: 101}, runtime_opts(runtime))

    assert {:error, %Error.ValidationError{}} =
             Connect.invoke(Jira, "jira.filter.list", %{offset: -1}, runtime_opts(runtime))

    assert {:error, %Error.ValidationError{}} =
             Connect.invoke(
               Jira,
               "jira.plan.list",
               %{cursor: String.duplicate("x", 1_001)},
               runtime_opts(runtime)
             )
  end

  test "runtime preparation keeps destructive writes gated and side-effect free" do
    runtime = Jido.Connect.Jira.TestRuntime.build(provider_client: NoCallClient)

    for {action_id, input, operation} <- [
          {"jira.issue.delete", %{issue_key: "PROJ-1"}, "delete_issue"},
          {"jira.plan.archive", %{id: 1237}, "archive_plan"},
          {"jira.plan.trash", %{id: 1237}, "trash_plan"}
        ] do
      assert {:ok, prepared} = Connect.prepare(Jira, action_id, input, runtime_opts(runtime))
      assert prepared.confirmation_required?
      assert prepared.preview["operation"] == operation
      assert prepared.preview.action_id == action_id
    end
  end

  defp fields(action), do: Map.new(action.input, &{&1.name, &1})

  defp runtime_opts(runtime) do
    lease =
      Connect.CredentialLease.from_connection!(
        runtime.context.connection,
        runtime.credentials,
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )

    [
      context: runtime.context,
      credential_lease: lease,
      provider_client: runtime.provider_client
    ]
  end
end
