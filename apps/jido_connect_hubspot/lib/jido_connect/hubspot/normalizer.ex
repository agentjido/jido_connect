defmodule Jido.Connect.HubSpot.Normalizer do
  @moduledoc "Normalizes HubSpot CRM v3 API payloads into stable package structs."

  alias Jido.Connect.Data

  alias Jido.Connect.HubSpot.{
    Company,
    Contact,
    Deal,
    Note,
    Owner,
    Pagination,
    Pipeline,
    PipelineStage
  }

  # ---------------------------------------------------------------------------
  # Contact
  # ---------------------------------------------------------------------------

  @doc "Normalizes a HubSpot CRM v3 contact payload."
  @spec contact(map()) :: {:ok, Contact.t()} | {:error, term()}
  def contact(payload) when is_map(payload) do
    props = Data.get(payload, "properties", %{}) || %{}

    %{
      contact_id: Data.get(payload, "id"),
      email: Data.get(props, "email"),
      first_name: Data.get(props, "firstname"),
      last_name: Data.get(props, "lastname"),
      phone: Data.get(props, "phone"),
      company: Data.get(props, "company"),
      job_title: Data.get(props, "jobtitle"),
      website: Data.get(props, "website"),
      lifecycle_stage: Data.get(props, "lifecyclestage"),
      created_at: Data.get(payload, "createdAt"),
      updated_at: Data.get(payload, "updatedAt"),
      archived?: Data.get(payload, "archived", false),
      archived_at: Data.get(payload, "archivedAt"),
      properties: props,
      associations: Data.get(payload, "associations")
    }
    |> Data.compact()
    |> Contact.new()
  end

  def contact(_payload), do: {:error, :invalid_contact_payload}

  # ---------------------------------------------------------------------------
  # Company
  # ---------------------------------------------------------------------------

  @doc "Normalizes a HubSpot CRM v3 company payload."
  @spec company(map()) :: {:ok, Company.t()} | {:error, term()}
  def company(payload) when is_map(payload) do
    props = Data.get(payload, "properties", %{}) || %{}

    %{
      company_id: Data.get(payload, "id"),
      name: Data.get(props, "name"),
      domain: Data.get(props, "domain"),
      industry: Data.get(props, "industry"),
      city: Data.get(props, "city"),
      state: Data.get(props, "state"),
      country: Data.get(props, "country"),
      phone: Data.get(props, "phone"),
      website: Data.get(props, "website"),
      description: Data.get(props, "description"),
      type: Data.get(props, "type"),
      number_of_employees: parse_integer(Data.get(props, "numberofemployees")),
      annual_revenue: parse_integer(Data.get(props, "annualrevenue")),
      created_at: Data.get(payload, "createdAt"),
      updated_at: Data.get(payload, "updatedAt"),
      archived?: Data.get(payload, "archived", false),
      archived_at: Data.get(payload, "archivedAt"),
      properties: props,
      associations: Data.get(payload, "associations")
    }
    |> Data.compact()
    |> Company.new()
  end

  def company(_payload), do: {:error, :invalid_company_payload}

  # ---------------------------------------------------------------------------
  # Deal
  # ---------------------------------------------------------------------------

  @doc "Normalizes a HubSpot CRM v3 deal payload."
  @spec deal(map(), keyword()) :: {:ok, Deal.t()} | {:error, term()}
  def deal(payload, opts \\ [])

  def deal(payload, opts) when is_map(payload) do
    props = Data.get(payload, "properties", %{}) || %{}
    stages = Keyword.get(opts, :stages, %{})

    %{
      deal_id: Data.get(payload, "id"),
      deal_name: Data.get(props, "dealname"),
      amount: parse_integer(Data.get(props, "amount")),
      deal_stage: Data.get(props, "dealstage"),
      pipeline: Data.get(props, "pipeline"),
      pipeline_stage:
        resolve_pipeline_stage(Data.get(props, "pipeline"), Data.get(props, "dealstage"), stages),
      close_date: Data.get(props, "closedate"),
      deal_currency: Data.get(props, "deal_currency_code"),
      owner_id: Data.get(props, "hubspot_owner_id"),
      description: Data.get(props, "description"),
      deal_type: Data.get(props, "dealtype"),
      probability: parse_integer(Data.get(props, "probability")),
      created_at: Data.get(payload, "createdAt"),
      updated_at: Data.get(payload, "updatedAt"),
      archived?: Data.get(payload, "archived", false),
      archived_at: Data.get(payload, "archivedAt"),
      properties: props,
      associations: Data.get(payload, "associations")
    }
    |> Data.compact()
    |> Deal.new()
  end

  def deal(_payload, _opts), do: {:error, :invalid_deal_payload}

  # ---------------------------------------------------------------------------
  # Note (engagement)
  # ---------------------------------------------------------------------------

  @doc "Normalizes a HubSpot CRM v3 note (engagement) payload."
  @spec note(map()) :: {:ok, Note.t()} | {:error, term()}
  def note(payload) when is_map(payload) do
    props = Data.get(payload, "properties", %{}) || %{}
    associations = Data.get(payload, "associations", %{}) || %{}

    %{
      note_id: Data.get(payload, "id"),
      body: Data.get(props, "hs_note_body"),
      owner_id: Data.get(props, "hubspot_owner_id"),
      contact_ids: association_ids(associations, "contacts"),
      company_ids: association_ids(associations, "companies"),
      deal_ids: association_ids(associations, "deals"),
      ticket_ids: association_ids(associations, "tickets"),
      engagement_type: Data.get(props, "hs_engagement_type"),
      created_at: Data.get(payload, "createdAt"),
      updated_at: Data.get(payload, "updatedAt"),
      archived?: Data.get(payload, "archived", false),
      properties: props,
      associations: associations
    }
    |> Data.compact()
    |> Note.new()
  end

  def note(_payload), do: {:error, :invalid_note_payload}

  # ---------------------------------------------------------------------------
  # Owner
  # ---------------------------------------------------------------------------

  @doc "Normalizes a HubSpot CRM v3 owner payload."
  @spec owner(map()) :: {:ok, Owner.t()} | {:error, term()}
  def owner(payload) when is_map(payload) do
    %{
      owner_id: Data.get(payload, "id"),
      email: Data.get(payload, "email"),
      first_name: Data.get(payload, "firstName"),
      last_name: Data.get(payload, "lastName"),
      user_id: Data.get(payload, "userId"),
      team_id: Data.get(payload, "teamId"),
      archived?: Data.get(payload, "archived", false),
      created_at: Data.get(payload, "createdAt"),
      updated_at: Data.get(payload, "updatedAt")
    }
    |> Data.compact()
    |> Owner.new()
  end

  def owner(_payload), do: {:error, :invalid_owner_payload}

  # ---------------------------------------------------------------------------
  # Pipeline
  # ---------------------------------------------------------------------------

  @doc "Normalizes a HubSpot CRM v3 pipeline payload."
  @spec pipeline(map()) :: {:ok, Pipeline.t()} | {:error, term()}
  def pipeline(payload) when is_map(payload) do
    with {:ok, stages} <- normalize_stages(Data.get(payload, "stages", [])) do
      %{
        pipeline_id: Data.get(payload, "id"),
        label: Data.get(payload, "label"),
        display_order: Data.get(payload, "displayOrder"),
        archived?: Data.get(payload, "archived", false),
        stages: stages,
        created_at: Data.get(payload, "createdAt"),
        updated_at: Data.get(payload, "updatedAt")
      }
      |> Data.compact()
      |> Pipeline.new()
    end
  end

  def pipeline(_payload), do: {:error, :invalid_pipeline_payload}

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  @doc "Normalizes a HubSpot API paging envelope."
  @spec pagination(map()) :: {:ok, Pagination.t()} | {:error, term()}
  def pagination(payload) when is_map(payload) do
    paging = Data.get(payload, "paging", %{}) || %{}
    next = Data.get(paging, "next", %{}) || %{}

    %{
      after: Data.get(next, "after"),
      before: Data.get(next, "before"),
      link: Data.get(next, "link"),
      total: parse_integer(Data.get(payload, "total")),
      total_page: parse_integer(Data.get(payload, "totalPage")),
      page_size: parse_integer(Data.get(payload, "pageSize"))
    }
    |> Data.compact()
    |> Pagination.new()
  end

  def pagination(_payload), do: {:error, :invalid_pagination_payload}

  # ---------------------------------------------------------------------------
  # Pipeline stages
  # ---------------------------------------------------------------------------

  defp normalize_stages(stages) when is_list(stages) do
    stages
    |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
      case pipeline_stage(payload) do
        {:ok, stage} -> {:cont, {:ok, [stage | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, stages} -> {:ok, Enum.reverse(stages)}
      {:error, error} -> {:error, error}
    end
  end

  defp normalize_stages(_stages), do: {:error, :invalid_stages_payload}

  @doc "Normalizes a HubSpot CRM v3 pipeline stage payload."
  @spec pipeline_stage(map()) :: {:ok, PipelineStage.t()} | {:error, term()}
  def pipeline_stage(payload) when is_map(payload) do
    %{
      stage_id: Data.get(payload, "id"),
      label: Data.get(payload, "label"),
      display_order: Data.get(payload, "displayOrder"),
      probability: Data.get(payload, "probability"),
      archived?: Data.get(payload, "archived", false),
      created_at: Data.get(payload, "createdAt"),
      updated_at: Data.get(payload, "updatedAt")
    }
    |> Data.compact()
    |> PipelineStage.new()
  end

  def pipeline_stage(_payload), do: {:error, :invalid_pipeline_stage_payload}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp parse_integer(nil), do: nil
  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_integer(_value), do: nil

  defp association_ids(associations, key) when is_map(associations) do
    associations
    |> Data.get(key, %{})
    |> Data.get("results", [])
    |> Enum.map(&to_string(Data.get(&1, "id", "")))
    |> Enum.reject(&(&1 == ""))
  end

  defp association_ids(_associations, _key), do: []

  defp resolve_pipeline_stage(_pipeline_id, _stage_id, stages) when map_size(stages) == 0, do: nil
  defp resolve_pipeline_stage(nil, _stage_id, _stages), do: nil
  defp resolve_pipeline_stage(_pipeline_id, nil, _stages), do: nil

  defp resolve_pipeline_stage(pipeline_id, stage_id, stages) do
    case Map.get(stages, {pipeline_id, stage_id}) do
      nil -> nil
      stage -> stage
    end
  end
end
