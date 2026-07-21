defmodule Jido.Connect.Salesforce.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.{
    Account,
    Contact,
    DescribeMetadata,
    Lead,
    Normalizer,
    Opportunity,
    Pagination,
    QueryResult,
    SObjectRecord,
    Task
  }

  # ---------------------------------------------------------------------------
  # SObject Record
  # ---------------------------------------------------------------------------

  test "normalizes a generic SObject record payload" do
    assert {:ok, %SObjectRecord{} = record} =
             Normalizer.sobject_record(%{
               "attributes" => %{
                 "type" => "CustomObject__c",
                 "url" => "/services/data/v60.0/sobjects/CustomObject__c/a005g00000XYZ"
               },
               "Id" => "a005g00000XYZ",
               "Name" => "Custom Record",
               "CustomField__c" => "value"
             })

    assert record.id == "a005g00000XYZ"
    assert record.type == "CustomObject__c"
    assert record.fields["Name"] == "Custom Record"
    assert record.fields["CustomField__c"] == "value"
  end

  test "sobject_record normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.sobject_record("not a map")
    assert {:error, _error} = Normalizer.sobject_record(nil)
  end

  # ---------------------------------------------------------------------------
  # Contact
  # ---------------------------------------------------------------------------

  test "normalizes a Salesforce contact payload" do
    assert {:ok, %Contact{} = contact} =
             Normalizer.contact(%{
               "attributes" => %{"type" => "Contact"},
               "Id" => "0035g00000ABCdE1AA",
               "FirstName" => "Bella",
               "LastName" => "Martinez",
               "Email" => "bella@example.com",
               "Phone" => "+1-555-0101",
               "Title" => "Product Manager",
               "AccountId" => "0015g00000XYZaA1AA",
               "OwnerId" => "0055g00000AAA1A1AA",
               "MailingAddress" => %{"city" => "Austin", "state" => "Texas"},
               "CreatedDate" => "2026-01-15T10:30:00.000Z",
               "LastModifiedDate" => "2026-05-01T14:22:00.000Z"
             })

    assert contact.contact_id == "0035g00000ABCdE1AA"
    assert contact.first_name == "Bella"
    assert contact.last_name == "Martinez"
    assert contact.email == "bella@example.com"
    assert contact.phone == "+1-555-0101"
    assert contact.title == "Product Manager"
    assert contact.account_id == "0015g00000XYZaA1AA"
    assert contact.owner_id == "0055g00000AAA1A1AA"
    assert contact.mailing_address["city"] == "Austin"
    assert contact.created_at == "2026-01-15T10:30:00.000Z"
  end

  test "contact normalizer tolerates minimal payload" do
    assert {:ok, %Contact{} = contact} =
             Normalizer.contact(%{"Id" => "0035g00000MINIMAL"})

    assert contact.contact_id == "0035g00000MINIMAL"
    assert contact.email == nil
    assert contact.properties == %{}
  end

  test "contact normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.contact("not a map")
    assert {:error, _error} = Normalizer.contact(nil)
  end

  # ---------------------------------------------------------------------------
  # Lead
  # ---------------------------------------------------------------------------

  test "normalizes a Salesforce lead payload" do
    assert {:ok, %Lead{} = lead} =
             Normalizer.lead(%{
               "attributes" => %{"type" => "Lead"},
               "Id" => "00Q5g00000DEFgH1AA",
               "FirstName" => "Diana",
               "LastName" => "Chen",
               "Email" => "diana@example.com",
               "Phone" => "+1-555-0201",
               "Company" => "Globex Inc",
               "Title" => "CTO",
               "Status" => "Working - Contacted",
               "LeadSource" => "Web",
               "OwnerId" => "0055g00000AAA1A1AA",
               "CreatedDate" => "2026-03-01T09:00:00.000Z",
               "LastModifiedDate" => "2026-05-10T11:30:00.000Z"
             })

    assert lead.lead_id == "00Q5g00000DEFgH1AA"
    assert lead.first_name == "Diana"
    assert lead.last_name == "Chen"
    assert lead.company == "Globex Inc"
    assert lead.status == "Working - Contacted"
    assert lead.source == "Web"
  end

  test "lead normalizer tolerates minimal payload" do
    assert {:ok, %Lead{} = lead} =
             Normalizer.lead(%{"Id" => "00Q5g00000MINIMAL"})

    assert lead.lead_id == "00Q5g00000MINIMAL"
    assert lead.email == nil
    assert lead.properties == %{}
  end

  test "lead normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.lead("not a map")
  end

  # ---------------------------------------------------------------------------
  # Account
  # ---------------------------------------------------------------------------

  test "normalizes a Salesforce account payload" do
    assert {:ok, %Account{} = account} =
             Normalizer.account(%{
               "attributes" => %{"type" => "Account"},
               "Id" => "0015g00000XYZaA1AA",
               "Name" => "Acme Corp",
               "Industry" => "Technology",
               "BillingCity" => "Austin",
               "BillingState" => "Texas",
               "BillingCountry" => "United States",
               "Phone" => "+1-555-0300",
               "Website" => "https://acme.example.com",
               "Description" => "A technology company",
               "Type" => "Customer - Direct",
               "NumberOfEmployees" => 250,
               "AnnualRevenue" => 50_000_000,
               "OwnerId" => "0055g00000AAA1A1AA",
               "CreatedDate" => "2025-11-01T08:00:00.000Z",
               "LastModifiedDate" => "2026-04-10T16:45:00.000Z"
             })

    assert account.account_id == "0015g00000XYZaA1AA"
    assert account.name == "Acme Corp"
    assert account.industry == "Technology"
    assert account.billing_city == "Austin"
    assert account.billing_state == "Texas"
    assert account.number_of_employees == 250
    assert account.annual_revenue == 50_000_000
  end

  test "account normalizer handles string numeric values" do
    assert {:ok, %Account{} = account} =
             Normalizer.account(%{
               "Id" => "0015g00000STRNUM",
               "NumberOfEmployees" => "100",
               "AnnualRevenue" => "75000000.50"
             })

    assert account.number_of_employees == 100
    assert account.annual_revenue == 75_000_000
  end

  test "account normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.account("not a map")
  end

  # ---------------------------------------------------------------------------
  # Opportunity
  # ---------------------------------------------------------------------------

  test "normalizes a Salesforce opportunity payload" do
    assert {:ok, %Opportunity{} = opp} =
             Normalizer.opportunity(%{
               "attributes" => %{"type" => "Opportunity"},
               "Id" => "0065g00000GHIjK1AA",
               "Name" => "Acme Enterprise License",
               "Amount" => 120_000,
               "StageName" => "Contract Sent",
               "Probability" => 80,
               "CloseDate" => "2026-06-30",
               "Type" => "New Customer",
               "CurrencyIsoCode" => "USD",
               "OwnerId" => "0055g00000AAA1A1AA",
               "AccountId" => "0015g00000XYZaA1AA",
               "Description" => "Annual enterprise license deal",
               "CreatedDate" => "2026-03-01T09:00:00.000Z",
               "LastModifiedDate" => "2026-05-10T11:30:00.000Z"
             })

    assert opp.opportunity_id == "0065g00000GHIjK1AA"
    assert opp.name == "Acme Enterprise License"
    assert opp.amount == 120_000
    assert opp.stage == "Contract Sent"
    assert opp.probability == 80
    assert opp.close_date == "2026-06-30"
    assert opp.currency == "USD"
    assert opp.account_id == "0015g00000XYZaA1AA"
  end

  test "opportunity normalizer handles string amounts" do
    assert {:ok, %Opportunity{} = opp} =
             Normalizer.opportunity(%{
               "Id" => "0065g00000STRAMT",
               "Amount" => "45000.00"
             })

    assert opp.amount == 45_000
  end

  test "opportunity normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.opportunity("not a map")
  end

  # ---------------------------------------------------------------------------
  # Task
  # ---------------------------------------------------------------------------

  test "normalizes a Salesforce task payload" do
    assert {:ok, %Task{} = task} =
             Normalizer.task(%{
               "attributes" => %{"type" => "Task"},
               "Id" => "00T5g00000JKLmN1AA",
               "Subject" => "Follow up on proposal",
               "Status" => "In Progress",
               "Priority" => "Normal",
               "Description" => "Review the SOW and send updated pricing.",
               "WhoId" => "0035g00000ABCdE1AA",
               "WhatId" => "0065g00000GHIjK1AA",
               "OwnerId" => "0055g00000AAA1A1AA",
               "ActivityDate" => "2026-05-20",
               "CreatedDate" => "2026-05-10T11:30:00.000Z",
               "LastModifiedDate" => "2026-05-10T11:30:00.000Z"
             })

    assert task.task_id == "00T5g00000JKLmN1AA"
    assert task.subject == "Follow up on proposal"
    assert task.status == "In Progress"
    assert task.priority == "Normal"
    assert task.who_id == "0035g00000ABCdE1AA"
    assert task.what_id == "0065g00000GHIjK1AA"
    assert task.activity_date == "2026-05-20"
  end

  test "task normalizer tolerates minimal payload" do
    assert {:ok, %Task{} = task} =
             Normalizer.task(%{"Id" => "00T5g00000MINIMAL"})

    assert task.task_id == "00T5g00000MINIMAL"
    assert task.subject == nil
    assert task.properties == %{}
  end

  test "task normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.task("not a map")
  end

  # ---------------------------------------------------------------------------
  # Describe Metadata
  # ---------------------------------------------------------------------------

  test "normalizes a Salesforce SObject describe metadata payload" do
    assert {:ok, %DescribeMetadata{} = meta} =
             Normalizer.describe_metadata(%{
               "name" => "Contact",
               "label" => "Contact",
               "labelPlural" => "Contacts",
               "keyPrefix" => "003",
               "createable" => true,
               "updateable" => true,
               "deletable" => true,
               "queryable" => true,
               "searchable" => true,
               "fields" => [
                 %{"name" => "Id", "type" => "id"},
                 %{"name" => "FirstName", "type" => "string"}
               ]
             })

    assert meta.name == "Contact"
    assert meta.label == "Contact"
    assert meta.label_plural == "Contacts"
    assert meta.key_prefix == "003"
    assert meta.createable == true
    assert meta.updateable == true
    assert meta.deletable == true
    assert meta.queryable == true
    assert meta.searchable == true
    assert length(meta.fields) == 2
  end

  test "describe_metadata normalizer defaults booleans to false" do
    assert {:ok, %DescribeMetadata{} = meta} =
             Normalizer.describe_metadata(%{"name" => "Custom__c"})

    assert meta.name == "Custom__c"
    assert meta.createable == false
    assert meta.updateable == false
    assert meta.fields == []
  end

  test "describe_metadata normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.describe_metadata("not a map")
  end

  # ---------------------------------------------------------------------------
  # Query Result
  # ---------------------------------------------------------------------------

  test "normalizes a SOQL query result envelope with generic records" do
    assert {:ok, %QueryResult{} = result} =
             Normalizer.query_result(%{
               "totalSize" => 2,
               "done" => true,
               "records" => [
                 %{
                   "attributes" => %{"type" => "Contact"},
                   "Id" => "0035g00000ABCdE1AA",
                   "FirstName" => "Bella"
                 },
                 %{
                   "attributes" => %{"type" => "Contact"},
                   "Id" => "0035g00000ABCdE2BB",
                   "FirstName" => "Carlos"
                 }
               ]
             })

    assert result.total_size == 2
    assert result.done == true
    assert result.next_records_url == nil
    assert length(result.records) == 2

    [first | _] = result.records
    assert first.id == "0035g00000ABCdE1AA"
    assert first.type == "Contact"
  end

  test "query_result normalizer handles paginated results" do
    assert {:ok, %QueryResult{} = result} =
             Normalizer.query_result(%{
               "totalSize" => 2000,
               "done" => false,
               "nextRecordsUrl" => "/services/data/v60.0/query/01g5g00000QRS-2000",
               "records" => []
             })

    assert result.total_size == 2000
    assert result.done == false
    assert result.next_records_url == "/services/data/v60.0/query/01g5g00000QRS-2000"
    assert result.records == []
  end

  test "query_result normalizer accepts a custom record normalizer" do
    assert {:ok, %QueryResult{} = result} =
             Normalizer.query_result(
               %{
                 "totalSize" => 1,
                 "done" => true,
                 "records" => [
                   %{
                     "attributes" => %{"type" => "Contact"},
                     "Id" => "0035g00000ABCdE1AA",
                     "FirstName" => "Bella",
                     "LastName" => "Martinez",
                     "Email" => "bella@example.com"
                   }
                 ]
               },
               &Normalizer.contact/1
             )

    assert length(result.records) == 1
    [%Contact{} = contact] = result.records
    assert contact.contact_id == "0035g00000ABCdE1AA"
    assert contact.first_name == "Bella"
  end

  test "query_result normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.query_result("not a map")
  end

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  test "normalizes a SOQL query pagination envelope" do
    assert {:ok, %Pagination{} = page} =
             Normalizer.pagination(%{
               "totalSize" => 2000,
               "done" => false,
               "nextRecordsUrl" => "/services/data/v60.0/query/01g5g00000QRS-2000"
             })

    assert page.total_size == 2000
    assert page.done == false
    assert page.next_records_url == "/services/data/v60.0/query/01g5g00000QRS-2000"
  end

  test "pagination normalizer handles completed results" do
    assert {:ok, %Pagination{} = page} =
             Normalizer.pagination(%{
               "totalSize" => 42,
               "done" => true
             })

    assert page.total_size == 42
    assert page.done == true
    assert page.next_records_url == nil
  end

  test "pagination normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.pagination("not a map")
  end

  # ---------------------------------------------------------------------------
  # Struct constructor contracts
  # ---------------------------------------------------------------------------

  test "struct constructors enforce required keys and expose defaults" do
    # SObjectRecord
    assert {:error, _error} = SObjectRecord.new(%{})

    assert %SObjectRecord{} =
             record =
             SObjectRecord.new!(%{id: "a005g00000XYZ"})

    assert record.fields == %{}
    assert record.metadata == %{}

    # Contact
    assert {:error, _error} = Contact.new(%{})

    assert %Contact{} =
             contact =
             Contact.new!(%{contact_id: "0035g00000ABCdE1AA"})

    assert contact.properties == %{}
    assert contact.metadata == %{}

    # Lead
    assert {:error, _error} = Lead.new(%{})

    assert %Lead{} =
             lead =
             Lead.new!(%{lead_id: "00Q5g00000DEFgH1AA"})

    assert lead.properties == %{}
    assert lead.metadata == %{}

    # Account
    assert {:error, _error} = Account.new(%{})

    assert %Account{} =
             account =
             Account.new!(%{account_id: "0015g00000XYZaA1AA"})

    assert account.properties == %{}
    assert account.metadata == %{}

    # Opportunity
    assert {:error, _error} = Opportunity.new(%{})

    assert %Opportunity{} =
             opp =
             Opportunity.new!(%{opportunity_id: "0065g00000GHIjK1AA"})

    assert opp.properties == %{}
    assert opp.metadata == %{}

    # Task
    assert {:error, _error} = Task.new(%{})

    assert %Task{} =
             task =
             Task.new!(%{task_id: "00T5g00000JKLmN1AA"})

    assert task.properties == %{}
    assert task.metadata == %{}

    # DescribeMetadata
    assert {:error, _error} = DescribeMetadata.new(%{})

    assert %DescribeMetadata{} =
             meta =
             DescribeMetadata.new!(%{name: "Contact"})

    assert meta.createable == false
    assert meta.fields == []
    assert meta.metadata == %{}

    # QueryResult
    assert %QueryResult{} =
             qr =
             QueryResult.new!(%{})

    assert qr.done == true
    assert qr.records == []
    assert qr.metadata == %{}

    # Pagination
    assert %Pagination{} =
             page =
             Pagination.new!(%{})

    assert page.done == true
    assert page.metadata == %{}
  end

  test "struct modules expose schema/0" do
    for module <- [
          SObjectRecord,
          Contact,
          Lead,
          Account,
          Opportunity,
          Task,
          DescribeMetadata,
          QueryResult,
          Pagination
        ] do
      assert {:module, ^module} = Code.ensure_loaded(module)
      assert function_exported?(module, :schema, 0)
      assert module.schema()
    end
  end
end
