defmodule Jido.Connect.Things.WriteWire do
  @moduledoc """
  Deterministic serializers for the observed Things Cloud schema-301 format.

  This first slice can create one open Inbox `Task6` object or change only its
  title and notes. It cannot serialize destructive or structural operations.
  """

  alias Jason.OrderedObject
  alias Jido.Connect.Things.WriteWire.Validation

  @schema 301

  defmodule Operation do
    @moduledoc false
    @enforce_keys [:id, :action, :entity, :payload, :body, :body_sha256, :operation_sha256]
    defstruct @enforce_keys
  end

  def schema, do: @schema

  def create(id, title, notes, timestamp) do
    with {:ok, id} <- Validation.identifier(id),
         {:ok, title} <- Validation.title(title),
         {:ok, notes} <- Validation.notes(if(is_nil(notes), do: "", else: notes)),
         {:ok, timestamp} <- Validation.timestamp(timestamp) do
      payload =
        ordered([
          {"tp", 0},
          {"sr", nil},
          {"dds", nil},
          {"rt", []},
          {"rmd", nil},
          {"ss", 0},
          {"tr", false},
          {"dl", []},
          {"icp", false},
          {"st", 0},
          {"ar", []},
          {"tt", title},
          {"do", 0},
          {"lai", nil},
          {"tir", nil},
          {"tg", []},
          {"agr", []},
          {"ix", 0},
          {"cd", timestamp},
          {"lt", false},
          {"icc", 0},
          {"md", nil},
          {"ti", 0},
          {"dd", nil},
          {"ato", nil},
          {"nt", note(notes)},
          {"icsd", nil},
          {"pr", []},
          {"rp", nil},
          {"acrd", nil},
          {"sp", nil},
          {"sb", 0},
          {"rr", nil},
          {"xx", ordered([{"sn", ordered([])}, {"_t", "oo"}])}
        ])

      operation(id, 0, payload)
    end
  end

  def update(id, input, timestamp) when is_map(input) do
    with {:ok, id} <- Validation.identifier(id),
         {:ok, attrs} <- Validation.changes(input),
         {:ok, timestamp} <- Validation.timestamp(timestamp),
         {:ok, fields} <- update_fields(attrs) do
      operation(id, 1, ordered(fields ++ [{"md", timestamp}]))
    end
  end

  def verify(%Operation{} = operation) do
    with {:ok, rebuilt} <- operation(operation.id, operation.action, operation.payload) do
      if rebuilt.body == operation.body and rebuilt.body_sha256 == operation.body_sha256 and
           rebuilt.operation_sha256 == operation.operation_sha256 do
        :ok
      else
        {:error, :wire_operation_changed}
      end
    end
  end

  defp update_fields(attrs) do
    Enum.reduce_while(attrs, {:ok, []}, fn
      {:title, value}, {:ok, fields} ->
        case Validation.title(value) do
          {:ok, title} -> {:cont, {:ok, fields ++ [{"tt", title}]}}
          {:error, _error} = error -> {:halt, error}
        end

      {:notes, value}, {:ok, fields} ->
        case Validation.notes(value) do
          {:ok, notes} -> {:cont, {:ok, fields ++ [{"nt", note(notes)}]}}
          {:error, _error} = error -> {:halt, error}
        end
    end)
  end

  defp operation(id, action, payload) when action in [0, 1] do
    envelope = ordered([{"t", action}, {"e", "Task6"}, {"p", payload}])

    with {:ok, body} <- Jason.encode(ordered([{id, envelope}])) do
      body_sha256 = sha256(body)

      {:ok,
       %Operation{
         id: id,
         action: action,
         entity: "Task6",
         payload: payload,
         body: body,
         body_sha256: body_sha256,
         operation_sha256: sha256([id, Integer.to_string(action), body_sha256])
       }}
    end
  end

  defp note(text) do
    ordered([
      {"_t", "tx"},
      {"ch", :erlang.crc32(text)},
      {"v", text},
      {"t", 1}
    ])
  end

  defp ordered(values), do: OrderedObject.new(values)

  defp sha256(value) do
    value
    |> IO.iodata_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
