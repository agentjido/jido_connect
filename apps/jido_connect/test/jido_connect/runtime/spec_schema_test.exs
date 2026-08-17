defmodule Jido.Connect.Runtime.SpecSchemaTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.RuntimeFixtures

  test "spec validation errors use the package taxonomy" do
    assert_raise Connect.Error.ValidationError, ~r/Unknown auth profile/, fn ->
      RuntimeFixtures.spec(%{action: %{auth_profile: :missing}})
    end

    assert_raise Connect.Error.ValidationError, ~r/Mutation action/, fn ->
      RuntimeFixtures.spec(%{action: %{mutation?: true, confirmation: :none}})
    end

    assert_raise Connect.Error.ValidationError, ~r/Poll trigger/, fn ->
      RuntimeFixtures.spec(%{trigger: %{checkpoint: nil}})
    end

    assert_raise Connect.Error.ValidationError, ~r/Unknown auth profile/, fn ->
      RuntimeFixtures.build_spec(
        triggers: [Map.merge(RuntimeFixtures.trigger_attrs(), %{auth_profile: :missing})]
      )
    end

    assert_raise Connect.Error.ValidationError, ~r/Duplicate action ids/, fn ->
      base = RuntimeFixtures.action_attrs()
      RuntimeFixtures.build_spec(actions: [base, Map.put(base, :name, :duplicate)])
    end

    assert_raise Connect.Error.ValidationError, ~r/Unknown verb/, fn ->
      RuntimeFixtures.spec(%{action: %{verb: :teleport}})
    end

    assert_raise Connect.Error.ValidationError, ~r/Unknown data_classification/, fn ->
      RuntimeFixtures.spec(%{action: %{data_classification: :secret_thoughts}})
    end

    assert_raise Connect.Error.ValidationError, ~r/Unsupported integration field type/, fn ->
      Connect.zoi_schema_from_fields([Connect.Field.new!(%{name: :bad, type: :unknown})])
    end
  end

  test "field schemas support defaults, enums, optional fields, and nested lists" do
    schema =
      Connect.zoi_schema_from_fields([
        Connect.Field.new!(%{
          name: :state,
          type: :string,
          enum: ["open", "closed"],
          required?: true
        }),
        Connect.Field.new!(%{name: :limit, type: :integer, default: 100}),
        Connect.Field.new!(%{name: :active, type: :boolean}),
        Connect.Field.new!(%{name: :metadata, type: :map}),
        Connect.Field.new!(%{name: :labels, type: {:array, :string}, default: []})
      ])

    assert {:ok,
            %{
              state: "open",
              limit: 50,
              active: true,
              metadata: %{source: "test"},
              labels: ["bug"]
            }} =
             Zoi.parse(schema, %{
               state: "open",
               limit: 50,
               active: true,
               metadata: %{source: "test"},
               labels: ["bug"]
             })
  end

  test "field schemas enforce common limits and emit strict JSON Schema" do
    schema =
      Connect.zoi_schema_from_fields([
        Connect.Field.new!(%{
          name: :title,
          type: :string,
          required?: true,
          min_length: 3,
          max_length: 20
        }),
        Connect.Field.new!(%{
          name: :count,
          type: :integer,
          minimum: 1,
          maximum: 10
        }),
        Connect.Field.new!(%{
          name: :tags,
          type: {:array, :string},
          min_length: 1,
          max_length: 2
        })
      ])

    assert {:ok, %{title: "Valid", count: 5, tags: ["one"]}} =
             Zoi.parse(schema, %{title: "Valid", count: 5, tags: ["one"]})

    assert {:error, _errors} = Zoi.parse(schema, %{title: "No", count: 11, tags: []})

    json_schema = Connect.Schema.to_json_schema(schema)

    assert %{
             "type" => "object",
             "additionalProperties" => false,
             "properties" => %{
               "title" => %{"minLength" => 3, "maxLength" => 20},
               "count" => %{"minimum" => 1, "maximum" => 10},
               "tags" => %{"minItems" => 1, "maxItems" => 2}
             }
           } = json_schema

    assert Connect.Schema.strict_object?(json_schema)
    assert byte_size(Connect.Schema.digest(json_schema)) == 64
  end

  test "field constraints reject incompatible types" do
    assert_raise Connect.Error.ValidationError, ~r/Field constraint/, fn ->
      Connect.zoi_schema_from_fields([
        Connect.Field.new!(%{name: :bad, type: :boolean, min_length: 1})
      ])
    end
  end
end
