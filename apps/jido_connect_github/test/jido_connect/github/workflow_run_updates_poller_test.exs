defmodule Jido.Connect.GitHub.WorkflowRunUpdatesPollerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.GitHub.Handlers.Triggers.WorkflowRunUpdatesPoller

  defmodule Client do
    def list_workflow_runs(%{repo: repo, page: page, per_page: 1}, observer) do
      send(observer, {:requested_page, repo, page})

      case {repo, page} do
        {"org/paginated", 1} -> {:ok, %{total_count: 3, workflow_runs: [run(3, "10:03:00")]}}
        {"org/paginated", 2} -> {:ok, %{total_count: 3, workflow_runs: [run(2, "10:02:00")]}}
        {"org/paginated", 3} -> {:ok, %{total_count: 3, workflow_runs: [run(1, "09:59:00")]}}
        {"org/error", 1} -> {:ok, %{total_count: 2, workflow_runs: [run(3, "10:03:00")]}}
        {"org/error", 2} -> {:error, :page_failed}
        {"org/incomplete", 1} -> {:ok, %{total_count: 2, workflow_runs: [run(3, "10:03:00")]}}
        {"org/incomplete", 2} -> {:ok, %{total_count: 2, workflow_runs: []}}
      end
    end

    defp run(id, time), do: %{id: id, updated_at: "2026-04-29T#{time}Z"}
  end

  test "reads every workflow run page before it advances the checkpoint" do
    assert {:ok, %{signals: signals, checkpoint: "2026-04-29T10:03:00Z"}} =
             poll("org/paginated")

    assert Enum.map(signals, & &1.workflow_run_id) == [2, 3]
    assert_received {:requested_page, "org/paginated", 1}
    assert_received {:requested_page, "org/paginated", 2}
    assert_received {:requested_page, "org/paginated", 3}
  end

  test "a later page error does not produce a partial result or a new checkpoint" do
    assert {:error, :page_failed} = poll("org/error")
    assert_received {:requested_page, "org/error", 1}
    assert_received {:requested_page, "org/error", 2}
  end

  test "an empty page before the reported total fails the poll" do
    assert {:error, %{reason: :incomplete_pagination}} = poll("org/incomplete")
  end

  defp poll(repo) do
    WorkflowRunUpdatesPoller.poll(
      %{repo: repo, per_page: 1},
      %{
        credentials: %{github_client: Client, access_token: self()},
        checkpoint: "2026-04-29T10:00:00Z"
      }
    )
  end
end
