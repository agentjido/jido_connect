defmodule Jido.Connect.Notion.Actions.Write do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Notion.ScopeResolver

  actions do
    action :create_page do
      id("notion.page.create")
      resource(:page)
      verb(:create)
      data_classification(:workspace_content)
      label("Create page")
      description("Create a new Notion page in a parent page, database, or workspace.")
      handler(Jido.Connect.Notion.Handlers.Actions.CreatePage)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:internal_token, :oauth2], default: :internal_token)
        policies([:workspace_access])
        scopes(["insert_content"], resolver: @scope_resolver)
      end

      input do
        field(:parent, :map,
          required?: true,
          description: "Parent reference, e.g. %{page_id: \"...\"} or %{database_id: \"...\"}."
        )

        field(:properties, :map,
          description: "Page property values (required when parent is a database)."
        )

        field(:children, {:array, :map}, description: "Block children to append to the new page.")

        field(:icon, :map, description: "Page icon (emoji or external file).")
        field(:cover, :map, description: "Page cover image.")
      end

      output do
        field(:page, :map)
      end
    end

    action :update_page do
      id("notion.page.update")
      resource(:page)
      verb(:update)
      data_classification(:workspace_content)
      label("Update page")

      description(
        "Update properties, archived status, or other fields on an existing Notion page."
      )

      handler(Jido.Connect.Notion.Handlers.Actions.UpdatePage)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:internal_token, :oauth2], default: :internal_token)
        policies([:workspace_access])
        scopes(["update_content"], resolver: @scope_resolver)
      end

      input do
        field(:page_id, :string, required?: true, description: "Notion page ID.")

        field(:properties, :map, description: "Updated page property values.")

        field(:archived, :boolean,
          description: "Set true to archive the page, false to unarchive."
        )

        field(:icon, :map, description: "Updated page icon.")
        field(:cover, :map, description: "Updated page cover image.")
      end

      output do
        field(:page, :map)
      end
    end

    action :append_block_children do
      id("notion.block.append_children")
      resource(:block)
      verb(:update)
      data_classification(:workspace_content)
      label("Append block children")
      description("Append child blocks to a Notion block or page.")
      handler(Jido.Connect.Notion.Handlers.Actions.AppendBlockChildren)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:internal_token, :oauth2], default: :internal_token)
        policies([:workspace_access])
        scopes(["insert_content"], resolver: @scope_resolver)
      end

      input do
        field(:block_id, :string, required?: true, description: "Parent block or page ID.")

        field(:children, {:array, :map},
          required?: true,
          description: "Block objects to append as children."
        )

        field(:after, :string, description: "Block ID after which to insert the new children.")
      end

      output do
        field(:results, {:array, :map})
        field(:has_more, :boolean)
        field(:next_cursor, :string)
      end
    end

    action :update_block do
      id("notion.block.update")
      resource(:block)
      verb(:update)
      data_classification(:workspace_content)
      label("Update block")
      description("Update the content or archived status of a Notion block.")
      handler(Jido.Connect.Notion.Handlers.Actions.UpdateBlock)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:internal_token, :oauth2], default: :internal_token)
        policies([:workspace_access])
        scopes(["update_content"], resolver: @scope_resolver)
      end

      input do
        field(:block_id, :string, required?: true, description: "Notion block ID.")

        field(:type, :string,
          description: "Block type to update (e.g. \"paragraph\", \"heading_1\")."
        )

        field(:archived, :boolean, description: "Set true to archive the block.")
      end

      output do
        field(:block, :map)
      end
    end

    action :archive_block do
      id("notion.block.archive")
      resource(:block)
      verb(:update)
      data_classification(:workspace_content)
      label("Archive block")
      description("Archive (soft-delete) a Notion block by setting archived to true.")
      handler(Jido.Connect.Notion.Handlers.Actions.ArchiveBlock)
      effect(:destructive, confirmation: :always)

      access do
        auth([:internal_token, :oauth2], default: :internal_token)
        policies([:workspace_access])
        scopes(["update_content"], resolver: @scope_resolver)
      end

      input do
        field(:block_id, :string, required?: true, description: "Notion block ID to archive.")
      end

      output do
        field(:block, :map)
      end
    end

    action :create_comment do
      id("notion.comment.create")
      resource(:comment)
      verb(:create)
      data_classification(:workspace_content)
      label("Create comment")
      description("Create a comment on a Notion page or in an existing discussion.")
      handler(Jido.Connect.Notion.Handlers.Actions.CreateComment)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:internal_token, :oauth2], default: :internal_token)
        policies([:workspace_access])
        scopes(["insert_comments"], resolver: @scope_resolver)
      end

      input do
        field(:parent, :map,
          description: "Parent reference for a new discussion, e.g. %{page_id: \"...\"}."
        )

        field(:discussion_id, :string,
          description: "Discussion ID to add a comment to an existing thread."
        )

        field(:rich_text, {:array, :map},
          required?: true,
          description: "Rich text content of the comment."
        )
      end

      output do
        field(:comment, :map)
      end
    end
  end
end
