defmodule Jido.Connect.Tempo.Client.WorklogCreate do
  @moduledoc """
  Tempo worklog creation.

  `create/2` sends one `POST /4/worklogs` for the request's account through
  `Jido.Connect.Tempo.Client.Transport.post/3`, which never retries it. The
  body holds `authorAccountId`, `issueId`, `startDate`, `timeSpentSeconds`
  and the given `description`, `attributes`, `startTime` and
  `billableSeconds`, each as given; it never holds
  `bypassPeriodClosuresAndApprovals` or `remainingEstimateSeconds`.

  A 2xx answer is a created worklog only when it normalizes through
  `Jido.Connect.Tempo.Worklog` and names the requested author, issue, booking
  day and seconds. Otherwise the outcome is unknown: a
  `Jido.Connect.Error.ProviderError` with `delivery: :sent_outcome_unknown`
  and reason `:invalid_response`, `:invalid_worklog` or `:worklog_mismatch`,
  whose details name the Tempo ID and the fields, never a value of the
  description, the attributes or the author.

  Tempo answered a booking into an approved period with a 403 and
  `The timesheet status must be open for the period` (recorded
  2026-11-02). That answer gets reason `:period_locked`; any other 400 or
  403 keeps its status reason. A booking into a period in review or one closed in Period
  Management was not observed and may come back as `:forbidden` or
  `:bad_request`; like `:period_locked`, both are `delivery: :rejected`
  with `:do_not_retry`. The other error rules are those of
  `Jido.Connect.Tempo.Client.Response.handle/2` with `mutation?: true`.

  Tempo quotes rejected input in its error text, as in
  `Non valid time '25:00:00'`. Before an error keeps that text in
  `details.message`, the description, every attribute value and the
  author's account ID are replaced by `[redacted]`, the longest first. The
  reason is taken from the text before that.
  """

  alias Jido.Connect.Error
  alias Jido.Connect.Tempo.Client.{Request, Response, Transport}
  alias Jido.Connect.Tempo.Input.NewWorklog
  alias Jido.Connect.Tempo.Worklog

  # Tempo's answer to a booking into an approved period, recorded
  # 2026-11-02.
  @period_locked {403, "The timesheet status must be open for the period", :period_locked}

  # The fields a confirmed worklog must share with the request.
  @confirmed [:author_account_id, :issue_id, :start_date, :time_spent_seconds]

  # Input field => Tempo body field.
  @fields [
    author_account_id: "authorAccountId",
    issue_id: "issueId",
    start_date: "startDate",
    time_spent_seconds: "timeSpentSeconds",
    description: "description",
    start_time: "startTime",
    billable_seconds: "billableSeconds"
  ]

  @doc """
  Creates one worklog of the request's account.

  `attrs` is a map with the atom keys `:author_account_id`, `:issue_id`,
  `:start_date` and `:time_spent_seconds`, and optionally `:description`,
  `:attributes`, `:start_time` and `:billable_seconds`, under the rules of
  the action input. `:author_account_id` must equal the request's account.
  Any other key, a malformed value and a foreign author fail before the POST
  with a `Jido.Connect.Error.ValidationError` (`:invalid_worklog_input`) or
  a `Jido.Connect.Error.AuthError` (`:foreign_worklog_author`).
  """
  @spec create(Request.t(), map()) :: {:ok, Worklog.t()} | {:error, Error.error()}
  def create(%Request{} = request, attrs) do
    with {:ok, worklog} <- NewWorklog.parse(attrs),
         {:ok, worklog} <-
           NewWorklog.check_author(worklog, request.account_id, request.connection_id),
         {:ok, body} <-
           Transport.post(request, "/4/worklogs",
             json: body(worklog),
             reasons: [@period_locked],
             redact: redact(worklog)
           ) do
      confirm(body, worklog)
    end
  end

  # Tempo quotes rejected input in its error text, as in `Non valid time
  # '25:00:00'`. The longest value goes first, so a shorter value that is
  # part of it cannot leave the rest of it in the text.
  defp redact(worklog) do
    values = Enum.map(Map.get(worklog, :attributes, []), & &1.value)

    [worklog.author_account_id, Map.get(worklog, :description) | values]
    |> Enum.filter(&is_binary/1)
    |> Enum.sort_by(&byte_size/1, :desc)
  end

  # Tempo answered 2xx, so it may have created a worklog. Only one that
  # normalizes and matches the request counts as created.
  defp confirm(body, expected) do
    case Worklog.normalize(body) do
      {:ok, worklog} ->
        case Enum.reject(@confirmed, &(Map.fetch!(worklog, &1) == Map.fetch!(expected, &1))) do
          [] ->
            {:ok, worklog}

          fields ->
            uncertain(:worklog_mismatch, "Tempo confirmed another worklog than requested", %{
              tempo_worklog_id: worklog.tempo_worklog_id,
              mismatched_fields: fields
            })
        end

      {:error, field} ->
        uncertain(:invalid_worklog, "Tempo worklog was invalid", %{field: field})
    end
  end

  defp uncertain(reason, message, details) do
    Response.invalid_response(message, nil, reason: reason, mutation?: true, details: details)
  end

  defp body(worklog) do
    body =
      for {field, key} <- @fields, Map.has_key?(worklog, field), into: %{} do
        {key, Map.fetch!(worklog, field)}
      end

    case Map.fetch(worklog, :attributes) do
      {:ok, pairs} ->
        Map.put(body, "attributes", Enum.map(pairs, &%{"key" => &1.key, "value" => &1.value}))

      :error ->
        body
    end
  end
end
