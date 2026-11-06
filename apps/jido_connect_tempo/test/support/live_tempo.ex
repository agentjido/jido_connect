defmodule Jido.Connect.Tempo.TestSupport.LiveTempo do
  @moduledoc false

  # Shared by the Tempo live smoke tests: builds connections, contexts and
  # requests for the test user, runs Tempo actions through `Jido.Connect`
  # with a credential lease around a live token, prepares and commits the
  # worklog create and stops a test when Tempo created a worklog it should
  # have refused, reads Tempo directly with
  # Req outside the connector and the recorder, and filters what the shared
  # test site returns besides the test data out of the recordings. A helper
  # that one test file uses stays in that file.
  #
  # ExUnit prints the arguments of a failing call. A token, the test user's
  # account ID or another user's data can be among them, so these helpers
  # fail with fixed messages that name only a step, a reason or a status.

  import ExUnit.Assertions, only: [flunk: 1]

  alias Jido.Connect.{Connection, Context, CredentialLease}
  alias Jido.Connect.Tempo
  alias Jido.Connect.Tempo.Client.Request

  @doc """
  Invokes `action` with a five-minute lease that holds `token` in the
  profile's token field.
  """
  def invoke(
        %Context{connection: connection} = context,
        profile,
        token,
        input,
        action \\ "tempo.worklogs.list_own"
      ) do
    lease =
      CredentialLease.from_connection!(connection, %{token_field(profile) => token},
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second)
      )

    Jido.Connect.invoke(Tempo, action, input, context: context, credential_lease: lease)
  end

  @doc """
  Prepares and commits `tempo.worklog.create` with direct calls denied and a
  five-minute lease that holds `token` in the profile's token field. The host
  evidence names the prepared action, and the validator accepts only that
  one.
  """
  def commit(%Context{connection: connection} = context, profile, token, input) do
    lease =
      CredentialLease.from_connection!(connection, %{token_field(profile) => token},
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second)
      )

    opts = [context: context, credential_lease: lease, direct_mutation_mode: :deny]

    with {:ok, prepared} <- Jido.Connect.prepare(Tempo, "tempo.worklog.create", input, opts) do
      Jido.Connect.commit(
        Tempo,
        prepared,
        input,
        opts ++
          [
            execution_authorization: %{prepared_action_id: prepared.id},
            authorization_validator: fn evidence, prepared, _context ->
              evidence.prepared_action_id == prepared.id
            end
          ]
      )
    end
  end

  @doc """
  Stops the test with the new ID when Tempo created a worklog for a booking
  it should have refused, so the test sends nothing more.
  """
  def stop_if_created!({:ok, %{worklog: %{tempo_worklog_id: id}}}, what),
    do: flunk("STOP: Tempo created worklog #{id} for #{what}")

  def stop_if_created!({:ok, %{"tempoWorklogId" => id}}, what),
    do: flunk("STOP: Tempo created worklog #{id} for #{what}")

  def stop_if_created!(_result, _what), do: :ok

  @doc """
  Names the reason and status of a result, never Tempo's text, which may
  quote the booking, including the test user's account ID.
  """
  def error_summary({:error, error}),
    do: "reason #{inspect(Map.get(error, :reason))}, status #{inspect(Map.get(error, :status))}"

  def error_summary({:ok, _value}), do: "a success"
  def error_summary(_other), do: "an unexpected result"

  @doc "Returns the value of a success, or fails with the step, reason and status."
  def ok!({:ok, value}, _step), do: value

  def ok!({:error, error}, step),
    do:
      flunk(
        "#{step} failed: #{inspect(Map.get(error, :reason))}, status #{inspect(Map.get(error, :status))}"
      )

  @doc "Returns a context of the test user's connection at `TEMPO_API_ORIGIN`."
  def context!(env, profile, scopes \\ ["tempo.worklogs.read"]) do
    Context.new!(%{
      tenant_id: "live",
      actor: %{id: "live", type: :app_user},
      connection: connection!(env, profile, env["TEMPO_API_ORIGIN"], scopes)
    })
  end

  @doc "Returns a connection of the test user at `origin`."
  def connection!(env, profile, origin, scopes) do
    Connection.new!(%{
      id: "tempo_live_#{profile}",
      provider: :tempo,
      profile: profile,
      tenant_id: "live",
      owner_type: :app_user,
      owner_id: "live",
      subject: %{account_id: account_id!(env)},
      status: :connected,
      scopes: scopes,
      metadata: %{api_origin: origin}
    })
  end

  @doc "Returns a transport request of the test user at `origin` or `TEMPO_API_ORIGIN`."
  def request!(env, profile, token, origin \\ nil) do
    connection = connection!(env, profile, origin || env["TEMPO_API_ORIGIN"], [])

    case Request.new(connection, %{token_field(profile) => token}) do
      {:ok, request} -> request
      {:error, error} -> flunk("Tempo request rejected: #{inspect(error.reason)}")
    end
  end

  @doc "Returns the test user's Atlassian account ID from Jira `GET /rest/api/3/myself`."
  def account_id!(env) do
    case Req.get(env["JIRA_SITE"] <> "/rest/api/3/myself",
           auth: {:basic, "#{env["JIRA_EMAIL"]}:#{env["JIRA_API_TOKEN"]}"},
           retry: false
         ) do
      {:ok, %{status: 200, body: %{"accountId" => id}}} when is_binary(id) -> id
      _other -> flunk("Jira /rest/api/3/myself did not return an account ID")
    end
  end

  @doc """
  Reads `path` at `TEMPO_API_ORIGIN` directly and returns the body of a
  200. The path can name the account ID or another user's data, so a
  failure names only the status.
  """
  def raw_get!(env, token, path, params \\ []) do
    case Req.get(env["TEMPO_API_ORIGIN"] <> path,
           auth: {:bearer, token},
           params: params,
           retry: false
         ) do
      {:ok, %{status: 200, body: body}} -> body
      {:ok, %{status: status}} -> flunk("a direct Tempo read got status #{status}")
      _other -> flunk("a direct Tempo read failed")
    end
  end

  @doc "Reads the test user's worklogs of `range` directly, in one page."
  def raw_worklogs!(env, token, %{from: from, to: to}) do
    path = "/4/worklogs/user/" <> URI.encode(account_id!(env), &URI.char_unreserved?/1)

    case raw_get!(env, token, path, from: from, to: to, offset: 0, limit: 1000) do
      %{"results" => results, "metadata" => metadata} when not is_map_key(metadata, "next") ->
        results

      _other ->
        flunk("the direct Tempo read did not return one complete page")
    end
  end

  @doc """
  Returns a `:transform` for `LiveSmoke.record/4` that keeps the test data
  and leaves out or neutralizes what else the shared site returns, in four
  places:

  - work attributes whose key is not in `attribute_keys` keep Tempo's
    structure, with a neutral key `_Other<n>_`, name, `self`, stored
    values and labels; type and required flag stay, and a field outside
    Tempo's schema is left out
  - links of accounts outside `test_accounts` are left out, and
    `metadata.count` counts the links that stay
  - reads of those accounts are not recorded
  - worklog values of attributes outside `attribute_keys` are left out

  `test_accounts` maps the IDs of the test accounts, as strings, to
  anything.
  """
  def site_data(test_accounts, attribute_keys) do
    fn
      "/4/accounts/" <> id, body ->
        if Map.has_key?(test_accounts, id), do: body, else: :skip

      "/4/account-links/project/" <> _project, %{"results" => links} = body
      when is_list(links) ->
        kept = Enum.filter(links, &Map.has_key?(test_accounts, link_account_id(&1)))

        body
        |> Map.put("results", kept)
        |> Map.update("metadata", %{}, &Map.put(&1, "count", length(kept)))

      "/4/work-attributes", %{"results" => attributes} = body when is_list(attributes) ->
        %{body | "results" => neutral_attributes(attributes, attribute_keys)}

      "/4/worklogs/" <> _rest, %{"results" => worklogs} = body when is_list(worklogs) ->
        %{body | "results" => Enum.map(worklogs, &test_values_only(&1, attribute_keys))}

      _path, body ->
        body
    end
  end

  @doc "Returns the account ID, as a string, that a link's `account.self` names."
  def link_account_id(%{"account" => %{"self" => self}}) when is_binary(self),
    do: self |> URI.parse() |> Map.get(:path, "") |> Path.basename()

  def link_account_id(_link), do: nil

  defp token_field(:api_token), do: :api_token
  defp token_field(_profile), do: :access_token

  defp neutral_attributes(attributes, keys) do
    attributes
    |> Enum.map_reduce(1, fn
      %{"key" => key} = attribute, n when is_binary(key) ->
        if key in keys, do: {attribute, n}, else: {neutral_attribute(attribute, n), n + 1}

      attribute, n ->
        {neutral_attribute(attribute, n), n + 1}
    end)
    |> elem(0)
  end

  # The fields of Tempo's WorkAttribute schema. Key, name, self and the
  # stored values and labels of a static list name or describe the
  # attribute; the n-th other attribute's i-th stored value becomes
  # `other-<n>-<i>` with the label `Other choice <i>`.
  defp neutral_attribute(attribute, n) do
    key = "_Other#{n}_"
    choices = choices(attribute, n)

    Enum.reduce(attribute, %{}, fn
      {"key", _key}, neutral ->
        Map.put(neutral, "key", key)

      {"name", _name}, neutral ->
        Map.put(neutral, "name", "Other attribute #{n}")

      {"self", self}, neutral ->
        Map.put(neutral, "self", neutral_self(self, key))

      {"values", values}, neutral when is_list(values) ->
        Map.put(neutral, "values", Enum.map(values, &elem(choices[&1], 0)))

      {"names", names}, neutral when is_map(names) ->
        Map.put(neutral, "names", Map.new(names, fn {value, _label} -> choices[value] end))

      {field, _value}, neutral when field in ["values", "names"] ->
        Map.put(neutral, field, nil)

      {field, value}, neutral when field in ["type", "required"] ->
        Map.put(neutral, field, value)

      {_field, _value}, neutral ->
        neutral
    end)
  end

  # Each stored value of the attribute, from `values` and then from
  # `names`, mapped to its neutral value and label.
  defp choices(attribute, n) do
    values = if is_list(attribute["values"]), do: attribute["values"], else: []
    names = if is_map(attribute["names"]), do: Map.keys(attribute["names"]), else: []

    (values ++ Enum.sort(names))
    |> Enum.uniq()
    |> Enum.with_index(1)
    |> Map.new(fn {value, i} -> {value, {"other-#{n}-#{i}", "Other choice #{i}"}} end)
  end

  defp neutral_self(self, key) when is_binary(self) do
    uri = URI.parse(self)
    URI.to_string(%{uri | path: "/4/work-attributes/" <> key, query: nil, fragment: nil})
  end

  defp neutral_self(_self, _key), do: nil

  defp test_values_only(%{"attributes" => %{"values" => values} = attributes} = worklog, keys)
       when is_list(values) do
    kept = Enum.filter(values, &(&1["key"] in keys))
    %{worklog | "attributes" => %{attributes | "values" => kept}}
  end

  defp test_values_only(worklog, _keys), do: worklog
end
