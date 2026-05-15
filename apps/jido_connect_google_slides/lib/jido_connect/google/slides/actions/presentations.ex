defmodule Jido.Connect.Google.Slides.Actions.Presentations do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @readonly_scope "https://www.googleapis.com/auth/presentations.readonly"
  @write_scope "https://www.googleapis.com/auth/presentations"
  @scope_resolver Jido.Connect.Google.Slides.ScopeResolver

  actions do
    action :get_presentation do
      id("google.slides.presentation.get")
      resource(:presentation)
      verb(:get)
      data_classification(:workspace_content)
      label("Get presentation")
      description("Fetch a Google Slides presentation by presentation id.")
      handler(Jido.Connect.Google.Slides.Handlers.Actions.GetPresentation)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:presentation_id, :string, required?: true, example: "1abc...")

        field(:fields, :string,
          description: "Optional field mask specifying which fields to include in the response."
        )
      end

      output do
        field(:presentation, :map)
      end
    end

    action :create_presentation do
      id("google.slides.presentation.create")
      resource(:presentation)
      verb(:create)
      data_classification(:workspace_metadata)
      label("Create presentation")
      description("Create a new Google Slides presentation with an optional title.")
      handler(Jido.Connect.Google.Slides.Handlers.Actions.CreatePresentation)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@write_scope], resolver: @scope_resolver)
      end

      input do
        field(:title, :string, required?: true, example: "Q4 Strategy Review")
      end

      output do
        field(:presentation, :map)
      end
    end

    action :batch_update do
      id("google.slides.presentation.batch_update")
      resource(:presentation)
      verb(:update)
      data_classification(:workspace_content)
      label("Batch update presentation")

      description(
        "Apply one or more updates to a Google Slides presentation in a single atomic request."
      )

      handler(Jido.Connect.Google.Slides.Handlers.Actions.BatchUpdatePresentation)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@write_scope], resolver: @scope_resolver)
      end

      input do
        field(:presentation_id, :string, required?: true, example: "1abc...")

        field(:requests, {:array, :map},
          required?: true,
          description: "List of update requests to apply."
        )

        field(:write_control, :map, description: "Optional write control for revision gating.")
      end

      output do
        field(:batch_update_result, :map)
      end
    end

    action :get_page_thumbnail do
      id("google.slides.presentation.page.get_thumbnail")
      resource(:presentation)
      verb(:get)
      data_classification(:workspace_content)
      label("Get page thumbnail")

      description(
        "Fetch the thumbnail image metadata for a specific page in a Google Slides presentation."
      )

      handler(Jido.Connect.Google.Slides.Handlers.Actions.GetPageThumbnail)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:presentation_id, :string, required?: true, example: "1abc...")
        field(:page_object_id, :string, required?: true, example: "slide_title")

        field(:thumbnail_properties, :map,
          description: "Optional thumbnail size and mime type preferences."
        )
      end

      output do
        field(:thumbnail, :map)
      end
    end
  end
end
