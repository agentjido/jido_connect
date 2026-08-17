defmodule Jido.Connect.Things.IdentifierTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Things.Identifier

  test "round-trips canonical 16-byte identifiers" do
    bytes = <<0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15>>
    assert {:ok, id} = Identifier.encode(bytes)
    assert {:ok, ^bytes} = Identifier.decode(id)
    assert :ok = Identifier.validate(id)
  end

  test "rejects unsafe and non-canonical identifiers" do
    assert {:error, :empty} = Identifier.validate("")
    assert {:error, :invalid_character} = Identifier.validate("not-an-id")
    assert {:error, :wrong_length} = Identifier.encode(<<1, 2>>)
    assert {:error, :non_canonical} = Identifier.decode(nil)
  end

  test "creates a valid random identifier" do
    id = Identifier.new()
    assert :ok = Identifier.validate(id)
  end
end
