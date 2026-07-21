defmodule Jido.Connect.HubSpot.PrivacyAuditTest do
  @moduledoc """
  Privacy classification audit for every HubSpot action and trigger.

  Each operation is reviewed for data classification, risk level, and
  confirmation requirement. When new actions or triggers are added, this
  test must be updated to keep the audit current.
  """
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot
  alias Jido.Connect.Taxonomy

  test "classifies every HubSpot action privacy boundary" do
    spec = HubSpot.integration()
    actions_by_id = Map.new(spec.actions, &{&1.id, &1})

    expected =
      Map.new(
        [
          action("hubspot.contacts.contact.get", :personal_data, :read, :none,
            text_includes: ["contact"]
          ),
          action("hubspot.contacts.contact.list", :personal_data, :read, :none,
            text_includes: ["contact"]
          ),
          action("hubspot.contacts.contact.search", :personal_data, :read, :none,
            text_includes: ["contact"]
          ),
          action("hubspot.companies.company.get", :workspace_metadata, :read, :none,
            text_includes: ["company"]
          ),
          action("hubspot.companies.company.list", :workspace_metadata, :read, :none,
            text_includes: ["company"]
          ),
          action("hubspot.companies.company.search", :workspace_metadata, :read, :none,
            text_includes: ["company"]
          ),
          action("hubspot.deals.deal.get", :workspace_metadata, :read, :none,
            text_includes: ["deal"]
          ),
          action("hubspot.deals.deal.list", :workspace_metadata, :read, :none,
            text_includes: ["deal"]
          ),
          action("hubspot.deals.deal.search", :workspace_metadata, :read, :none,
            text_includes: ["deal"]
          ),
          action("hubspot.contacts.contact.create", :personal_data, :write, :required_for_ai,
            text_includes: ["contact"]
          ),
          action("hubspot.contacts.contact.update", :personal_data, :write, :required_for_ai,
            text_includes: ["contact"]
          ),
          action("hubspot.deals.deal.create", :workspace_metadata, :write, :required_for_ai,
            text_includes: ["deal"]
          ),
          action("hubspot.deals.deal.update", :workspace_metadata, :write, :required_for_ai,
            text_includes: ["deal"]
          ),
          action("hubspot.notes.note.create", :workspace_content, :write, :required_for_ai,
            text_includes: ["note"]
          )
        ],
        fn row -> {row.id, row} end
      )

    # Every declared action must have a row
    assert MapSet.new(Map.keys(actions_by_id)) == MapSet.new(Map.keys(expected))

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

  test "classifies every HubSpot trigger data classification" do
    spec = HubSpot.integration()
    triggers_by_id = Map.new(spec.triggers, &{&1.id, &1})

    expected =
      Map.new(
        [
          %{
            id: "hubspot.contacts.contact.changed",
            classification: :personal_data,
            text_includes: ["contact"]
          },
          %{
            id: "hubspot.contacts.contact.changed.push",
            classification: :personal_data,
            text_includes: ["contact"]
          },
          %{
            id: "hubspot.deals.deal.changed",
            classification: :workspace_metadata,
            text_includes: ["deal"]
          },
          %{
            id: "hubspot.deals.deal.changed.push",
            classification: :workspace_metadata,
            text_includes: ["deal"]
          }
        ],
        fn row -> {row.id, row} end
      )

    assert MapSet.new(Map.keys(triggers_by_id)) == MapSet.new(Map.keys(expected))

    for {id, row} <- expected do
      trigger = Map.fetch!(triggers_by_id, id)

      assert trigger.data_classification == row.classification,
             "#{id}: expected classification #{inspect(row.classification)}, got #{inspect(trigger.data_classification)}"

      assert_text_includes(trigger, Map.get(row, :text_includes, []))
    end
  end

  test "every data classification is a known taxonomy value" do
    spec = HubSpot.integration()

    for action <- spec.actions do
      assert Taxonomy.known_data_classification?(action.data_classification),
             "#{action.id}: unknown classification #{inspect(action.data_classification)}"
    end

    for trigger <- spec.triggers do
      assert Taxonomy.known_data_classification?(trigger.data_classification),
             "#{trigger.id}: unknown classification #{inspect(trigger.data_classification)}"
    end
  end

  test "every risk and confirmation is a known taxonomy value" do
    spec = HubSpot.integration()

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
