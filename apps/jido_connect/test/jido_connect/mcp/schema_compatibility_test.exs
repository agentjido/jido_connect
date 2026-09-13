defmodule Jido.Connect.MCP.SchemaCompatibilityTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.MCP.SchemaCompatibility

  @required %{
    "type" => "object",
    "properties" => %{
      "action" => %{"type" => "string", "enum" => ["get", "list"]},
      "position" => %{
        "anyOf" => [
          %{"type" => "number"},
          %{"type" => "string", "const" => "top"},
          %{"type" => "string", "const" => "bottom"}
        ]
      }
    },
    "required" => ["action"],
    "additionalProperties" => false
  }

  test "accepts compatible provider metadata and optional fields" do
    actual =
      @required
      |> Map.put("title", "Captured provider input")
      |> put_in(["properties", "optional"], %{
        "type" => "string",
        "description" => "A provider-owned optional field"
      })
      |> put_in(["properties", "action", "enum"], ["get", "list", "future_action"])

    assert SchemaCompatibility.compatible?(@required, actual)
  end

  test "rejects missing actions, changed field types, and new required fields" do
    refute SchemaCompatibility.compatible?(
             @required,
             put_in(@required, ["properties", "action", "enum"], ["get"])
           )

    refute SchemaCompatibility.compatible?(
             @required,
             put_in(@required, ["properties", "position", "anyOf"], [
               %{"type" => "string", "const" => "top"},
               %{"type" => "string", "const" => "bottom"}
             ])
           )

    refute SchemaCompatibility.compatible?(
             @required,
             Map.update!(@required, "required", &["new_required" | &1])
           )
  end

  test "accepts broader provider constraints and rejects narrower limits" do
    required = %{
      "type" => "object",
      "properties" => %{
        "name" => %{"type" => "string", "minLength" => 2, "maxLength" => 20},
        "count" => %{"type" => "integer", "minimum" => 1, "maximum" => 10}
      },
      "additionalProperties" => false
    }

    broader =
      required
      |> Map.put("additionalProperties", true)
      |> put_in(["properties", "name", "minLength"], 1)
      |> put_in(["properties", "name", "maxLength"], 30)
      |> put_in(["properties", "count", "minimum"], 0)
      |> put_in(["properties", "count", "maximum"], 20)

    assert SchemaCompatibility.compatible?(required, broader)

    refute SchemaCompatibility.compatible?(
             required,
             put_in(required, ["properties", "name", "maxLength"], 10)
           )
  end

  test "rejects unsupported validation keywords at every schema level" do
    narrower =
      put_in(@required, ["properties", "action", "allOf"], [
        %{"enum" => ["get"]}
      ])

    refute SchemaCompatibility.compatible?(@required, narrower)

    refute SchemaCompatibility.compatible?(
             @required,
             Map.put(@required, "not", %{"required" => ["action"]})
           )

    refute SchemaCompatibility.compatible?(
             @required,
             Map.put(@required, "oneOf", [%{"type" => "object"}])
           )

    refute SchemaCompatibility.compatible?(Map.put(@required, "allOf", [%{}]), @required)
  end

  test "accepts annotation-only metadata" do
    actual =
      @required
      |> Map.put("$schema", "https://json-schema.org/draft/2020-12/schema")
      |> Map.put("description", "Provider input")
      |> put_in(["properties", "action", "default"], "get")

    assert SchemaCompatibility.compatible?(@required, actual)
  end

  test "rejects narrower additional-property schemas" do
    required = %{"type" => "object", "additionalProperties" => true}
    restricted = %{"type" => "object", "additionalProperties" => %{"type" => "string"}}

    refute SchemaCompatibility.compatible?(required, restricted)

    assert SchemaCompatibility.compatible?(
             %{required | "additionalProperties" => false},
             restricted
           )
  end
end
