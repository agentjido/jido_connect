defmodule Jido.Connect.HubSpot.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.{
    Company,
    Contact,
    Deal,
    Note,
    Owner,
    Pagination,
    Pipeline,
    PipelineStage,
    Normalizer
  }

  # ---------------------------------------------------------------------------
  # Contact
  # ---------------------------------------------------------------------------

  test "normalizes CRM v3 contact payloads" do
    assert {:ok, %Contact{} = contact} =
             Normalizer.contact(%{
               "id" => "501",
               "properties" => %{
                 "email" => "bella@example.com",
                 "firstname" => "Bella",
                 "lastname" => "Martinez",
                 "phone" => "+1-555-0101",
                 "company" => "Acme Corp",
                 "jobtitle" => "Product Manager",
                 "lifecyclestage" => "customer"
               },
               "createdAt" => "2026-01-15T10:30:00.000Z",
               "updatedAt" => "2026-05-01T14:22:00.000Z",
               "archived" => false
             })

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

  test "contact normalizer tolerates missing properties" do
    assert {:ok, %Contact{} = contact} =
             Normalizer.contact(%{
               "id" => "502",
               "properties" => %{},
               "archived" => false
             })

    assert contact.contact_id == "502"
    assert contact.email == nil
    assert contact.properties == %{}
  end

  test "contact normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.contact("not a map")
    assert {:error, _error} = Normalizer.contact(nil)
  end

  # ---------------------------------------------------------------------------
  # Company
  # ---------------------------------------------------------------------------

  test "normalizes CRM v3 company payloads" do
    assert {:ok, %Company{} = company} =
             Normalizer.company(%{
               "id" => "201",
               "properties" => %{
                 "name" => "Acme Corp",
                 "domain" => "acme.example.com",
                 "industry" => "Technology",
                 "city" => "Austin",
                 "state" => "Texas",
                 "country" => "United States",
                 "numberofemployees" => "250",
                 "annualrevenue" => "50000000"
               },
               "createdAt" => "2025-11-01T08:00:00.000Z",
               "updatedAt" => "2026-04-10T16:45:00.000Z",
               "archived" => false
             })

    assert company.company_id == "201"
    assert company.name == "Acme Corp"
    assert company.domain == "acme.example.com"
    assert company.industry == "Technology"
    assert company.number_of_employees == 250
    assert company.annual_revenue == 50_000_000
  end

  test "company normalizer handles missing numeric properties" do
    assert {:ok, %Company{} = company} =
             Normalizer.company(%{
               "id" => "202",
               "properties" => %{}
             })

    assert company.company_id == "202"
    assert company.number_of_employees == nil
    assert company.annual_revenue == nil
  end

  test "company normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.company("not a map")
  end

  # ---------------------------------------------------------------------------
  # Deal
  # ---------------------------------------------------------------------------

  test "normalizes CRM v3 deal payloads" do
    assert {:ok, %Deal{} = deal} =
             Normalizer.deal(%{
               "id" => "301",
               "properties" => %{
                 "dealname" => "Acme Enterprise License",
                 "amount" => "120000",
                 "dealstage" => "contractsent",
                 "pipeline" => "default",
                 "closedate" => "2026-06-30T23:59:59.000Z",
                 "deal_currency_code" => "USD",
                 "hubspot_owner_id" => "401",
                 "dealtype" => "newbusiness"
               },
               "createdAt" => "2026-03-01T09:00:00.000Z",
               "updatedAt" => "2026-05-10T11:30:00.000Z",
               "archived" => false
             })

    assert deal.deal_id == "301"
    assert deal.deal_name == "Acme Enterprise License"
    assert deal.amount == 120_000
    assert deal.deal_stage == "contractsent"
    assert deal.pipeline == "default"
    assert deal.deal_currency == "USD"
    assert deal.owner_id == "401"
  end

  test "deal normalizer resolves pipeline stage from opts" do
    stage = %PipelineStage{
      stage_id: "contractsent",
      label: "Contract Sent",
      probability: 80,
      archived?: false
    }

    assert {:ok, %Deal{} = deal} =
             Normalizer.deal(
               %{
                 "id" => "301",
                 "properties" => %{
                   "dealstage" => "contractsent",
                   "pipeline" => "default"
                 }
               },
               stages: %{{"default", "contractsent"} => stage}
             )

    assert deal.pipeline_stage == stage
  end

  test "deal normalizer handles missing pipeline stage gracefully" do
    assert {:ok, %Deal{} = deal} =
             Normalizer.deal(%{
               "id" => "302",
               "properties" => %{}
             })

    assert deal.deal_id == "302"
    assert deal.pipeline_stage == nil
  end

  test "deal normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.deal("not a map")
  end

  # ---------------------------------------------------------------------------
  # Note
  # ---------------------------------------------------------------------------

  test "normalizes CRM v3 note payloads with associations" do
    assert {:ok, %Note{} = note} =
             Normalizer.note(%{
               "id" => "601",
               "properties" => %{
                 "hs_note_body" => "Follow up next week.",
                 "hubspot_owner_id" => "401",
                 "hs_engagement_type" => "NOTE"
               },
               "createdAt" => "2026-05-01T15:00:00.000Z",
               "updatedAt" => "2026-05-01T15:00:00.000Z",
               "archived" => false,
               "associations" => %{
                 "contacts" => %{"results" => [%{"id" => "501"}]},
                 "companies" => %{"results" => [%{"id" => "201"}]},
                 "deals" => %{"results" => [%{"id" => "301"}]}
               }
             })

    assert note.note_id == "601"
    assert note.body == "Follow up next week."
    assert note.owner_id == "401"
    assert note.contact_ids == ["501"]
    assert note.company_ids == ["201"]
    assert note.deal_ids == ["301"]
    assert note.ticket_ids == []
  end

  test "note normalizer handles missing associations" do
    assert {:ok, %Note{} = note} =
             Normalizer.note(%{
               "id" => "602",
               "properties" => %{}
             })

    assert note.note_id == "602"
    assert note.contact_ids == []
    assert note.company_ids == []
    assert note.deal_ids == []
    assert note.ticket_ids == []
  end

  test "note normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.note("not a map")
  end

  # ---------------------------------------------------------------------------
  # Owner
  # ---------------------------------------------------------------------------

  test "normalizes CRM v3 owner payloads" do
    assert {:ok, %Owner{} = owner} =
             Normalizer.owner(%{
               "id" => "401",
               "email" => "alice@example.com",
               "firstName" => "Alice",
               "lastName" => "Nakamura",
               "userId" => "12345",
               "teamId" => "90",
               "archived" => false,
               "createdAt" => "2025-06-01T12:00:00.000Z",
               "updatedAt" => "2026-01-10T09:00:00.000Z"
             })

    assert owner.owner_id == "401"
    assert owner.email == "alice@example.com"
    assert owner.first_name == "Alice"
    assert owner.last_name == "Nakamura"
    assert owner.user_id == "12345"
    assert owner.team_id == "90"
    refute owner.archived?
  end

  test "owner normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.owner("not a map")
  end

  # ---------------------------------------------------------------------------
  # Pipeline
  # ---------------------------------------------------------------------------

  test "normalizes CRM v3 pipeline payloads with stages" do
    assert {:ok, %Pipeline{} = pipeline} =
             Normalizer.pipeline(%{
               "id" => "default",
               "label" => "Sales Pipeline",
               "displayOrder" => 0,
               "archived" => false,
               "createdAt" => "2025-01-01T00:00:00.000Z",
               "updatedAt" => "2026-05-01T00:00:00.000Z",
               "stages" => [
                 %{
                   "id" => "appointmentscheduled",
                   "label" => "Appointment Scheduled",
                   "displayOrder" => 0,
                   "probability" => 20,
                   "archived" => false
                 },
                 %{
                   "id" => "closedwon",
                   "label" => "Closed Won",
                   "displayOrder" => 6,
                   "probability" => 100,
                   "archived" => false
                 }
               ]
             })

    assert pipeline.pipeline_id == "default"
    assert pipeline.label == "Sales Pipeline"
    assert pipeline.display_order == 0
    assert length(pipeline.stages) == 2

    [
      %PipelineStage{stage_id: "appointmentscheduled"} = first,
      %PipelineStage{stage_id: "closedwon"} = last
    ] =
      pipeline.stages

    assert first.label == "Appointment Scheduled"
    assert first.probability == 20
    assert last.label == "Closed Won"
    assert last.probability == 100
  end

  test "pipeline normalizer handles empty stages" do
    assert {:ok, %Pipeline{} = pipeline} =
             Normalizer.pipeline(%{
               "id" => "empty",
               "label" => "Empty Pipeline",
               "stages" => []
             })

    assert pipeline.pipeline_id == "empty"
    assert pipeline.stages == []
  end

  test "pipeline normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.pipeline("not a map")
  end

  # ---------------------------------------------------------------------------
  # Pipeline stage
  # ---------------------------------------------------------------------------

  test "normalizes CRM v3 pipeline stage payloads" do
    assert {:ok, %PipelineStage{} = stage} =
             Normalizer.pipeline_stage(%{
               "id" => "contractsent",
               "label" => "Contract Sent",
               "displayOrder" => 4,
               "probability" => 80,
               "archived" => false,
               "createdAt" => "2025-01-01T00:00:00.000Z",
               "updatedAt" => "2025-01-01T00:00:00.000Z"
             })

    assert stage.stage_id == "contractsent"
    assert stage.label == "Contract Sent"
    assert stage.display_order == 4
    assert stage.probability == 80
    refute stage.archived?
  end

  test "pipeline stage normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.pipeline_stage("not a map")
  end

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  test "normalizes API paging envelopes" do
    assert {:ok, %Pagination{} = page} =
             Normalizer.pagination(%{
               "paging" => %{
                 "next" => %{
                   "after" => "501",
                   "link" => "https://api.hubapi.com/crm/v3/objects/contacts?after=501"
                 }
               },
               "total" => 142
             })

    assert page.after == "501"
    assert page.link == "https://api.hubapi.com/crm/v3/objects/contacts?after=501"
    assert page.total == 142
  end

  test "pagination normalizer handles missing paging envelope" do
    assert {:ok, %Pagination{} = page} =
             Normalizer.pagination(%{})

    assert page.after == nil
    assert page.total == nil
  end

  test "pagination normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.pagination("not a map")
  end

  # ---------------------------------------------------------------------------
  # Struct constructor contracts
  # ---------------------------------------------------------------------------

  test "struct constructors expose schema defaults and enforce required keys" do
    # Contact
    assert {:error, _error} = Contact.new(%{})

    assert %Contact{} =
             contact =
             Contact.new!(%{contact_id: "501"})

    assert contact.archived? == false
    assert contact.properties == %{}
    assert contact.metadata == %{}

    # Company
    assert {:error, _error} = Company.new(%{})

    assert %Company{} =
             company =
             Company.new!(%{company_id: "201"})

    assert company.archived? == false
    assert company.properties == %{}
    assert company.metadata == %{}

    # Deal
    assert {:error, _error} = Deal.new(%{})

    assert %Deal{} =
             deal =
             Deal.new!(%{deal_id: "301"})

    assert deal.archived? == false
    assert deal.properties == %{}
    assert deal.metadata == %{}

    # Note
    assert {:error, _error} = Note.new(%{})

    assert %Note{} =
             note =
             Note.new!(%{note_id: "601"})

    assert note.archived? == false
    assert note.contact_ids == []
    assert note.company_ids == []
    assert note.deal_ids == []
    assert note.ticket_ids == []
    assert note.properties == %{}
    assert note.metadata == %{}

    # Owner
    assert {:error, _error} = Owner.new(%{})

    assert %Owner{} =
             owner =
             Owner.new!(%{owner_id: "401"})

    assert owner.archived? == false
    assert owner.metadata == %{}

    # Pipeline
    assert {:error, _error} = Pipeline.new(%{})

    assert %Pipeline{} =
             pipeline =
             Pipeline.new!(%{pipeline_id: "default"})

    assert pipeline.archived? == false
    assert pipeline.stages == []
    assert pipeline.metadata == %{}

    # PipelineStage
    assert {:error, _error} = PipelineStage.new(%{})

    assert %PipelineStage{} =
             stage =
             PipelineStage.new!(%{stage_id: "contractsent"})

    assert stage.archived? == false
    assert stage.metadata == %{}

    # Pagination
    assert %Pagination{} =
             page =
             Pagination.new!(%{})

    assert page.metadata == %{}
  end

  test "struct modules expose schema/0" do
    for module <- [Contact, Company, Deal, Note, Owner, Pipeline, PipelineStage, Pagination] do
      assert {:module, ^module} = Code.ensure_loaded(module)
      assert function_exported?(module, :schema, 0)
      assert module.schema()
    end
  end
end
