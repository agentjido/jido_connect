defmodule Jido.Connect.Jira.Client.Normalizer.ExpandedTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Jira.Client.Normalizer.{Board, Filter, Plan, Value}

  test "value helpers reject malformed provider values" do
    assert Value.id(:bad) == :error
    assert Value.required_string(nil) == :error
    assert Value.optional_string("value") == {:ok, "value"}
    assert Value.optional_map([]) == :error
    assert Value.optional_map_list([%{}, :bad]) == :error
    assert Value.optional_map_list(:bad) == :error
    assert Value.boolean(1) == :error
    assert Value.optional_boolean(nil) == {:ok, nil}
    assert Value.non_negative(-1) == :error
    assert Value.optional_non_negative(nil) == {:ok, nil}
    assert Value.positive(0) == :error
    assert Value.optional_cursor(nil) == {:ok, nil}
    assert Value.optional_cursor("") == {:ok, nil}
    assert Value.https_url(nil) == :error
  end

  test "board normalizer accepts provider location variants and rejects malformed items" do
    assert Board.list(:bad, []) == :error
    assert Board.one(:bad) == :error

    assert {:ok, %{location: %{type: "user", project: nil}}} =
             Board.one(board(%{type: "user"}))

    assert {:ok, %{location: %{type: "project", project: "DOC"}}} =
             Board.one(board(%{type: "project", projectKey: "DOC"}))

    for location <- [
          %{projectKey: "DOC"},
          %{projectName: "Documentation"},
          %{userAccountId: "account-1"}
        ] do
      assert {:ok, %{location: location_result}} = Board.one(board(location))
      assert location_result.type in ["project", "user"]
    end

    assert Board.one(board(%{type: "unknown"})) == :error
    assert Board.one(board("bad")) == :error
    assert Board.one(board(%{})) == :error
    assert Board.list(%{values: [board(%{type: "unknown"})]}, offset: 0, limit: 1) == :error
  end

  test "filter normalizer handles optional fields and rejects malformed nested data" do
    assert Filter.list(:bad, []) == :error
    assert Filter.one(:bad) == :error
    assert Filter.columns(:bad, 1) == :error
    assert Filter.permissions(:bad, 1, "private") == :error
    assert Filter.permission_ids(:bad) == :error
    assert Filter.project_id(:bad) == :error

    assert {:ok,
            %{
              description: nil,
              owner: nil,
              share_count: 0,
              url: "https://example.atlassian.net/issues/?filter=10000"
            }} = Filter.one(filter())

    assert Filter.one(Map.put(filter(), :description, 1)) == :error
    assert Filter.one(Map.put(filter(), :owner, "bad")) == :error
    assert Filter.one(Map.put(filter(), :sharePermissions, "bad")) == :error
    assert Filter.columns(["bad"], 1) == :error
    assert Filter.permissions(["bad"], 1, "private") == :error
    assert Filter.permission_ids(["bad"]) == :error

    assert Filter.permissions(
             [%{id: 1, type: "project", project: "bad"}],
             1,
             "projects"
           ) == :error

    assert Filter.permissions([%{id: 1, type: "group", group: "bad"}], 1, "groups") ==
             :error

    assert {:ok, %{permissions: [%{group: %{id: "group-1", name: "Team"}}]}} =
             Filter.permissions(
               [
                 %{
                   id: 1,
                   type: "group",
                   group: %{groupId: "group-1", name: "Team"}
                 }
               ],
               1,
               "groups"
             )
  end

  test "plan normalizer rejects malformed pages and nested issue sources" do
    assert Plan.list(:bad, []) == :error
    assert Plan.one(:bad) == :error

    assert {:ok, %{scenario_id: "2", issue_sources: []}} =
             Plan.one(Map.put(plan(), :scenarioId, 2))

    assert Plan.one(Map.put(plan(), :issueSources, "bad")) == :error
    assert Plan.one(Map.put(plan(), :issueSources, [%{type: "Project", value: "bad"}])) == :error
    assert Plan.list(%{values: [:bad]}, limit: 1) == :error
  end

  defp board(location) do
    %{
      id: 84,
      name: "Docket",
      type: "kanban",
      self: "https://example.atlassian.net/rest/agile/1.0/board/84",
      location: location
    }
  end

  defp filter do
    %{
      id: "10000",
      name: "Docket",
      jql: "project = DOC",
      favourite: false,
      self: "https://example.atlassian.net/rest/api/3/filter/10000"
    }
  end

  defp plan, do: %{id: 1237, name: "Docket", status: "Active"}
end
