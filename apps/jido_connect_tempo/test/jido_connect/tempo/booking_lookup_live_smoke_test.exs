defmodule Jido.Connect.Tempo.BookingLookupLiveSmokeTest do
  @moduledoc """
  Live smoke checks of the booking lookup against the Atlassian test site:
  the site's work attributes and the account candidates of the test project.

      MIX_ENV=test mix do --app jido_connect_tempo test --include live_smoke \\
        test/jido_connect/tempo/booking_lookup_live_smoke_test.exs

  The account checks hold on the accounts of the test data alone:
  JCL-PROJECT (`TEMPO_ACCOUNT_ID`, the default link), JCL-SECONDARY and the
  closed JCL-CLOSED, linked to `TEMPO_JIRA_PROJECT_ID`, and the global
  JCL-GLOBAL. The site is shared with real users, and Tempo returns their
  global accounts next to these; the checks assert nothing about those
  accounts beyond that the read succeeds.

  The work attribute checks need the five test attributes `_JclPhase_`
  (STATIC_LIST with the labels analysis, build and review), `_JclBillable_`
  (CHECKBOX), `_JclHours_` (INPUT_NUMERIC), `_JclAccount_` (ACCOUNT) and
  `_JclNote_` (INPUT_FIELD). They exist on the site only around a run: the
  seed script `tempo_attributes.py up` creates them, required unless
  `--optional`, with `_JclNote_` optional in both modes, and gives the
  seeded worklog of October 1, 2026 the values build, true, 1.5,
  JCL-PROJECT and `JCL live note`; `down` deletes them. These checks run
  only with `TEMPO_WORK_ATTRIBUTES` set to the mode of the run, `required`
  or `optional`. The attribute check compares with that configured form and
  names the recording after the mode: `work_attributes_required` or
  `work_attributes_optional`. The value check records
  `work_attribute_values` in the optional mode only, so the recording
  belongs to the window of `work_attributes_optional`, whose stored values
  of `_JclPhase_` it holds; a run in the required mode leaves it alone.

  Recordings leave out what the shared site returns besides the test data
  (see `LiveTempo.site_data/2`). The test user's account ID comes from Jira
  `GET /rest/api/3/myself`; that call and the direct Tempo reads that the
  checks compare against are not recorded. ExUnit prints the arguments of a
  failing call, so checks that involve the account ID or the site's other
  data compute a boolean first and fail with a fixed message.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  import Jido.Connect.Tempo.TestSupport.LiveTempo,
    only: [
      context!: 3,
      invoke: 5,
      link_account_id: 1,
      ok!: 2,
      raw_get!: 3,
      raw_get!: 4,
      raw_worklogs!: 3,
      request!: 3,
      site_data: 2
    ]

  alias Jido.Connect.Error
  alias Jido.Connect.Tempo.Client.Transport

  @recorder {:jido_connect_tempo, :tempo_req_options}
  @jira ["JIRA_SITE", "JIRA_EMAIL", "JIRA_API_TOKEN"]
  @attributes %{
    "_JclPhase_" => {"STATIC_LIST", "JCL live: phase"},
    "_JclBillable_" => {"CHECKBOX", "JCL live: billable"},
    "_JclHours_" => {"INPUT_NUMERIC", "JCL live: estimate hours"},
    "_JclAccount_" => {"ACCOUNT", "JCL live: account"},
    "_JclNote_" => {"INPUT_FIELD", "JCL live: note"}
  }
  @attribute_keys @attributes |> Map.keys() |> Enum.sort()
  # Optional in both modes, so a required window never forces other users
  # of the site to fill it in.
  @always_optional ["_JclNote_"]
  @accounts %{
    "JCL-PROJECT" => {"JCL live: project account", "OPEN", false},
    "JCL-SECONDARY" => {"JCL live: second project account", "OPEN", false},
    "JCL-CLOSED" => {"JCL live: closed project account", "CLOSED", false},
    "JCL-GLOBAL" => {"JCL live: global account", "OPEN", true}
  }

  @tag env!([
         "TEMPO_OAUTH_ACCESS_TOKEN",
         "TEMPO_API_ORIGIN",
         "TEMPO_JIRA_PROJECT_ID",
         "TEMPO_ACCOUNT_ID" | @jira
       ])
  test "the account candidates of the test project match the seeded accounts", %{env: env} do
    token = env["TEMPO_OAUTH_ACCESS_TOKEN"]
    project = String.to_integer(env["TEMPO_JIRA_PROJECT_ID"])
    context = context!(env, :oauth2_user, ["tempo.accounts.read"])
    raw = raw_test_accounts!(env, token, project)

    LiveSmoke.record(@recorder, :tempo, "accounts_for_project",
      transform: site_data(raw, @attribute_keys)
    )

    result =
      ok!(
        invoke(
          context,
          :oauth2_user,
          token,
          %{project_id: project},
          "tempo.account.list_for_project"
        ),
        "the account read"
      )

    assert result.project_id == project
    accounts = Enum.filter(result.accounts, &Map.has_key?(@accounts, &1.key))

    assert accounts |> Enum.map(& &1.key) |> Enum.sort() == @accounts |> Map.keys() |> Enum.sort()

    for account <- accounts do
      {name, status, global} = @accounts[account.key]
      assert {account.name, account.status, account.global} == {name, status, global}

      direct = Map.fetch!(raw, Integer.to_string(account.id))

      assert {account.id, account.key, account.name, account.status, account.global} ==
               {direct["id"], direct["key"], direct["name"], direct["status"], direct["global"]}

      assert [link] = account.links
      assert {link.scope_type, link.scope_id} == {"PROJECT", project}
      assert link.default == (account.key == "JCL-PROJECT")
      assert if(account.global, do: link.id == 0, else: link.id > 0)
    end

    default = Enum.find(accounts, &(&1.key == "JCL-PROJECT"))
    assert Integer.to_string(default.id) == env["TEMPO_ACCOUNT_ID"]

    defaults = for account <- result.accounts, link <- account.links, link.default, do: link
    one_default? = length(defaults) == 1
    assert one_default?, "the project does not have exactly one default link"
  end

  @tag env!(["TEMPO_API_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "an unknown account gets Tempo's not-found answer", %{env: env} do
    request = request!(env, :api_token, env["TEMPO_API_TOKEN"])
    LiveSmoke.record(@recorder, :tempo, "account_not_found")

    assert {:error, %Error.ProviderError{reason: :not_found, status: 404, details: details}} =
             Transport.get(request, "/4/accounts/999999")

    assert details.message == "Invalid account"
  end

  # Needs the five test attributes, which exist only in a work-attribute
  # window; see the moduledoc.
  @tag env!(["TEMPO_WORK_ATTRIBUTES", "TEMPO_OAUTH_ACCESS_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "the work attributes match the configured time-entry form", %{env: env} do
    token = env["TEMPO_OAUTH_ACCESS_TOKEN"]
    context = context!(env, :oauth2_user, ["tempo.worklogs.read"])
    mode = env["TEMPO_WORK_ATTRIBUTES"]
    required = required!(env)
    raw = raw_test_attributes!(env, token)

    LiveSmoke.record(@recorder, :tempo, "work_attributes_" <> mode,
      transform: site_data(%{}, @attribute_keys)
    )

    result =
      ok!(invoke(context, :oauth2_user, token, %{}, "tempo.work_attribute.list"), "the read")

    attributes = Enum.filter(result.attributes, &(&1.key in @attribute_keys))
    assert attributes |> Enum.map(& &1.key) |> Enum.sort() == @attribute_keys

    for attribute <- attributes do
      direct = raw[attribute.key]
      assert {attribute.type, attribute.name} == @attributes[attribute.key]
      assert attribute.required == (required and attribute.key not in @always_optional)

      assert {attribute.key, attribute.name, attribute.type, attribute.required, attribute.self} ==
               {direct["key"], direct["name"], direct["type"], direct["required"], direct["self"]}
    end

    phase = Enum.find(attributes, &(&1.key == "_JclPhase_"))
    assert Enum.map(phase.values, & &1.value) == raw["_JclPhase_"]["values"]
    assert Enum.map(phase.values, & &1.label) == ["analysis", "build", "review"]
    assert Enum.all?(phase.values, &(&1.label == raw["_JclPhase_"]["names"][&1.value]))

    assert Enum.all?(attributes, &(&1.type == "STATIC_LIST" or &1.values == nil))
    refute Enum.any?(result.incomplete, &(&1.key in @attribute_keys))

    consistent? = result.complete == (result.incomplete == [])
    assert consistent?, "complete does not match the incomplete requirements"
  end

  # Needs the five test attributes; see the moduledoc. Records only in the
  # optional mode. The worklog read is recorded after the attribute and
  # account reads, which are not.
  @tag env!([
         "TEMPO_WORK_ATTRIBUTES",
         "TEMPO_API_TOKEN",
         "TEMPO_API_ORIGIN",
         "TEMPO_JIRA_PROJECT_ID" | @jira
       ])
  test "the seeded worklog stores the value each attribute type takes", %{env: env} do
    token = env["TEMPO_API_TOKEN"]
    project = String.to_integer(env["TEMPO_JIRA_PROJECT_ID"])
    scopes = ["tempo.worklogs.read", "tempo.accounts.read"]
    context = context!(env, :api_token, scopes)
    day = %{from: "2026-10-01", to: "2026-10-01"}

    attributes =
      ok!(invoke(context, :api_token, token, %{}, "tempo.work_attribute.list"), "the read")

    accounts =
      ok!(
        invoke(
          context,
          :api_token,
          token,
          %{project_id: project},
          "tempo.account.list_for_project"
        ),
        "the account read"
      )

    unless required!(env) do
      LiveSmoke.record(@recorder, :tempo, "work_attribute_values",
        transform: site_data(%{}, @attribute_keys)
      )
    end

    worklogs =
      ok!(invoke(context, :api_token, token, day, "tempo.worklogs.list_own"), "the read")

    values =
      for worklog <- worklogs.worklogs,
          value <- worklog.work_attributes,
          value.key in @attribute_keys,
          do: {worklog.tempo_worklog_id, value.key, value.value}

    assert values |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length() == 1,
           "not exactly one worklog of October 1 carries the test attributes"

    stored = Map.new(values, fn {_id, key, value} -> {key, value} end)
    assert stored |> Map.keys() |> Enum.sort() == @attribute_keys

    phase = Enum.find(attributes.attributes, &(&1.key == "_JclPhase_"))
    assert %{label: "build"} = Enum.find(phase.values, &(&1.value == stored["_JclPhase_"]))

    IO.puts("CHECKBOX value: #{inspect(stored["_JclBillable_"])}")
    IO.puts("INPUT_NUMERIC value: #{inspect(stored["_JclHours_"])}")
    IO.puts("INPUT_FIELD value: #{inspect(stored["_JclNote_"])}")
    assert stored["_JclBillable_"] == "true"
    assert stored["_JclHours_"] == "1.5"
    assert stored["_JclNote_"] == "JCL live note"

    project_account = Enum.find(accounts.accounts, &(&1.key == "JCL-PROJECT"))
    assert stored["_JclAccount_"] == project_account.key
    refute stored["_JclAccount_"] in [project_account.name, Integer.to_string(project_account.id)]

    direct =
      for worklog <- raw_worklogs!(env, token, day),
          value <- get_in(worklog, ["attributes", "values"]) || [],
          value["key"] in @attribute_keys,
          do: {worklog["tempoWorklogId"], value["key"], value["value"]}

    assert Enum.sort(values) == Enum.sort(direct)
  end

  # The mode in which the test attributes exist for this run.
  defp required!(env) do
    case env["TEMPO_WORK_ATTRIBUTES"] do
      "required" -> true
      "optional" -> false
      _other -> flunk("TEMPO_WORK_ATTRIBUTES must be required or optional")
    end
  end

  # The test accounts among the project's candidates, read directly,
  # outside the package and the recorder, by ID as a string.
  defp raw_test_accounts!(env, token, project) do
    %{"results" => links} =
      raw_get!(env, token, "/4/account-links/project/#{project}", includeGlobalAccounts: true)

    for link <- links,
        id = link_account_id(link),
        account = raw_get!(env, token, "/4/accounts/" <> id),
        Map.has_key?(@accounts, account["key"]),
        into: %{},
        do: {id, account}
  end

  # The five test attributes, read directly in one page, by key.
  defp raw_test_attributes!(env, token) do
    case raw_get!(env, token, "/4/work-attributes", offset: 0, limit: 1000) do
      %{"results" => results, "metadata" => metadata} when not is_map_key(metadata, "next") ->
        for %{"key" => key} = attribute <- results, key in @attribute_keys, into: %{} do
          {key, attribute}
        end

      _other ->
        flunk("the direct work attribute read did not return one complete page")
    end
  end
end
