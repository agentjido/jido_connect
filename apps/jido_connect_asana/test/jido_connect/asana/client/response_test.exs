defmodule Jido.Connect.Asana.Client.ResponseTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.Client.Response

  describe "handle_workspace_list_response/1" do
    test "returns items and pagination for valid list response" do
      body = %{
        "data" => [
          %{"gid" => "112233", "name" => "Acme Corp", "resource_type" => "workspace"}
        ],
        "next_page" => %{
          "offset" => "eyJvZmZzZXQiOiAiMQ",
          "path" => "/workspaces?offset=eyJvZmZzZXQiOiAiMQ",
          "uri" => "https://app.asana.com/api/1.0/workspaces?offset=eyJvZmZzZXQiOiAiMQ"
        }
      }

      response = {:ok, %{status: 200, body: body}}

      assert {:ok, result} = Response.handle_workspace_list_response(response)
      assert length(result.items) == 1
      assert hd(result.items).gid == "112233"
      assert hd(result.items).name == "Acme Corp"
      assert result.pagination != nil
      assert result.pagination.has_next == true
    end

    test "returns error for missing data key" do
      body = %{"next_page" => nil}
      response = {:ok, %{status: 200, body: body}}

      assert {:error, error} = Response.handle_workspace_list_response(response)
      assert error.reason == :invalid_response
    end

    test "returns error for non-200 status" do
      response = {:ok, %{status: 401, body: %{"errors" => [%{"message" => "Not Authorized"}]}}}

      assert {:error, error} = Response.handle_workspace_list_response(response)
      assert error.status == 401
      assert error.provider == :asana
    end
  end

  describe "handle_task_response/1" do
    test "returns normalized task for valid response" do
      body = %{
        "data" => %{
          "gid" => "998877",
          "name" => "Design new landing page",
          "resource_type" => "task",
          "completed" => false,
          "notes" => "Create wireframes"
        }
      }

      response = {:ok, %{status: 200, body: body}}

      assert {:ok, task} = Response.handle_task_response(response)
      assert task.gid == "998877"
      assert task.name == "Design new landing page"
      assert task.completed == false
    end

    test "returns error for missing data key" do
      body = %{}
      response = {:ok, %{status: 200, body: body}}

      assert {:error, error} = Response.handle_task_response(response)
      assert error.reason == :invalid_response
    end
  end

  describe "handle_user_response/1" do
    test "returns normalized user for valid response" do
      body = %{
        "data" => %{
          "gid" => "123456",
          "name" => "Alice Nakamura",
          "resource_type" => "user",
          "email" => "alice@example.com"
        }
      }

      response = {:ok, %{status: 200, body: body}}

      assert {:ok, user} = Response.handle_user_response(response)
      assert user.gid == "123456"
      assert user.name == "Alice Nakamura"
      assert user.email == "alice@example.com"
    end
  end

  describe "handle_story_list_response/1" do
    test "returns normalized stories with pagination" do
      body = %{
        "data" => [
          %{
            "gid" => "334455",
            "resource_type" => "story",
            "resource_subtype" => "comment_added",
            "text" => "Updated wireframes"
          }
        ],
        "next_page" => nil
      }

      response = {:ok, %{status: 200, body: body}}

      assert {:ok, result} = Response.handle_story_list_response(response)
      assert length(result.items) == 1
      assert hd(result.items).gid == "334455"
      assert hd(result.items).resource_subtype == "comment_added"
    end
  end

  describe "handle_user_list_response/1" do
    test "returns normalized users list" do
      body = %{
        "data" => [
          %{
            "gid" => "123456",
            "name" => "Alice Nakamura",
            "resource_type" => "user",
            "email" => "alice@example.com"
          }
        ],
        "next_page" => nil
      }

      response = {:ok, %{status: 200, body: body}}

      assert {:ok, result} = Response.handle_user_list_response(response)
      assert length(result.items) == 1
      assert hd(result.items).gid == "123456"
    end
  end

  describe "handle_task_list_response/1" do
    test "returns normalized tasks with empty pagination" do
      body = %{
        "data" => [
          %{"gid" => "998877", "name" => "Task A", "resource_type" => "task"}
        ],
        "next_page" => nil
      }

      response = {:ok, %{status: 200, body: body}}

      assert {:ok, result} = Response.handle_task_list_response(response)
      assert length(result.items) == 1
      assert result.pagination != nil
      assert result.pagination.has_next == false
    end
  end

  describe "handle_project_list_response/1" do
    test "returns normalized projects list" do
      body = %{
        "data" => [
          %{"gid" => "445566", "name" => "Website Redesign", "resource_type" => "project"}
        ],
        "next_page" => nil
      }

      response = {:ok, %{status: 200, body: body}}

      assert {:ok, result} = Response.handle_project_list_response(response)
      assert length(result.items) == 1
      assert hd(result.items).gid == "445566"
    end
  end
end
