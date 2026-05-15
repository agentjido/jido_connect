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
  end
end
