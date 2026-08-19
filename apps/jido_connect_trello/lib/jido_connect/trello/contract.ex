defmodule Jido.Connect.Trello.Contract do
  @moduledoc false

  alias Jido.Connect.MCP.Tool

  @endpoint "https://mcp.trello.com/v1"
  @endpoint_id "trello"
  @cursor_max 2_048
  @ari_max 128
  @name_max 512
  @description_max 2_048
  @query_max 500
  @checklist_text_max 16_384

  @actions [
    %{id: "trello.board.get", tool: "trelloReadBoard", remote_action: "get", mutation?: false},
    %{
      id: "trello.list.list",
      tool: "trelloReadList",
      remote_action: "list_by_board",
      mutation?: false
    },
    %{id: "trello.list.get", tool: "trelloReadList", remote_action: "get", mutation?: false},
    %{
      id: "trello.list.create",
      tool: "trelloWriteList",
      remote_action: "create",
      mutation?: true
    },
    %{
      id: "trello.list.update",
      tool: "trelloWriteList",
      remote_action: "update",
      mutation?: true
    },
    %{id: "trello.list.move", tool: "trelloWriteList", remote_action: "move", mutation?: true},
    %{
      id: "trello.list.archive",
      tool: "trelloWriteList",
      remote_action: "archive",
      mutation?: true
    },
    %{
      id: "trello.label.list",
      tool: "trelloReadBoard",
      remote_action: "list_labels",
      mutation?: false
    },
    %{
      id: "trello.card.list",
      tool: "trelloReadCard",
      remote_action: "list_by_board",
      mutation?: false
    },
    %{id: "trello.card.get", tool: "trelloReadCard", remote_action: "get", mutation?: false},
    %{
      id: "trello.card.search",
      tool: "trelloSearch",
      remote_action: "search_cards",
      mutation?: false
    },
    %{
      id: "trello.card.create",
      tool: "trelloWriteCard",
      remote_action: "create",
      mutation?: true
    },
    %{
      id: "trello.card.update",
      tool: "trelloWriteCard",
      remote_action: "update",
      mutation?: true
    },
    %{id: "trello.card.move", tool: "trelloWriteCard", remote_action: "move", mutation?: true},
    %{
      id: "trello.card.complete",
      tool: "trelloWriteCard",
      remote_action: "mark_done",
      mutation?: true
    },
    %{
      id: "trello.card.archive",
      tool: "trelloWriteCard",
      remote_action: "archive",
      mutation?: true
    },
    %{
      id: "trello.card.label.attach",
      tool: "trelloWriteCard",
      remote_action: "attach_label",
      mutation?: true
    },
    %{
      id: "trello.card.label.detach",
      tool: "trelloWriteCard",
      remote_action: "detach_label",
      mutation?: true
    },
    %{
      id: "trello.checklist.list",
      tool: "trelloReadChecklist",
      remote_action: "list_by_card",
      mutation?: false
    },
    %{
      id: "trello.checklist.create",
      tool: "trelloWriteChecklist",
      remote_action: "create",
      mutation?: true
    },
    %{
      id: "trello.checklist.update",
      tool: "trelloWriteChecklist",
      remote_action: "update",
      mutation?: true
    },
    %{
      id: "trello.checklist.item.create",
      tool: "trelloWriteChecklist",
      remote_action: "add_item",
      mutation?: true
    },
    %{
      id: "trello.checklist.item.update",
      tool: "trelloWriteChecklist",
      remote_action: "update_item",
      mutation?: true
    }
  ]

  @string %{"type" => "string"}
  @integer %{"type" => "integer"}
  @boolean %{"type" => "boolean"}
  @position %{
    "anyOf" => [
      %{"type" => "number"},
      %{"type" => "string", "const" => "top"},
      %{"type" => "string", "const" => "bottom"}
    ]
  }

  @tool_schemas (
                  schema = fn actions, properties, required ->
                    %{
                      "type" => "object",
                      "properties" =>
                        Map.put(properties, "action", %{
                          "type" => "string",
                          "enum" => actions
                        }),
                      "required" => required,
                      "additionalProperties" => false
                    }
                  end

                  %{
                    "trelloReadBoard" =>
                      schema.(
                        ~w(get list_labels),
                        %{
                          "boardId" => @string,
                          "cursor" => @string,
                          "limit" => @integer
                        },
                        ["action"]
                      ),
                    "trelloReadList" =>
                      schema.(
                        ~w(list_by_board get),
                        %{
                          "boardId" => @string,
                          "listId" => @string,
                          "cursor" => @string,
                          "limit" => @integer
                        },
                        ["action"]
                      ),
                    "trelloReadCard" =>
                      schema.(
                        ~w(get list_by_board list_by_list),
                        %{
                          "cardIdOrUrl" => @string,
                          "boardIdOrUrl" => @string,
                          "listId" => @string,
                          "filter" => @string,
                          "cursor" => @string,
                          "limit" => @integer
                        },
                        ["action"]
                      ),
                    "trelloSearch" =>
                      schema.(
                        ["search_cards"],
                        %{
                          "query" => @string,
                          "boardIds" => %{"type" => "array"},
                          "cursor" => @string,
                          "limit" => @integer,
                          "partial" => @boolean
                        },
                        ["action", "query"]
                      ),
                    "trelloWriteCard" =>
                      schema.(
                        ~w(create update move archive mark_done attach_label detach_label),
                        %{
                          "cardId" => @string,
                          "listId" => @string,
                          "boardId" => @string,
                          "name" => @string,
                          "desc" => @string,
                          "due" => @string,
                          "pos" => @position,
                          "labelId" => @string
                        },
                        ["action"]
                      ),
                    "trelloReadChecklist" =>
                      schema.(
                        ~w(list_by_card get),
                        %{
                          "cardId" => @string,
                          "checklistId" => @string,
                          "cursor" => @string,
                          "limit" => @integer
                        },
                        ["action"]
                      ),
                    "trelloWriteChecklist" =>
                      schema.(
                        ~w(create add_item update_item update),
                        %{
                          "cardId" => @string,
                          "checklistId" => @string,
                          "itemId" => @string,
                          "name" => @string,
                          "text" => @string,
                          "checked" => @boolean,
                          "pos" => @position
                        },
                        ["action"]
                      ),
                    "trelloWriteList" =>
                      schema.(
                        ~w(create update archive move),
                        %{
                          "listId" => @string,
                          "boardId" => @string,
                          "name" => @string,
                          "pos" => @position
                        },
                        ["action"]
                      )
                  }
                )

  @tool_schema_hashes Map.new(@tool_schemas, fn {tool, schema} ->
                        {tool, Tool.schema_hash(schema)}
                      end)
  @action_mutations Map.new(@actions, &{&1.id, &1.mutation?})

  def endpoint, do: @endpoint
  def endpoint_id, do: @endpoint_id
  def actions, do: @actions
  def tool_schemas, do: @tool_schemas
  def cursor_max, do: @cursor_max
  def ari_max, do: @ari_max
  def name_max, do: @name_max
  def description_max, do: @description_max
  def query_max, do: @query_max
  def checklist_text_max, do: @checklist_text_max

  def fetch_action!(id), do: Enum.find(@actions, &(&1.id == id)) || raise(ArgumentError, id)
  def schema_hash(tool), do: Map.fetch!(@tool_schema_hashes, tool)
  def mutation?(action), do: Map.get(@action_mutations, action, true)
end
