defmodule Jido.Connect.Jira.Client.ResponseTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Jira.Client.Response
  alias Jido.Connect.TestSupport.LiveSmoke

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

  describe "handle_issue_search_response/2" do
    # Recorded enhanced-search pages; see `Client.IssueSearchTest`.
    test "returns the page envelope without total or start_at" do
      body = LiveSmoke.fixture!(:jira, "issue_context.4")

      assert {:ok, result} =
               Response.handle_issue_search_response({:ok, %{status: 200, body: body}})

      assert Map.keys(result) |> Enum.sort() == [:is_last, :issues, :next_page_token]
      assert %{is_last: false, issues: [%{key: "JCL-1"}, %{key: "JCL-2"}]} = result
      assert result.next_page_token == body["nextPageToken"]
    end

    test "returns no token on the last page" do
      body = LiveSmoke.fixture!(:jira, "issue_context.6")

      assert {:ok, %{is_last: true, next_page_token: nil, issues: [%{key: "JCL-5"}]}} =
               Response.handle_issue_search_response({:ok, %{status: 200, body: body}})
    end
  end
end
