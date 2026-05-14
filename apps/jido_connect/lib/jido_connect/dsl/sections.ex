defmodule Jido.Connect.Dsl.Sections do
  @moduledoc false

  alias Jido.Connect.Dsl.Entities.{Auth, Catalog, Fields, Operations}

  def sections do
    [
      Catalog.integration_section(),
      Catalog.catalog_section(),
      schemas_section(),
      auth_section(),
      Catalog.policies_section(),
      actions_section(),
      triggers_section()
    ]
  end

  defp schemas_section do
    %Spark.Dsl.Section{
      name: :schemas,
      entities: [Fields.named_schema()]
    }
  end

  defp auth_section do
    %Spark.Dsl.Section{
      name: :auth,
      entities: [
        Auth.oauth2(),
        Auth.api_key(),
        Auth.app_installation(),
        Auth.service_account(),
        Auth.domain_delegated_service_account()
      ]
    }
  end

  defp actions_section do
    %Spark.Dsl.Section{
      name: :actions,
      entities: [Operations.action()]
    }
  end

  defp triggers_section do
    %Spark.Dsl.Section{
      name: :triggers,
      entities: [Operations.poll(), Operations.webhook()]
    }
  end
end
