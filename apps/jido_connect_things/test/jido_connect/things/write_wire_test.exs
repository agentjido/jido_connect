defmodule Jido.Connect.Things.WriteWireTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
  alias Jido.Connect.Things.WriteWire

  @id "VJ1edXTP9q3PmFDUuy8EQh"
  @timestamp 1_770_000_000.25

  test "serializes the observed schema-301 open Inbox create shape" do
    assert WriteWire.schema() == 301
    assert {:ok, operation} = WriteWire.create(@id, "Conservative canary", "Note", @timestamp)

    assert operation.action == 0
    assert operation.entity == "Task6"

    assert operation.body_sha256 ==
             "0fcde8fa233df3963c435d2f09dedd08fce1f11143b9ca15ea1f41d69ebf4634"

    assert operation.operation_sha256 ==
             "74100ffe5ba924dbe2bd80790fe6e2ee2055a411f4e6cc0111806fdc2786dabd"

    assert :ok = WriteWire.verify(operation)

    assert %{
             @id => %{
               "t" => 0,
               "e" => "Task6",
               "p" => payload
             }
           } = Jason.decode!(operation.body)

    assert payload["tp"] == 0
    assert payload["ss"] == 0
    assert payload["st"] == 0
    assert payload["tr"] == false
    assert payload["ar"] == []
    assert payload["pr"] == []
    assert payload["agr"] == []
    assert payload["tt"] == "Conservative canary"
    assert payload["cd"] == @timestamp

    assert payload["nt"] == %{
             "_t" => "tx",
             "ch" => :erlang.crc32("Note"),
             "v" => "Note",
             "t" => 1
           }
  end

  test "serializes title and notes updates only with stable hashes" do
    input = %{title: "New title", notes: "New notes"}

    assert {:ok, first} = WriteWire.update(@id, input, @timestamp)
    assert {:ok, second} = WriteWire.update(@id, input, @timestamp)
    assert first.body == second.body
    assert first.body_sha256 == second.body_sha256
    assert first.body_sha256 == "b2bb5966f6617dcb08a1da04db0dce76fa465c23bc386c5eb90b88e568e070fa"
    assert first.operation_sha256 == second.operation_sha256

    assert first.operation_sha256 ==
             "ae7c40f090359e8b43066fe7acaf524eacb8bbb25664022b4e4f57dec2621ec2"

    assert %{
             @id => %{
               "t" => 1,
               "e" => "Task6",
               "p" => %{"tt" => "New title", "nt" => note, "md" => @timestamp}
             }
           } = Jason.decode!(first.body)

    assert note["v"] == "New notes"
  end

  test "rejects empty changes, unsafe IDs, and text outside the contract" do
    assert {:error, %Error.ValidationError{reason: :no_changes}} =
             WriteWire.update(@id, %{}, @timestamp)

    assert {:error, %Error.ValidationError{reason: :unsafe_identifier}} =
             WriteWire.create("bad-id", "Title", nil, @timestamp)

    assert {:error, %Error.ValidationError{reason: :contains_newline}} =
             WriteWire.create(@id, "Line one\nLine two", nil, @timestamp)

    assert {:error, %Error.ValidationError{reason: :too_long}} =
             WriteWire.create(@id, String.duplicate("a", 2_001), nil, @timestamp)

    assert {:error, %Error.ValidationError{reason: :too_long}} =
             WriteWire.create(@id, "Title", String.duplicate("n", 100_001), @timestamp)

    assert {:error, %Error.ValidationError{reason: :must_be_string}} =
             WriteWire.create(@id, "Title", false, @timestamp)
  end

  test "rejects every field outside the V1 Task6 boundary" do
    for attrs <- [
          %{recurrence: %{}},
          %{alarm_time_offset: 60},
          %{position: 1},
          %{today_position: 1},
          %{entity: "Task7"},
          %{raw: %{"p" => %{}}}
        ] do
      assert {:error, %Error.ValidationError{reason: :no_changes}} =
               WriteWire.update(@id, attrs, @timestamp)
    end

    assert {:error, %Error.ValidationError{reason: :must_change_together}} =
             WriteWire.update(@id, %{area_ids: []}, @timestamp)

    assert {:error, %Error.ValidationError{reason: :duplicate_identifier}} =
             WriteWire.update(@id, %{tag_ids: [@id, @id]}, @timestamp)
  end
end
