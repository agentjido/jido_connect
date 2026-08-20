defmodule Jido.Connect.Dsl.Entities.Fields do
  @moduledoc false

  alias Jido.Connect.Dsl

  def field do
    %Spark.Dsl.Entity{
      name: :field,
      target: Jido.Connect.Field,
      args: [:name, :type],
      schema: field_schema(),
      transform: {Dsl.Field, :transform, []}
    }
  end

  def input, do: field_group(:input)
  def output, do: field_group(:output)
  def config, do: field_group(:config)
  def signal, do: field_group(:signal)

  def named_schema do
    %Spark.Dsl.Entity{
      name: :schema,
      target: Dsl.NamedSchema,
      args: [:name],
      identifier: :name,
      entities: [fields: [field()]],
      schema: [
        name: [type: :atom, required: true],
        label: [type: :string],
        description: [type: :string],
        metadata: [type: :map, default: %{}]
      ]
    }
  end

  defp field_group(name) do
    %Spark.Dsl.Entity{
      name: name,
      target: Dsl.FieldGroup,
      entities: [fields: [field()]],
      schema: []
    }
  end

  defp field_schema do
    [
      name: [type: :atom, required: true],
      type: [type: :any, required: true],
      required?: [type: :boolean, default: false],
      default: [type: :any],
      enum: [type: {:list, :any}],
      minimum: [type: :number],
      maximum: [type: :number],
      min_length: [type: :non_neg_integer],
      max_length: [type: :non_neg_integer],
      json_schema: [type: :any],
      example: [type: :any],
      description: [type: :string],
      metadata: [type: :map, default: %{}]
    ]
  end
end
