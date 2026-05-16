defmodule Jido.Connect.Salesforce.Normalizer do
  @moduledoc "Normalizes Salesforce REST API payloads into stable package structs."

  alias Jido.Connect.Data

  alias Jido.Connect.Salesforce.{
    Account,
    Contact,
    DescribeMetadata,
    Lead,
    Opportunity,
    Pagination,
    QueryResult,
    SObjectRecord,
    Task
  }

  # ---------------------------------------------------------------------------
  # SObject Record (generic)
  # ---------------------------------------------------------------------------

  @doc "Normalizes a generic Salesforce SObject record payload."
  @spec sobject_record(map()) :: {:ok, SObjectRecord.t()} | {:error, term()}
  def sobject_record(payload) when is_map(payload) do
    attrs = Data.get(payload, "attributes", %{}) || %{}
    type = Data.get(attrs, "type")

    excluded = ~w(Id attributes)
    fields = Map.drop(payload, excluded)

    %{
      id: Data.get(payload, "Id"),
      type: type,
      attributes: attrs,
      fields: fields
    }
    |> Data.compact()
    |> SObjectRecord.new()
  end

  def sobject_record(_payload), do: {:error, :invalid_sobject_payload}

  # ---------------------------------------------------------------------------
  # Contact
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Salesforce contact payload."
  @spec contact(map()) :: {:ok, Contact.t()} | {:error, term()}
  def contact(payload) when is_map(payload) do
    excluded =
      ~w(Id FirstName LastName Email Phone Title AccountId OwnerId MailingAddress CreatedDate LastModifiedDate attributes)

    extra = Map.drop(payload, excluded)

    %{
      contact_id: Data.get(payload, "Id"),
      first_name: Data.get(payload, "FirstName"),
      last_name: Data.get(payload, "LastName"),
      email: Data.get(payload, "Email"),
      phone: Data.get(payload, "Phone"),
      title: Data.get(payload, "Title"),
      account_id: Data.get(payload, "AccountId"),
      owner_id: Data.get(payload, "OwnerId"),
      mailing_address: Data.get(payload, "MailingAddress"),
      created_at: Data.get(payload, "CreatedDate"),
      updated_at: Data.get(payload, "LastModifiedDate"),
      attributes: Data.get(payload, "attributes"),
      properties: extra
    }
    |> Data.compact()
    |> Contact.new()
  end

  def contact(_payload), do: {:error, :invalid_contact_payload}

  # ---------------------------------------------------------------------------
  # Lead
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Salesforce lead payload."
  @spec lead(map()) :: {:ok, Lead.t()} | {:error, term()}
  def lead(payload) when is_map(payload) do
    excluded =
      ~w(Id FirstName LastName Email Phone Company Title Status LeadSource OwnerId ConvertedContactId ConvertedAccountId CreatedDate LastModifiedDate attributes)

    extra = Map.drop(payload, excluded)

    %{
      lead_id: Data.get(payload, "Id"),
      first_name: Data.get(payload, "FirstName"),
      last_name: Data.get(payload, "LastName"),
      email: Data.get(payload, "Email"),
      phone: Data.get(payload, "Phone"),
      company: Data.get(payload, "Company"),
      title: Data.get(payload, "Title"),
      status: Data.get(payload, "Status"),
      source: Data.get(payload, "LeadSource"),
      owner_id: Data.get(payload, "OwnerId"),
      converted_contact_id: Data.get(payload, "ConvertedContactId"),
      converted_account_id: Data.get(payload, "ConvertedAccountId"),
      created_at: Data.get(payload, "CreatedDate"),
      updated_at: Data.get(payload, "LastModifiedDate"),
      attributes: Data.get(payload, "attributes"),
      properties: extra
    }
    |> Data.compact()
    |> Lead.new()
  end

  def lead(_payload), do: {:error, :invalid_lead_payload}

  # ---------------------------------------------------------------------------
  # Account
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Salesforce account payload."
  @spec account(map()) :: {:ok, Account.t()} | {:error, term()}
  def account(payload) when is_map(payload) do
    excluded =
      ~w(Id Name Industry BillingCity BillingState BillingCountry Phone Website Description Type NumberOfEmployees AnnualRevenue OwnerId CreatedDate LastModifiedDate attributes)

    extra = Map.drop(payload, excluded)

    %{
      account_id: Data.get(payload, "Id"),
      name: Data.get(payload, "Name"),
      industry: Data.get(payload, "Industry"),
      billing_city: Data.get(payload, "BillingCity"),
      billing_state: Data.get(payload, "BillingState"),
      billing_country: Data.get(payload, "BillingCountry"),
      phone: Data.get(payload, "Phone"),
      website: Data.get(payload, "Website"),
      description: Data.get(payload, "Description"),
      type: Data.get(payload, "Type"),
      number_of_employees: parse_integer(Data.get(payload, "NumberOfEmployees")),
      annual_revenue: parse_integer(Data.get(payload, "AnnualRevenue")),
      owner_id: Data.get(payload, "OwnerId"),
      created_at: Data.get(payload, "CreatedDate"),
      updated_at: Data.get(payload, "LastModifiedDate"),
      attributes: Data.get(payload, "attributes"),
      properties: extra
    }
    |> Data.compact()
    |> Account.new()
  end

  def account(_payload), do: {:error, :invalid_account_payload}

  # ---------------------------------------------------------------------------
  # Opportunity
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Salesforce opportunity payload."
  @spec opportunity(map()) :: {:ok, Opportunity.t()} | {:error, term()}
  def opportunity(payload) when is_map(payload) do
    excluded =
      ~w(Id Name Amount StageName Probability CloseDate Type CurrencyIsoCode OwnerId AccountId Description CreatedDate LastModifiedDate attributes)

    extra = Map.drop(payload, excluded)

    %{
      opportunity_id: Data.get(payload, "Id"),
      name: Data.get(payload, "Name"),
      amount: parse_integer(Data.get(payload, "Amount")),
      stage: Data.get(payload, "StageName"),
      probability: parse_integer(Data.get(payload, "Probability")),
      close_date: Data.get(payload, "CloseDate"),
      type: Data.get(payload, "Type"),
      currency: Data.get(payload, "CurrencyIsoCode"),
      owner_id: Data.get(payload, "OwnerId"),
      account_id: Data.get(payload, "AccountId"),
      description: Data.get(payload, "Description"),
      created_at: Data.get(payload, "CreatedDate"),
      updated_at: Data.get(payload, "LastModifiedDate"),
      attributes: Data.get(payload, "attributes"),
      properties: extra
    }
    |> Data.compact()
    |> Opportunity.new()
  end

  def opportunity(_payload), do: {:error, :invalid_opportunity_payload}

  # ---------------------------------------------------------------------------
  # Task
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Salesforce task payload."
  @spec task(map()) :: {:ok, Task.t()} | {:error, term()}
  def task(payload) when is_map(payload) do
    excluded =
      ~w(Id Subject Status Priority Description WhoId WhatId OwnerId ActivityDate CreatedDate LastModifiedDate attributes)

    extra = Map.drop(payload, excluded)

    %{
      task_id: Data.get(payload, "Id"),
      subject: Data.get(payload, "Subject"),
      status: Data.get(payload, "Status"),
      priority: Data.get(payload, "Priority"),
      description: Data.get(payload, "Description"),
      who_id: Data.get(payload, "WhoId"),
      what_id: Data.get(payload, "WhatId"),
      owner_id: Data.get(payload, "OwnerId"),
      activity_date: Data.get(payload, "ActivityDate"),
      created_at: Data.get(payload, "CreatedDate"),
      updated_at: Data.get(payload, "LastModifiedDate"),
      attributes: Data.get(payload, "attributes"),
      properties: extra
    }
    |> Data.compact()
    |> Task.new()
  end

  def task(_payload), do: {:error, :invalid_task_payload}

  # ---------------------------------------------------------------------------
  # Describe Metadata
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Salesforce SObject describe metadata payload."
  @spec describe_metadata(map()) :: {:ok, DescribeMetadata.t()} | {:error, term()}
  def describe_metadata(payload) when is_map(payload) do
    %{
      name: Data.get(payload, "name"),
      label: Data.get(payload, "label"),
      label_plural: Data.get(payload, "labelPlural"),
      key_prefix: Data.get(payload, "keyPrefix"),
      createable: Data.get(payload, "createable", false),
      updateable: Data.get(payload, "updateable", false),
      deletable: Data.get(payload, "deletable", false),
      queryable: Data.get(payload, "queryable", false),
      searchable: Data.get(payload, "searchable", false),
      fields: Data.get(payload, "fields", [])
    }
    |> Data.compact()
    |> DescribeMetadata.new()
  end

  def describe_metadata(_payload), do: {:error, :invalid_describe_metadata_payload}

  # ---------------------------------------------------------------------------
  # Query Result
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Salesforce SOQL query result envelope."
  @spec query_result(map(), (map() -> {:ok, struct} | {:error, term()})) ::
          {:ok, QueryResult.t()} | {:error, term()}
  def query_result(payload, normalizer \\ &sobject_record/1)

  def query_result(payload, normalizer) when is_map(payload) and is_function(normalizer, 1) do
    with {:ok, records} <-
           normalize_items(
             Data.get(payload, "records", []),
             normalizer,
             "Salesforce query result contained invalid records"
           ) do
      %{
        total_size: Data.get(payload, "totalSize"),
        done: Data.get(payload, "done", true),
        next_records_url: Data.get(payload, "nextRecordsUrl"),
        records: records
      }
      |> Data.compact()
      |> QueryResult.new()
    end
  end

  def query_result(_payload, _normalizer), do: {:error, :invalid_query_result_payload}

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Salesforce SOQL query pagination envelope."
  @spec pagination(map()) :: {:ok, Pagination.t()} | {:error, term()}
  def pagination(payload) when is_map(payload) do
    %{
      total_size: Data.get(payload, "totalSize"),
      done: Data.get(payload, "done", true),
      next_records_url: Data.get(payload, "nextRecordsUrl")
    }
    |> Data.compact()
    |> Pagination.new()
  end

  def pagination(_payload), do: {:error, :invalid_pagination_payload}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp parse_integer(nil), do: nil
  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> trunc(float)
      :error -> nil
    end
  end

  defp parse_integer(value) when is_float(value), do: trunc(value)
  defp parse_integer(_value), do: nil

  defp normalize_items(records, normalizer, message) when is_list(records) do
    records
    |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
      case normalizer.(payload) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        {:error, _error} -> {:halt, {:error, message}}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      {:error, error} -> {:error, error}
    end
  end

  defp normalize_items(_records, _normalizer, message), do: {:error, message}
end
