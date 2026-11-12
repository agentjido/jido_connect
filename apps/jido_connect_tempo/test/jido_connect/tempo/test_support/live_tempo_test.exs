defmodule Jido.Connect.Tempo.TestSupport.LiveTempoTest do
  use ExUnit.Case, async: true

  # The booking lookup recordings pass Tempo's responses through
  # `LiveTempo.site_data/2`, which leaves out or neutralizes what the
  # shared test site returns besides the test data. The other users' data
  # here is made up: two attributes and an attribute value shaped like the
  # recorded ones, and the recorded links with a fifth of an account
  # outside the test data.

  alias Jido.Connect.Tempo.{Fixture, WorkAttribute}
  alias Jido.Connect.Tempo.TestSupport.LiveTempo

  @keys ["_JclPhase_", "_JclNote_"]
  @self "https://api.tempo.io/4/work-attributes/"

  describe "site_data/2 on a work attribute page" do
    test "another attribute keeps Tempo's structure with neutral key, name, stored values and labels" do
      phase = recorded_attribute("_JclPhase_")

      list = %{
        "key" => "_TeamPhase_",
        "name" => "Team phase",
        "type" => "STATIC_LIST",
        "required" => true,
        "self" => @self <> "_TeamPhase_",
        "values" => ["a1", "b2"],
        "names" => %{"a1" => "Team alpha", "b2" => "Team beta"}
      }

      note = %{
        "key" => "_TeamNote_",
        "name" => "Team note",
        "type" => "INPUT_FIELD",
        "required" => false,
        "self" => @self <> "_TeamNote_",
        "colour" => "Team blue"
      }

      body = %{
        "metadata" => %{"count" => 3, "limit" => 50, "offset" => 0},
        "results" => [list, phase, note],
        "self" => "https://api.tempo.io/4/work-attributes?offset=0&limit=50"
      }

      assert %{"results" => [neutral_list, ^phase, neutral_note]} =
               recorded = LiveTempo.site_data(%{}, @keys).("/4/work-attributes", body)

      assert Map.delete(recorded, "results") == Map.delete(body, "results")

      assert neutral_list == %{
               "key" => "_Other1_",
               "name" => "Other attribute 1",
               "type" => "STATIC_LIST",
               "required" => true,
               "self" => @self <> "_Other1_",
               "values" => ["other-1-1", "other-1-2"],
               "names" => %{"other-1-1" => "Other choice 1", "other-1-2" => "Other choice 2"}
             }

      # A field outside Tempo's schema is left out.
      assert neutral_note == %{
               "key" => "_Other2_",
               "name" => "Other attribute 2",
               "type" => "INPUT_FIELD",
               "required" => false,
               "self" => @self <> "_Other2_"
             }

      assert {:ok, %WorkAttribute{values: [%{value: "other-1-1", label: "Other choice 1"}, _]}} =
               WorkAttribute.normalize(neutral_list)

      refute inspect(recorded) =~ "Team"
    end

    test "a choice list that is not a list becomes nil" do
      list = %{
        "key" => "_TeamPhase_",
        "name" => "Team phase",
        "type" => "STATIC_LIST",
        "required" => false,
        "values" => "Team alpha",
        "names" => nil
      }

      assert %{"results" => [neutral]} =
               LiveTempo.site_data(%{}, @keys).("/4/work-attributes", %{"results" => [list]})

      assert neutral == %{
               "key" => "_Other1_",
               "name" => "Other attribute 1",
               "type" => "STATIC_LIST",
               "required" => false,
               "values" => nil,
               "names" => nil
             }
    end
  end

  describe "site_data/2 on accounts and worklogs" do
    test "links and reads of other accounts are left out, the count follows" do
      links = Fixture.recorded!("accounts_for_project")["body"]

      other =
        links["results"]
        |> List.last()
        |> put_in(["account", "self"], "https://api.tempo.io/4/accounts/77")

      body = %{links | "results" => links["results"] ++ [other]}
      test_accounts = Map.new(["26", "27", "28", "29"], &{&1, %{}})
      transform = LiveTempo.site_data(test_accounts, @keys)

      assert %{"results" => kept, "metadata" => %{"count" => 4}} =
               transform.("/4/account-links/project/10882", body)

      assert kept == links["results"]

      details = Fixture.recorded!("accounts_for_project.2")["body"]
      assert transform.("/4/accounts/26", details) == details
      assert transform.("/4/accounts/77", details) == :skip
    end

    test "worklog values of other attributes are left out" do
      page = Fixture.recorded!("work_attribute_values")["body"]

      body =
        update_in(page, ["results"], fn [first | rest] ->
          [
            update_in(
              first,
              ["attributes", "values"],
              &(&1 ++ [%{"key" => "_Team_", "value" => "Team"}])
            )
            | rest
          ]
        end)

      recorded =
        LiveTempo.site_data(%{}, @keys ++ ["_JclBillable_", "_JclHours_", "_JclAccount_"])

      assert recorded.("/4/worklogs/user/account-1", body) == page
    end
  end

  defp recorded_attribute(key) do
    Enum.find(
      Fixture.recorded!("work_attributes_optional")["body"]["results"],
      &(&1["key"] == key)
    )
  end
end
