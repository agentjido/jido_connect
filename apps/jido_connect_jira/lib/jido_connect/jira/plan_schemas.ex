defmodule Jido.Connect.Jira.PlanSchemas do
  @moduledoc false

  @max_id 2_147_483_647
  @max_items 100
  @max_string 255

  @id %{"type" => "integer", "minimum" => 1, "maximum" => @max_id}

  def issue_sources do
    array(
      object(
        %{
          "type" => %{"type" => "string", "enum" => ~w(Board Project Filter)},
          "value" => @id
        },
        ~w(type value)
      ),
      min_items: 1,
      unique_items: true
    )
  end

  def scheduling(require_estimation?) do
    required = if require_estimation?, do: ["estimation"], else: []

    object(
      %{
        "estimation" => %{"type" => "string", "enum" => ~w(StoryPoints Days Hours)},
        "startDate" => date_field(),
        "endDate" => date_field(),
        "inferredDates" => %{
          "type" => "string",
          "enum" => ~w(None SprintDates ReleaseDates)
        },
        "dependencies" => %{"type" => "string", "enum" => ~w(Sequential Concurrent)}
      },
      required,
      if(require_estimation?, do: [], else: [min_properties: 1])
    )
  end

  def exclusion_rules(require_non_empty?) do
    schema =
      object(%{
        "numberOfDaysToShowCompletedIssues" => %{
          "type" => "integer",
          "minimum" => 0,
          "maximum" => @max_id
        },
        "issueIds" => id_list(),
        "workStatusIds" => id_list(),
        "workStatusCategoryIds" => id_list(),
        "issueTypeIds" => id_list(),
        "releaseIds" => id_list()
      })

    if require_non_empty?, do: Map.put(schema, "minProperties", 1), else: schema
  end

  def cross_project_releases do
    array(
      object(
        %{
          "name" => bounded_string(),
          "releaseIds" => id_list()
        },
        ~w(name releaseIds)
      )
    )
  end

  def custom_fields do
    array(
      object(
        %{
          "customFieldId" => @id,
          "filter" => %{"type" => "boolean"}
        },
        ~w(customFieldId filter)
      )
    )
  end

  def permissions do
    holder =
      object(
        %{
          "type" => %{"type" => "string", "enum" => ~w(Group AccountId)},
          "value" => bounded_string()
        },
        ~w(type value)
      )

    array(
      object(
        %{
          "type" => %{"type" => "string", "enum" => ~w(View Edit)},
          "holder" => holder
        },
        ~w(type holder)
      )
    )
  end

  defp date_field do
    other_types = ~w(DueDate TargetStartDate TargetEndDate)

    object(
      %{
        "type" => %{"type" => "string", "enum" => other_types ++ ["DateCustomField"]},
        "dateCustomFieldId" => @id
      },
      ["type"],
      oneOf: [
        %{
          "properties" => %{"type" => %{"const" => "DateCustomField"}},
          "required" => ["dateCustomFieldId"]
        },
        %{
          "properties" => %{"type" => %{"enum" => other_types}},
          "not" => %{"required" => ["dateCustomFieldId"]}
        }
      ]
    )
  end

  defp id_list do
    %{
      "type" => "array",
      "items" => @id,
      "minItems" => 1,
      "maxItems" => @max_items,
      "uniqueItems" => true
    }
  end

  defp bounded_string do
    %{"type" => "string", "minLength" => 1, "maxLength" => @max_string}
  end

  defp array(items, opts \\ []) do
    %{
      "type" => "array",
      "items" => items,
      "maxItems" => @max_items
    }
    |> maybe_put("minItems", Keyword.get(opts, :min_items))
    |> maybe_put("uniqueItems", Keyword.get(opts, :unique_items))
  end

  defp object(properties, required \\ [], opts \\ []) do
    %{
      "type" => "object",
      "properties" => properties,
      "required" => required,
      "additionalProperties" => false
    }
    |> Map.merge(Map.new(opts, fn {key, value} -> {camel_key(key), value} end))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp camel_key(:min_properties), do: "minProperties"
  defp camel_key(:oneOf), do: "oneOf"
end
