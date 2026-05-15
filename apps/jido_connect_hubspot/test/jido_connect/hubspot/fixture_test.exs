defmodule Jido.Connect.HubSpot.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Normalizer

  describe "contact fixtures" do
    test "normalizes common contact fixture" do
      payload = fixture!("contact_common.json")

      assert {:ok, contact} = Normalizer.contact(payload)
      assert contact.contact_id == "501"
      assert contact.email == "bella@example.com"
      assert contact.first_name == "Bella"
      assert contact.last_name == "Martinez"
      assert contact.phone == "+1-555-0101"
      assert contact.company == "Acme Corp"
      assert contact.job_title == "Product Manager"
      assert contact.lifecycle_stage == "customer"
      refute contact.archived?
    end
  end

  describe "company fixtures" do
    test "normalizes common company fixture" do
      payload = fixture!("company_common.json")

      assert {:ok, company} = Normalizer.company(payload)
      assert company.company_id == "201"
      assert company.name == "Acme Corp"
      assert company.domain == "acme.example.com"
      assert company.industry == "Technology"
      assert company.number_of_employees == 250
      assert company.annual_revenue == 50_000_000
    end
  end

  describe "deal fixtures" do
    test "normalizes common deal fixture" do
      payload = fixture!("deal_common.json")

      assert {:ok, deal} = Normalizer.deal(payload)
      assert deal.deal_id == "301"
      assert deal.deal_name == "Acme Enterprise License"
      assert deal.amount == 120_000
      assert deal.deal_stage == "contractsent"
      assert deal.pipeline == "default"
      assert deal.deal_currency == "USD"
      assert deal.owner_id == "401"
      assert deal.deal_type == "newbusiness"
    end
  end

  describe "note fixtures" do
    test "normalizes common note fixture with associations" do
      payload = fixture!("note_common.json")

      assert {:ok, note} = Normalizer.note(payload)
      assert note.note_id == "601"
      assert note.body == "Had a great discovery call. Follow up next week with pricing."
      assert note.owner_id == "401"
      assert "501" in note.contact_ids
      assert "201" in note.company_ids
      assert "301" in note.deal_ids
      assert note.ticket_ids == []
    end
  end

  describe "owner fixtures" do
    test "normalizes common owner fixture" do
      payload = fixture!("owner_common.json")

      assert {:ok, owner} = Normalizer.owner(payload)
      assert owner.owner_id == "401"
      assert owner.email == "alice@example.com"
      assert owner.first_name == "Alice"
      assert owner.last_name == "Nakamura"
      assert owner.user_id == "12345"
      assert owner.team_id == "90"
      refute owner.archived?
    end
  end

  describe "pipeline fixtures" do
    test "normalizes common pipeline fixture with stages" do
      payload = fixture!("pipeline_common.json")

      assert {:ok, pipeline} = Normalizer.pipeline(payload)
      assert pipeline.pipeline_id == "default"
      assert pipeline.label == "Sales Pipeline"

      stage_ids = Enum.map(pipeline.stages, & &1.stage_id)
      assert "appointmentscheduled" in stage_ids
      assert "contractsent" in stage_ids
      assert "closedwon" in stage_ids

      sent = Enum.find(pipeline.stages, &(&1.stage_id == "contractsent"))
      assert sent.label == "Contract Sent"
      assert sent.probability == 80

      won = Enum.find(pipeline.stages, &(&1.stage_id == "closedwon"))
      assert won.probability == 100
    end
  end

  describe "pagination fixtures" do
    test "normalizes common pagination fixture" do
      payload = fixture!("pagination_common.json")

      assert {:ok, page} = Normalizer.pagination(payload)
      assert page.after == "501"
      assert page.total == 142
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "test", "fixtures", "hubspot", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
