defmodule Jido.Connect.X.Contract do
  @moduledoc false

  @base_url "http://127.0.0.1:8000"
  @mcp_path "/mcp"
  @endpoint @base_url <> @mcp_path
  @endpoint_id "x"
  @pagination_token_max 2_048

  @actions [
    %{id: "x.account.get", tool: "get_users_me"},
    %{id: "x.bookmark.list", tool: "get_users_bookmarks"},
    %{id: "x.post.list", tool: "get_users_posts"}
  ]

  @tool_schemas %{
    "get_users_me" => %{
      "type" => "object",
      "properties" => %{},
      "required" => [],
      "additionalProperties" => true
    },
    "get_users_bookmarks" => %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string"},
        "max_results" => %{"type" => "integer"},
        "pagination_token" => %{"type" => "string"}
      },
      "required" => ["id"],
      "additionalProperties" => true
    },
    "get_users_posts" => %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string"},
        "max_results" => %{"type" => "integer"},
        "pagination_token" => %{"type" => "string"}
      },
      "required" => ["id"],
      "additionalProperties" => true
    }
  }

  def endpoint, do: @endpoint
  def base_url, do: @base_url
  def mcp_path, do: @mcp_path
  def endpoint_id, do: @endpoint_id
  def pagination_token_max, do: @pagination_token_max
  def actions, do: @actions
  def tool_schemas, do: @tool_schemas
  def tool_schema(tool), do: Map.fetch!(@tool_schemas, tool)
  def fetch_action!(id), do: Enum.find(@actions, &(&1.id == id)) || raise(ArgumentError, id)
end
