defmodule Jido.Connect.Confluence.Actions.Pages do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  alias Jido.Connect.Confluence.Contract

  @identifier_max Contract.maximum_identifier_length()
  @title_max Contract.maximum_title_length()
  @markdown_max Contract.maximum_markdown_length()
  @cursor_max Contract.maximum_cursor_length()
  @version_message_max Contract.maximum_version_message_length()
  @default_limit Contract.default_limit()
  @maximum_limit Contract.maximum_limit()
  @default_max_characters Contract.default_max_characters()
  @maximum_max_characters Contract.maximum_max_characters()

  actions do
    action :list_pages do
      id("confluence.page.list")
      resource(:page)
      verb(:list)
      data_classification(:workspace_content)
      label("List pages")
      description("List visible pages in one Confluence Cloud space.")
      handler(Jido.Connect.Confluence.Handlers.Actions.ListPages)
      effect(:read)

      access do
        auth([:api_token], default: :api_token)
        scopes(["read:space:confluence", "read:page:confluence"])
      end

      input do
        field(:space_key, :string,
          required?: true,
          min_length: 1,
          max_length: @identifier_max,
          example: "OPS"
        )

        field(:limit, :integer, default: @default_limit, minimum: 1, maximum: @maximum_limit)
        field(:cursor, :string, min_length: 1, max_length: @cursor_max)
      end

      output do
        field(:kind, :string)
        field(:account, :string)
        field(:space, :map)
        field(:count, :integer)
        field(:limit, :integer)
        field(:next_cursor, :string)
        field(:items, {:array, :map})
      end
    end

    action :get_page do
      id("confluence.page.get")
      resource(:page)
      verb(:get)
      data_classification(:workspace_content)
      label("Get page")
      description("Get readable text from one Confluence Cloud page.")
      handler(Jido.Connect.Confluence.Handlers.Actions.GetPage)
      effect(:read)

      access do
        auth([:api_token], default: :api_token)
        scopes(["read:page:confluence"])
      end

      input do
        field(:id, :string, required?: true, min_length: 1, max_length: @identifier_max)

        field(:max_characters, :integer,
          default: @default_max_characters,
          minimum: 1,
          maximum: @maximum_max_characters
        )
      end

      output do
        field(:kind, :string)
        field(:account, :string)
        field(:id, :string)
        field(:title, :string)
        field(:revision_id, :string)
        field(:version, :integer)
        field(:space_id, :string)
        field(:text, :string)
        field(:character_count, :integer)
        field(:truncated, :boolean)
      end
    end

    action :create_page do
      id("confluence.page.create")
      resource(:page)
      verb(:create)
      data_classification(:workspace_content)
      label("Create page")
      description("Create one Confluence Cloud page from bounded Markdown.")
      handler(Jido.Connect.Confluence.Handlers.Actions.CreatePage)
      preview(Jido.Connect.Confluence.Previews.CreatePage)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:api_token], default: :api_token)
        scopes(["read:space:confluence", "write:page:confluence"])
      end

      input do
        field(:title, :string,
          required?: true,
          min_length: 1,
          max_length: @title_max
        )

        field(:space_key, :string,
          required?: true,
          min_length: 1,
          max_length: @identifier_max
        )

        field(:markdown, :string,
          required?: true,
          min_length: 0,
          max_length: @markdown_max
        )

        field(:parent_id, :string, min_length: 1, max_length: @identifier_max)
      end

      output do
        field(:kind, :string)
        field(:effect, :string)
        field(:submitted, :boolean)
        field(:page, :map)
      end
    end

    action :update_page do
      id("confluence.page.update")
      resource(:page)
      verb(:update)
      data_classification(:workspace_content)
      label("Update page")
      description("Update one page after a remote version and space check.")
      handler(Jido.Connect.Confluence.Handlers.Actions.UpdatePage)
      preview(Jido.Connect.Confluence.Previews.UpdatePage)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:api_token], default: :api_token)
        scopes(["read:space:confluence", "read:page:confluence", "write:page:confluence"])
      end

      input do
        field(:id, :string, required?: true, min_length: 1, max_length: @identifier_max)

        field(:space_key, :string,
          required?: true,
          min_length: 1,
          max_length: @identifier_max
        )

        field(:markdown, :string,
          required?: true,
          min_length: 0,
          max_length: @markdown_max
        )

        field(:last_pushed_version, :integer, required?: true, minimum: 1)
        field(:force, :boolean, default: false)
        field(:title, :string, min_length: 1, max_length: @title_max)

        field(:version_message, :string,
          min_length: 1,
          max_length: @version_message_max
        )
      end

      output do
        field(:kind, :string)
        field(:effect, :string)
        field(:submitted, :boolean)
        field(:page, :map)
      end
    end

    action :delete_page do
      id("confluence.page.delete")
      resource(:page)
      verb(:delete)
      data_classification(:workspace_content)
      label("Delete page")
      description("Move one Confluence Cloud page to the trash.")
      handler(Jido.Connect.Confluence.Handlers.Actions.DeletePage)
      preview(Jido.Connect.Confluence.Previews.DeletePage)
      effect(:destructive, confirmation: :always)

      access do
        auth([:api_token], default: :api_token)
        scopes(["write:page:confluence"])
      end

      input do
        field(:id, :string, required?: true, min_length: 1, max_length: @identifier_max)
      end

      output do
        field(:kind, :string)
        field(:effect, :string)
        field(:submitted, :boolean)
        field(:page, :map)
      end
    end
  end
end
