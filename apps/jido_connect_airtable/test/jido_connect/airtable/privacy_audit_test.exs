defmodule Jido.Connect.Airtable.PrivacyAuditTest do
  @moduledoc """
  Privacy classification audit for every Airtable action.

  Each operation is reviewed for data classification, risk level, and
  confirmation requirement. When new actions are added, this test must be
  updated to keep the audit current.
  """
  use ExUnit.Case, async: true

  alias Jido.Connect.Airtable
  alias Jido.Connect.Taxonomy

  test "classifies every Airtable action privacy boundary" do
    spec = Airtable.integration()
    actions_by_id = Map.new(spec.actions, &{&1.id, &1})

    expected =
      Map.new(
        [
          # Read-only base operations
          action("airtable.bases.list", :workspace_metadata, :read, :none,
            text_includes: ["base"]
          ),
          action("airtable.bases.get", :workspace_metadata, :read, :none,
            text_includes: ["base"]
          ),
          action("airtable.tables.list", :workspace_metadata, :read, :none,
            text_includes: ["table"]
          ),
          # Read-only record operations
          action("airtable.records.list", :workspace_content, :read, :none,
            text_includes: ["record"]
          ),
          action("airtable.records.get", :workspace_content, :read, :none,
            text_includes: ["record"]
          ),
          # Single-record write operations
          action("airtable.records.create", :workspace_content, :write, :required_for_ai,
            text_includes: ["record", "create"]
          ),
          action("airtable.records.update", :workspace_content, :write, :required_for_ai,
            text_includes: ["record", "update"]
          ),
          action("airtable.records.delete", :workspace_content, :destructive, :required_for_ai,
            text_includes: ["record", "delete"]
          ),
          # Batch write operations
          action("airtable.records.batch_create", :workspace_content, :write, :required_for_ai,
            text_includes: ["record", "create"]
          ),
          action("airtable.records.batch_update", :workspace_content, :write, :required_for_ai,
            text_includes: ["record", "update"]
          ),
          action(
            "airtable.records.batch_delete",
            :workspace_content,
            :destructive,
            :required_for_ai,
            text_includes: ["record", "delete"]
          )
        ],
        fn row -> {row.id, row} end
      )

    # Every declared action must have a row
    assert MapSet.new(Map.keys(actions_by_id)) == MapSet.new(Map.keys(expected)),
           "Missing audit rows for: #{MapSet.difference(MapSet.new(Map.keys(actions_by_id)), MapSet.new(Map.keys(expected))) |> MapSet.to_list() |> Enum.join(", ")}"

    for {id, row} <- expected do
      action = Map.fetch!(actions_by_id, id)

      assert action.data_classification == row.classification,
             "#{id}: expected classification #{inspect(row.classification)}, got #{inspect(action.data_classification)}"

      assert action.risk == row.risk,
             "#{id}: expected risk #{inspect(row.risk)}, got #{inspect(action.risk)}"

      assert action.confirmation == row.confirmation,
             "#{id}: expected confirmation #{inspect(row.confirmation)}, got #{inspect(action.confirmation)}"

      assert_text_includes(action, Map.get(row, :text_includes, []))
    end
  end

  test "every data classification is a known taxonomy value" do
    spec = Airtable.integration()

    for action <- spec.actions do
      assert Taxonomy.known_data_classification?(action.data_classification),
             "#{action.id}: unknown classification #{inspect(action.data_classification)}"
    end
  end

  test "every risk and confirmation is a known taxonomy value" do
    spec = Airtable.integration()

    for action <- spec.actions do
      assert Taxonomy.known_risk?(action.risk),
             "#{action.id}: unknown risk #{inspect(action.risk)}"

      assert Taxonomy.known_confirmation?(action.confirmation),
             "#{action.id}: unknown confirmation #{inspect(action.confirmation)}"
    end
  end

  defp action(id, classification, risk, confirmation, opts) do
    %{
      id: id,
      classification: classification,
      risk: risk,
      confirmation: confirmation,
      text_includes: Keyword.get(opts, :text_includes, [])
    }
  end

  defp assert_text_includes(_operation, []), do: :ok

  defp assert_text_includes(operation, expected_fragments) do
    text =
      [operation.id, operation.label, Map.get(operation, :description)]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")
      |> String.downcase()

    for fragment <- expected_fragments do
      assert text =~ String.downcase(fragment),
             "#{operation.id}: expected text to include #{inspect(fragment)}"
    end
  end
end
