defmodule Jido.Connect.Confluence.Actions.Spaces do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  alias Jido.Connect.Confluence.Contract

  @identifier_max Contract.maximum_identifier_length()

  actions do
    action :get_space do
      id("confluence.space.get")
      resource(:space)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get space")
      description("Get one visible Confluence Cloud space by key.")
      handler(Jido.Connect.Confluence.Handlers.Actions.GetSpace)
      effect(:read)

      access do
        auth([:api_token], default: :api_token)
        scopes(["read:space:confluence"])
      end

      input do
        field(:key, :string,
          required?: true,
          min_length: 1,
          max_length: @identifier_max,
          example: "OPS"
        )
      end

      output do
        field(:kind, :string)
        field(:account, :string)
        field(:id, :string)
        field(:key, :string)
        field(:name, :string)
        field(:type, :string)
        field(:status, :string)
        field(:homepage_id, :string)
        field(:url, :string)
      end
    end
  end
end
