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

  test "write risk requires a mutation declaration and confirmation" do
    assert_raise Connect.Error.ValidationError,
                 ~r/Write-risk action must declare mutation/,
                 fn ->
                   RuntimeFixtures.spec(%{action: %{risk: :external_write}})
                 end

    assert_raise Connect.Error.ValidationError,
                 ~r/Mutation action must declare confirmation policy/,
                 fn ->
                   RuntimeFixtures.spec(%{
                     action: %{risk: :external_write, mutation?: true, confirmation: :none}
                   })
                 end

    assert %Connect.Spec{} =
             RuntimeFixtures.spec(%{
               action: %{
                 risk: :external_write,
                 mutation?: true,
                 confirmation: :required_for_ai
               }
             })
  end

  test "duplicate field names cannot replace an earlier schema constraint" do
    fields = [
      Connect.Field.new!(%{name: :id, type: :string, required?: true}),
      Connect.Field.new!(%{name: :id, type: :integer})
    ]

    assert_raise Connect.Error.ValidationError, ~r/Duplicate field name/, fn ->
      Connect.zoi_schema_from_fields(fields)
    end

    assert_raise Connect.Error.ValidationError, ~r/Duplicate field name/, fn ->
      Connect.ActionSpec.new!(%{RuntimeFixtures.action_attrs() | input: fields})
    end

    assert {:error, %Connect.Error.ValidationError{reason: :duplicate_field_name}} =
             Connect.ActionSpec.new(%{RuntimeFixtures.action_attrs() | output: fields})

    assert_raise Connect.Error.ValidationError, ~r/Duplicate field name/, fn ->
      Connect.TriggerSpec.new!(%{RuntimeFixtures.trigger_attrs() | config: fields})
    end

    assert {:error, %Connect.Error.ValidationError{reason: :duplicate_field_name}} =
             Connect.TriggerSpec.new(%{RuntimeFixtures.trigger_attrs() | signal: fields})

    schema_attrs = %{id: :item, fields: fields, zoi_schema: Zoi.object(%{})}

    assert_raise Connect.Error.ValidationError, ~r/Duplicate field name/, fn ->
      Connect.NamedSchema.new!(schema_attrs)
    end

    assert {:error, %Connect.Error.ValidationError{reason: :duplicate_field_name}} =
             Connect.NamedSchema.new(schema_attrs)

    spec_attrs = %{
      id: :demo,
      name: "Demo",
      auth_profiles: [RuntimeFixtures.auth_profile()],
      actions: [Map.put(RuntimeFixtures.action_attrs(), :input, fields)]
    }

    assert_raise Connect.Error.ValidationError, ~r/Duplicate field name/, fn ->
      Connect.Spec.new!(spec_attrs)
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

    assert {:ok, %{state: "open", limit: 100, labels: []}} =
             Zoi.parse(schema, %{state: "open"})
  end

  test "enum values and defaults must match the field type and limits" do
    assert_raise Connect.Error.ValidationError, ~r/Invalid field enum value/, fn ->
      Connect.zoi_schema_from_fields([
        Connect.Field.new!(%{name: :count, type: :integer, enum: ["wrong"]})
      ])
    end

    assert_raise Connect.Error.ValidationError, ~r/Invalid field enum value/, fn ->
      Connect.zoi_schema_from_fields([
        Connect.Field.new!(%{name: :count, type: :integer, minimum: 2, enum: [1, 2]})
      ])
    end

    assert_raise Connect.Error.ValidationError, ~r/Invalid field default/, fn ->
      Connect.zoi_schema_from_fields([
        Connect.Field.new!(%{name: :count, type: :integer, default: "wrong"})
      ])
    end

    assert_raise Connect.Error.ValidationError, ~r/Invalid field default/, fn ->
      Connect.zoi_schema_from_fields([
        Connect.Field.new!(%{name: :count, type: :integer, maximum: 3, default: 4})
      ])
    end

    assert_raise Connect.Error.ValidationError, ~r/Invalid field default/, fn ->
      Connect.zoi_schema_from_fields([
        Connect.Field.new!(%{name: :count, type: :integer, enum: [2, 3], default: 1})
      ])
    end

    schema =
      Connect.zoi_schema_from_fields([
        Connect.Field.new!(%{
          name: :count,
          type: :integer,
          minimum: 2,
          maximum: 3,
          enum: [2, 3],
          default: 2
        })
      ])

    assert {:ok, %{count: 2}} = Zoi.parse(schema, %{})
    assert {:ok, %{count: 3}} = Zoi.parse(schema, %{count: 3})
    assert {:error, _} = Zoi.parse(schema, %{count: 1})

    assert %{"properties" => %{"count" => %{"type" => "integer"}}} =
             Connect.Schema.to_json_schema(schema)
  end

  test "array enum values constrain each element" do
    field =
      Connect.Field.new!(%{
        name: :roles,
        type: {:array, :string},
        enum: ["read", "write"],
        default: ["read"]
      })

    schema = Connect.zoi_schema_from_fields([field])

    assert {:ok, %{roles: ["read"]}} = Zoi.parse(schema, %{})

    assert {:ok, %{roles: ["read", "write"]}} =
             Zoi.parse(schema, %{roles: ["read", "write"]})

    assert {:error, _} = Zoi.parse(schema, %{roles: ["admin"]})

    assert %{
             "properties" => %{
               "roles" => %{"type" => "array", "items" => %{"enum" => ["read", "write"]}}
             }
           } = Connect.Schema.to_json_schema(schema)

    assert_raise Connect.Error.ValidationError, ~r/Invalid field enum value/, fn ->
      Connect.zoi_schema_from_fields([
        Connect.Field.new!(%{name: :roles, type: {:array, :string}, enum: [3]})
      ])
    end

    assert_raise Connect.Error.ValidationError, ~r/Invalid field default/, fn ->
      Connect.zoi_schema_from_fields([
        Connect.Field.new!(%{
          name: :roles,
          type: {:array, :string},
          enum: ["read"],
          default: ["admin"]
        })
      ])
    end
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

  test "catalog JSON Schema accepts nested field contracts and root requirements" do
    fields = [
      Connect.Field.new!(%{
        name: :items,
        type: {:array, :map},
        required?: true,
        json_schema: %{
          "type" => "array",
          "minItems" => 1,
          "items" => %{
            "type" => "object",
            "additionalProperties" => false,
            "required" => ["id"],
            "properties" => %{"id" => %{"type" => "integer", "minimum" => 1}}
          }
        }
      }),
      Connect.Field.new!(%{name: :name, type: :string})
    ]

    schema =
      fields
      |> Connect.zoi_schema_from_fields()
      |> Connect.Schema.to_json_schema(fields, Connect.Schema.at_least_one_of([:items, :name]))

    assert get_in(schema, ["properties", "items", "items", "properties", "id"]) == %{
             "type" => "integer",
             "minimum" => 1
           }

    assert schema["anyOf"] == [
             %{"required" => ["items"]},
             %{"required" => ["name"]}
           ]
  end
end
