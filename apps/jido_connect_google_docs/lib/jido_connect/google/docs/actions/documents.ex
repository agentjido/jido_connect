defmodule Jido.Connect.Google.Docs.Actions.Documents do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @readonly_scope "https://www.googleapis.com/auth/documents.readonly"
  @write_scope "https://www.googleapis.com/auth/documents"
  @scope_resolver Jido.Connect.Google.Docs.ScopeResolver

  actions do
    action :get_document do
      id("google.docs.document.get")
      resource(:document)
      verb(:get)
      data_classification(:workspace_content)
      label("Get document")
      description("Fetch a Google Docs document by document id.")
      handler(Jido.Connect.Google.Docs.Handlers.Actions.GetDocument)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:document_id, :string, required?: true, example: "1abc...")

        field(:suggestions_view_mode, :string,
          enum: [
            "DEFAULT_FOR_CURRENT_ACCESS",
            "SUGGESTIONS_INLINE",
            "PREVIEW_SUGGESTIONS_INLINE",
            "PREVIEW_WITHOUT_SUGGESTIONS_INLINE"
          ]
        )

        field(:include_tabs_content, :boolean,
          example: true,
          description: "Populate the Document.tabs field instead of legacy text content fields."
        )
      end

      output do
        field(:document, :map)
      end
    end

    action :create_document do
      id("google.docs.document.create")
      resource(:document)
      verb(:create)
      data_classification(:workspace_metadata)
      label("Create document")
      description("Create a new Google Docs document with an optional title.")
      handler(Jido.Connect.Google.Docs.Handlers.Actions.CreateDocument)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@write_scope], resolver: @scope_resolver)
      end

      input do
        field(:title, :string, required?: true, example: "Project Plan")
      end

      output do
        field(:document, :map)
      end
    end

    action :batch_update_document do
      id("google.docs.document.batch_update")
      resource(:document)
      verb(:update)
      data_classification(:workspace_content)
      label("Batch update document")

      description(
        "Run a validated Google Docs batchUpdate request for text, style, table, and image operations."
      )

      handler(Jido.Connect.Google.Docs.Handlers.Actions.BatchUpdateDocument)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@write_scope], resolver: @scope_resolver)
      end

      input do
        field(:document_id, :string, required?: true, example: "1abc...")

        field(:requests, {:array, :map},
          required?: true,
          description:
            "List of batch update operations. Each map must contain exactly one operation key."
        )

        field(:write_control, :map,
          description: "Optional write control for concurrency control."
        )
      end

      output do
        field(:document, :map)
        field(:replies, {:array, :map})
      end
    end
  end
end
