defmodule Jido.Connect.Jira.Client.ResponseTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Jira.Client.Response

  describe "handle_project_response/1" do
    test "normalizes a successful project get response" do
      body = %{
        "key" => "PROJ",
        "id" => "10000",
        "name" => "Project Alpha",
        "projectTypeKey" => "software",
        "style" => "classic",
        "self" => "https://example.atlassian.net/rest/api/3/project/10000"
      }

      assert {:ok, project} = Response.handle_project_response({:ok, %{status: 200, body: body}})
      assert project[:key] == "PROJ"
      assert project[:name] == "Project Alpha"
      assert project[:id] == "10000"
      assert project[:project_type] == "software"
    end

    test "returns error for non-map body" do
      assert {:error, _} = Response.handle_project_response({:ok, %{status: 200, body: nil}})
    end

    test "returns error for HTTP error" do
      assert {:error, _} =
               Response.handle_project_response(
                 {:ok, %{status: 404, body: %{"errorMessages" => ["Not found"]}}}
               )
    end
  end

  describe "handle_project_list_response/1" do
    test "normalizes a successful project list response" do
      body = %{
        "startAt" => 0,
        "maxResults" => 50,
        "total" => 2,
        "isLast" => true,
        "values" => [
          %{
            "key" => "PROJ",
            "id" => "10000",
            "name" => "Project Alpha",
            "projectTypeKey" => "software"
          },
          %{
            "key" => "TEAM",
            "id" => "10001",
            "name" => "Team Ops",
            "projectTypeKey" => "business"
          }
        ]
      }

      assert {:ok, result} =
               Response.handle_project_list_response({:ok, %{status: 200, body: body}})

      assert length(result.projects) == 2
      assert hd(result.projects)[:key] == "PROJ"
      assert result.total == 2
      assert result.start_at == 0
      assert result.max_results == 50
      assert result.is_last == true
    end

    test "returns error when values key is missing" do
      body = %{"startAt" => 0, "total" => 0}

      assert {:error, _} =
               Response.handle_project_list_response({:ok, %{status: 200, body: body}})
    end
  end

  describe "handle_field_schema_list_response/1" do
    test "normalizes a successful field schema list response" do
      body = [
        %{
          "id" => "summary",
          "name" => "Summary",
          "key" => "summary",
          "custom" => false,
          "orderable" => true,
          "navigable" => true,
          "searchable" => true,
          "clauseNames" => ["summary"],
          "schema" => %{"type" => "string", "system" => "summary"}
        },
        %{
          "id" => "customfield_10001",
          "name" => "Story Points",
          "key" => "customfield_10001",
          "custom" => true,
          "clauseNames" => ["cf[10001]"],
          "schema" => %{"type" => "number", "customId" => 10001}
        }
      ]

      assert {:ok, result} =
               Response.handle_field_schema_list_response({:ok, %{status: 200, body: body}})

      assert length(result.fields) == 2
      assert result.total == 2
      assert hd(result.fields)[:id] == "summary"
      assert hd(result.fields)[:custom] == false
      assert Enum.at(result.fields, 1)[:id] == "customfield_10001"
      assert Enum.at(result.fields, 1)[:custom] == true
    end

    test "returns error for map body (wrong shape)" do
      body = %{"id" => "summary"}

      assert {:error, _} =
               Response.handle_field_schema_list_response({:ok, %{status: 200, body: body}})
    end
  end

  describe "handle_issue_search_response/1 with is_last" do
    test "includes is_last in search results" do
      body = %{
        "startAt" => 0,
        "maxResults" => 50,
        "total" => 1,
        "isLast" => true,
        "issues" => [
          %{
            "key" => "PROJ-123",
            "id" => "10001",
            "fields" => %{
              "summary" => "Test"
            }
          }
        ]
      }

      assert {:ok, result} =
               Response.handle_issue_search_response({:ok, %{status: 200, body: body}})

      assert result.is_last == true
      assert result.start_at == 0
      assert result.max_results == 50
    end

    test "returns nil is_last when not present" do
      body = %{
        "startAt" => 0,
        "maxResults" => 50,
        "total" => 1,
        "issues" => [
          %{
            "key" => "PROJ-123",
            "id" => "10001",
            "fields" => %{}
          }
        ]
      }

      assert {:ok, result} =
               Response.handle_issue_search_response({:ok, %{status: 200, body: body}})

      assert result.is_last == nil
    end
  end
end
