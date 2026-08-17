defmodule Jido.Connect.Things.WriteWire do
  @moduledoc """
  Deterministic serializers for the observed Things Cloud schema-301 format.

  The serializer accepts only the approved non-recurring V1 `Task6` to-do
  fields. It cannot serialize direct deletes, tombstones, recurrence, alarms,
  raw positions, or writes for any other entity.
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
    create_task(
      id,
      %{title: title, notes: if(is_nil(notes), do: "", else: notes)},
      timestamp,
      Date.utc_today()
    )
  end

  def create_task(id, input, timestamp, today) when is_map(input) and is_struct(today, Date) do
    with {:ok, id} <- Validation.identifier(id),
         {:ok, title} <- Validation.title(Map.get(input, :title)),
         {:ok, notes} <- Validation.notes(Map.get(input, :notes, "")),
         {:ok, timestamp} <- Validation.timestamp(timestamp),
         {:ok, schedule} <- schedule(Map.get(input, :schedule, "inbox"), today),
         {:ok, deadline} <- Validation.nullable_date(Map.get(input, :deadline)),
         {:ok, tag_ids} <- Validation.identifiers(Map.get(input, :tag_ids, []), :tag_ids),
         {:ok, relations} <- relations(input),
         {:ok, schedule} <-
           container_schedule(schedule, relations, Map.has_key?(input, :schedule)) do
      payload =
        ordered([
          {"tp", 0},
          {"sr", schedule.scheduled_at},
          {"dds", nil},
          {"rt", []},
          {"rmd", nil},
          {"ss", 0},
          {"tr", false},
          {"dl", []},
          {"icp", false},
          {"st", schedule.start},
          {"ar", relations.area_ids},
          {"tt", title},
          {"do", 0},
          {"lai", nil},
          {"tir", schedule.today_reference_at},
          {"tg", tag_ids},
          {"agr", relations.heading_ids},
          {"ix", 0},
          {"cd", timestamp},
          {"lt", false},
          {"icc", 0},
          {"md", nil},
          {"ti", 0},
          {"dd", deadline},
          {"ato", nil},
          {"nt", note(notes)},
          {"icsd", nil},
          {"pr", relations.project_ids},
          {"rp", nil},
          {"acrd", nil},
          {"sp", nil},
          {"sb", schedule.evening},
          {"rr", nil},
          {"xx", ordered([{"sn", ordered([])}, {"_t", "oo"}])}
        ])

      operation(id, 0, payload)
    end
  end

  def update(id, input, timestamp) when is_map(input) do
    update(id, input, timestamp, Date.utc_today())
  end

  def update(id, input, timestamp, today) when is_map(input) and is_struct(today, Date) do
    with {:ok, id} <- Validation.identifier(id),
         {:ok, attrs} <- Validation.changes(input),
         {:ok, timestamp} <- Validation.timestamp(timestamp),
         {:ok, fields} <- update_fields(attrs, today) do
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

  defp update_fields(attrs, today) do
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

      {:schedule, value}, {:ok, fields} ->
        case schedule(value, today) do
          {:ok, schedule} ->
            {:cont,
             {:ok,
              fields ++
                [
                  {"st", schedule.start},
                  {"sr", schedule.scheduled_at},
                  {"tir", schedule.today_reference_at},
                  {"sb", schedule.evening}
                ]}}

          {:error, _error} = error ->
            {:halt, error}
        end

      {:deadline, value}, {:ok, fields} ->
        case Validation.nullable_date(value) do
          {:ok, deadline} -> {:cont, {:ok, fields ++ [{"dd", deadline}]}}
          {:error, _error} = error -> {:halt, error}
        end

      {:tag_ids, value}, {:ok, fields} ->
        case Validation.identifiers(value, :tag_ids) do
          {:ok, ids} -> {:cont, {:ok, fields ++ [{"tg", ids}]}}
          {:error, _error} = error -> {:halt, error}
        end

      {:area_ids, _value}, {:ok, fields} ->
        relation_update_fields(attrs, fields)

      {:project_ids, _value}, result ->
        skip_relation_field(attrs, :area_ids, result)

      {:heading_ids, _value}, result ->
        skip_relation_field(attrs, :area_ids, result)

      {:status, value}, {:ok, fields} ->
        case status_fields(value, Keyword.get(attrs, :stopped_at)) do
          {:ok, status} -> {:cont, {:ok, fields ++ status}}
          {:error, _error} = error -> {:halt, error}
        end

      {:stopped_at, _value}, result ->
        if Keyword.has_key?(attrs, :status),
          do: {:cont, result},
          else: {:halt, validation_error(:stopped_at, :requires_status)}

      {:in_trash, value}, {:ok, fields} when is_boolean(value) ->
        {:cont, {:ok, fields ++ [{"tr", value}]}}

      {:in_trash, _value}, _result ->
        {:halt, validation_error(:in_trash, :must_be_boolean)}
    end)
  end

  defp relation_update_fields(attrs, fields) do
    values = Map.new(attrs)

    if Enum.all?([:area_ids, :project_ids, :heading_ids], &Map.has_key?(values, &1)) do
      case relations(values) do
        {:ok, relation} ->
          {:cont,
           {:ok,
            fields ++
              [
                {"pr", relation.project_ids},
                {"ar", relation.area_ids},
                {"agr", relation.heading_ids}
              ]}}

        {:error, _error} = error ->
          {:halt, error}
      end
    else
      {:halt, validation_error(:relations, :must_change_together)}
    end
  end

  defp skip_relation_field(attrs, first, result) do
    if Keyword.has_key?(attrs, first),
      do: {:cont, result},
      else: {:halt, validation_error(:relations, :must_change_together)}
  end

  defp relations(input) do
    with {:ok, area_ids} <- relation_values(input, :area_ids, :area_id),
         {:ok, project_ids} <- relation_values(input, :project_ids, :project_id),
         {:ok, heading_ids} <- relation_values(input, :heading_ids, :heading_id),
         :ok <- valid_relation_shape(area_ids, project_ids, heading_ids) do
      {:ok, %{area_ids: area_ids, project_ids: project_ids, heading_ids: heading_ids}}
    end
  end

  defp relation_values(input, plural, singular) do
    cond do
      Map.has_key?(input, plural) ->
        Validation.identifiers(Map.get(input, plural), plural, 1)

      is_binary(Map.get(input, singular)) ->
        Validation.identifiers([Map.get(input, singular)], plural, 1)

      is_nil(Map.get(input, singular)) ->
        {:ok, []}

      true ->
        validation_error(singular, :unsafe_identifier)
    end
  end

  defp valid_relation_shape(area_ids, project_ids, heading_ids) do
    cond do
      area_ids != [] and (project_ids != [] or heading_ids != []) ->
        validation_error(:relations, :area_and_project_are_mutually_exclusive)

      heading_ids != [] and project_ids == [] ->
        validation_error(:relations, :heading_requires_project)

      true ->
        :ok
    end
  end

  defp schedule("inbox", _today),
    do: {:ok, %{start: 0, scheduled_at: nil, today_reference_at: nil, evening: 0}}

  defp schedule("anytime", _today),
    do: {:ok, %{start: 1, scheduled_at: nil, today_reference_at: nil, evening: 0}}

  defp schedule("someday", _today),
    do: {:ok, %{start: 2, scheduled_at: nil, today_reference_at: nil, evening: 0}}

  defp schedule("today", today), do: dated_schedule(today, today, 0)
  defp schedule("evening", today), do: dated_schedule(today, today, 1)

  defp schedule(value, today) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> dated_schedule(date, today, 0)
      {:error, _reason} -> validation_error(:schedule, :invalid_schedule)
    end
  end

  defp schedule(_value, _today), do: validation_error(:schedule, :invalid_schedule)

  defp dated_schedule(date, today, evening) do
    with {:ok, timestamp} <- Validation.nullable_date(date) do
      start = if Date.compare(date, today) == :gt, do: 2, else: 1

      {:ok,
       %{start: start, scheduled_at: timestamp, today_reference_at: timestamp, evening: evening}}
    end
  end

  defp container_schedule(%{start: 0}, relations, true) do
    if container?(relations),
      do: validation_error(:schedule, :container_cannot_be_inbox),
      else: schedule("inbox", Date.utc_today())
  end

  defp container_schedule(%{start: 0} = schedule, relations, false) do
    if container?(relations), do: {:ok, %{schedule | start: 1}}, else: {:ok, schedule}
  end

  defp container_schedule(schedule, _relations, _explicit), do: {:ok, schedule}
  defp container?(relations), do: relations.area_ids != [] or relations.project_ids != []

  defp status_fields(value, stopped_at) when value in [:open, "open"] do
    if is_nil(stopped_at),
      do: {:ok, [{"ss", 0}, {"sp", nil}]},
      else: validation_error(:stopped_at, :must_be_nil_when_open)
  end

  defp status_fields(value, stopped_at)
       when value in [:completed, "completed", :canceled, "canceled"] do
    with {:ok, timestamp} <- Validation.timestamp(stopped_at) do
      status = if value in [:completed, "completed"], do: 3, else: 2
      {:ok, [{"ss", status}, {"sp", timestamp}]}
    end
  end

  defp status_fields(_value, _stopped_at), do: validation_error(:status, :invalid_status)

  defp validation_error(field, reason) do
    {:error,
     Jido.Connect.Error.validation("Things action input is invalid",
       reason: reason,
       subject: field
     )}
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
