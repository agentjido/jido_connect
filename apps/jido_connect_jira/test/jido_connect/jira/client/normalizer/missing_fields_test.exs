defmodule Jido.Connect.Jira.Client.Normalizer.MissingFieldsTest do
  use ExUnit.Case, async: true

  # `missing_fields` of `Normalizer.issue/2` on recorded reads of JCL-3, an
  # issue without description, assignee and due date:
  #
  #   * `issue_context.7`: read with ten named fields, among them `duedate`
  #   * `issue_fields`: a search page with `*navigable`, all navigable fields
  #   * `issue_fields.2`: a read without `fields`, so all fields
  #
  # Jira returns the empty `duedate` as null. A copy without `duedate` stands
  # for a site whose field configuration hides the field.

  alias Jido.Connect.Jira.Client.Normalizer
  alias Jido.Connect.TestSupport.LiveSmoke

  setup do
    [navigable] = LiveSmoke.fixture!(:jira, "issue_fields")["issues"]

    %{
      payload: LiveSmoke.fixture!(:jira, "issue_context.7"),
      navigable: navigable,
      all: LiveSmoke.fixture!(:jira, "issue_fields.2")
    }
  end

  test "lists nothing when no fields were requested", %{payload: payload} do
    assert {:ok, %{missing_fields: []}} = Normalizer.issue(payload)
  end

  test "lists requested keys that the payload leaves out, in request order", %{payload: payload} do
    assert {:ok, %{missing_fields: ["parent", "customfield_10001"]}} =
             Normalizer.issue(payload,
               requested_fields: ["summary", "parent,duedate", " customfield_10001 ", "parent"]
             )
  end

  test "*navigable stands for the read fields that Jira counts as navigable", %{
    navigable: navigable
  } do
    assert {:ok, %{due_date: nil, missing_fields: []}} =
             Normalizer.issue(navigable, requested_fields: ["*navigable"])

    assert {:ok, %{due_date: nil, missing_fields: ["duedate"]}} =
             Normalizer.issue(without(navigable, ["duedate"]), requested_fields: ["*navigable"])

    # `timetracking` is not navigable, so only `*all` asks for it.
    assert {:ok, %{missing_fields: ["timetracking"]}} =
             Normalizer.issue(navigable, requested_fields: ["*all"])
  end

  test "*all stands for every read field", %{all: all} do
    assert {:ok, %{missing_fields: []}} = Normalizer.issue(all, requested_fields: ["*all"])

    assert {:ok, %{missing_fields: ["duedate"]}} =
             Normalizer.issue(without(all, ["duedate"]), requested_fields: ["*all"])
  end

  test "a list without named fields starts from all fields, as an issue read does", %{all: all} do
    # An issue read answers `fields=-description` with all fields except
    # description, and an empty `fields=` with all fields.
    assert {:ok, %{missing_fields: ["duedate"]}} =
             Normalizer.issue(without(all, ["description", "duedate"]),
               requested_fields: ["-description"]
             )

    assert {:ok, %{missing_fields: ["duedate"]}} =
             Normalizer.issue(without(all, ["duedate"]), requested_fields: [])
  end

  test "skips other selectors, excluded keys and top-level properties", %{payload: payload} do
    assert {:ok, %{missing_fields: []}} =
             Normalizer.issue(payload,
               requested_fields: ["*unknown", "key", "id", "-parent", "parent", "summary"]
             )
  end

  test "lists every requested key for a payload without a fields object", %{payload: payload} do
    assert {:ok, %{missing_fields: ["summary", "duedate"]}} =
             Normalizer.issue(Map.delete(payload, "fields"),
               requested_fields: ["summary", "duedate"]
             )
  end

  defp without(payload, keys), do: update_in(payload, ["fields"], &Map.drop(&1, keys))
end
