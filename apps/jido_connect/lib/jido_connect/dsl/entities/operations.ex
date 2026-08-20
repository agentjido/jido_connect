defmodule Jido.Connect.Dsl.Entities.Operations do
  @moduledoc false

  alias Jido.Connect.Dsl
  alias Jido.Connect.Dsl.Entities.{Auth, Fields}

  def action do
    %Spark.Dsl.Entity{
      name: :action,
      target: Dsl.Action,
      args: [:name],
      identifier: :name,
      schema: action_schema(),
      entities: [
        access: [Auth.access()],
        effect: [effect()],
        auth_profiles: [Auth.auth_profiles()],
        requirements: [Auth.requirements()],
        input: [Fields.input()],
        output: [Fields.output()]
      ],
      singleton_entity_keys: [:access, :effect, :auth_profiles, :requirements, :input, :output]
    }
  end

  def poll do
    %Spark.Dsl.Entity{
      name: :poll,
      target: Dsl.Trigger,
      args: [:name],
      identifier: :name,
      auto_set_fields: [kind: :poll],
      schema: poll_schema(),
      entities: trigger_entities(),
      singleton_entity_keys: [:access, :auth_profiles, :requirements, :config, :signal]
    }
  end

  def webhook do
    %Spark.Dsl.Entity{
      name: :webhook,
      target: Dsl.Trigger,
      args: [:name],
      identifier: :name,
      auto_set_fields: [kind: :webhook],
      schema: webhook_schema(),
      entities: trigger_entities(),
      singleton_entity_keys: [:access, :auth_profiles, :requirements, :config, :signal]
    }
  end

  defp effect do
    %Spark.Dsl.Entity{
      name: :effect,
      target: Dsl.Effect,
      args: [:risk],
      schema: [
        risk: [type: :atom, required: true],
        mutation?: [type: :boolean],
        provider_idempotency?: [type: :boolean, default: false],
        confirmation: [type: :atom]
      ]
    }
  end

  defp trigger_entities do
    [
      access: [Auth.access()],
      auth_profiles: [Auth.auth_profiles()],
      requirements: [Auth.requirements()],
      config: [Fields.config()],
      signal: [Fields.signal()]
    ]
  end

  defp action_schema do
    [
      name: [type: :atom, required: true],
      id: [type: :string],
      label: [type: :string],
      description: [type: :string],
      tags: [type: {:list, :atom}, default: []],
      resource: [type: :atom],
      verb: [type: :atom],
      data_classification: [type: :atom],
      policies: [type: {:list, :atom}, default: []],
      input_schema: [type: :atom],
      input_json_schema_overlay: [type: :any, default: %{}],
      output_schema: [type: :atom],
      mutation?: [type: :boolean, default: false],
      provider_idempotency?: [type: :boolean, default: false],
      risk: [type: :atom, default: :read],
      confirmation: [type: :atom, default: :none],
      handler: [type: :module, required: true],
      preview: [type: :module],
      metadata: [type: :map, default: %{}]
    ]
  end

  defp poll_schema do
    [
      name: [type: :atom, required: true],
      id: [type: :string],
      label: [type: :string],
      description: [type: :string],
      tags: [type: {:list, :atom}, default: []],
      resource: [type: :atom],
      verb: [type: :atom],
      data_classification: [type: :atom],
      policies: [type: {:list, :atom}, default: []],
      config_schema: [type: :atom],
      signal_schema: [type: :atom],
      interval_ms: [type: :pos_integer],
      checkpoint: [type: :atom],
      dedupe: [type: :map],
      handler: [type: :module, required: true],
      metadata: [type: :map, default: %{}]
    ]
  end

  defp webhook_schema do
    [
      name: [type: :atom, required: true],
      id: [type: :string],
      label: [type: :string],
      description: [type: :string],
      tags: [type: {:list, :atom}, default: []],
      resource: [type: :atom],
      verb: [type: :atom],
      data_classification: [type: :atom],
      policies: [type: {:list, :atom}, default: []],
      config_schema: [type: :atom],
      signal_schema: [type: :atom],
      verification: [type: :map, required: true],
      dedupe: [type: :map],
      handler: [type: :module, required: true],
      metadata: [type: :map, default: %{}]
    ]
  end
end
