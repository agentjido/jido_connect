defmodule Jido.Connect.Google.Meet.Actions.Spaces do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @created_scope "https://www.googleapis.com/auth/meetings.space.created"
  @readonly_scope "https://www.googleapis.com/auth/meetings.space.readonly"
  @scope_resolver Jido.Connect.Google.Meet.ScopeResolver

  actions do
    action :create_space do
      id("google.meet.space.create")
      resource(:space)
      verb(:create)
      data_classification(:personal_data)
      label("Create Meet space")
      description("Create a Google Meet meeting space.")
      handler(Jido.Connect.Google.Meet.Handlers.Actions.CreateSpace)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@created_scope], resolver: @scope_resolver)
      end

      input do
        field(:config, :map)
        field(:access_type, :string)
        field(:entry_point_access, :string)
        field(:moderation, :string)
        field(:moderation_restrictions, :map)
        field(:attendance_report_generation_type, :string)
        field(:artifact_config, :map)
      end

      output do
        field(:space, :map)
      end
    end

    action :get_space do
      id("google.meet.space.get")
      resource(:space)
      verb(:get)
      data_classification(:personal_data)
      label("Get Meet space")
      description("Fetch metadata for a Google Meet meeting space.")
      handler(Jido.Connect.Google.Meet.Handlers.Actions.GetSpace)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:space_name, :string, required?: true, example: "spaces/abc-mnop-xyz")
        field(:fields, :string)
      end

      output do
        field(:space, :map)
      end
    end
  end
end
