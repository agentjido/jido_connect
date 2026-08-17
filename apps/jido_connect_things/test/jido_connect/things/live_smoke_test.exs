defmodule Jido.Connect.Things.LiveSmokeTest do
  @moduledoc """
  Local, opt-in live conformance cycle for the disposable Things account.

  This suite is excluded from normal tests and refuses to run in CI. It uses
  only public provider actions. It never calls the serializer or writer
  directly. One successful cycle leaves its test to-do in Trash because V1
  does not support permanent deletion.
  """

  use ExUnit.Case, async: false

  alias Jido.Connect.{Connection, Context, CredentialLease}
  alias Jido.Connect.Things.Client

  @moduletag :live_smoke
  @moduletag :things_cloud_live
  @moduletag :things_cloud_live_write
  @moduletag timeout: 600_000

  @expected_email "mike+things@epicfirm.com"
  @live_gate "I_UNDERSTAND_THIS_TEST_USES_THE_UNOFFICIAL_THINGS_CLOUD_API"
  @write_gate "I_UNDERSTAND_THIS_TEST_WRITES_TO_THE_DISPOSABLE_THINGS_ACCOUNT"
  @high_risk_gate "I_UNDERSTAND_THIS_TEST_REPLACES_PRIVATE_NOTES"
  @destructive_gate "I_UNDERSTAND_THIS_TEST_MOVES_DISPOSABLE_TASKS_TO_TRASH"

  setup_all do
    require_local_run!()
    require_gate!("JIDO_CONNECT_THINGS_LIVE_ENABLED", @live_gate)
    require_gate!("JIDO_CONNECT_THINGS_LIVE_WRITE_ENABLED", @write_gate)
    require_gate!("JIDO_CONNECT_THINGS_LIVE_HIGH_RISK_ENABLED", @high_risk_gate)
    require_gate!("JIDO_CONNECT_THINGS_LIVE_DESTRUCTIVE_ENABLED", @destructive_gate)

    email = required_env!("WAYFINDER_THINGS_TEST_EMAIL")
    password = required_env!("WAYFINDER_THINGS_TEST_PASSWORD")
    expected_email = required_env!("WAYFINDER_THINGS_TEST_EXPECTED_EMAIL")

    assert email == @expected_email
    assert expected_email == @expected_email

    {context, lease} = runtime_contract(email, password)

    options = [
      context: context,
      credential_lease: lease,
      verification_attempts: 5,
      verification_delay_ms: 500
    ]

    assert {:ok, client} = Client.from_runtime(context, lease)
    assert {:ok, account} = Client.verify_account(client)
    assert account.email == @expected_email
    assert account.status == "SYAccountStatusActive"
    assert account.issues in [nil, []]

    assert {:ok, history} = Client.history(client, account.history_key)
    assert history.schema == 301
    assert is_integer(history.head) and history.head >= 0

    {:ok, options: options, delay_ms: bounded_delay()}
  end

  test "public V1 actions pass one live disposable-account cycle", context do
    options = context.options
    delay_ms = context.delay_ms
    run_id = "#{System.system_time(:second)}-#{String.slice(random_id(), 0, 6)}"

    assert {:ok, %{freshness: %{provider_head: head}}} =
             Jido.Connect.Things.invoke(
               "things.todo.list",
               %{view: "all", limit: 1},
               options
             )

    assert is_integer(head) and head >= 0

    for action_id <- [
          "things.project.list",
          "things.heading.list",
          "things.area.list",
          "things.tag.list"
        ] do
      assert {:ok, %{freshness: %{provider_head: reference_head}}} =
               Jido.Connect.Things.invoke(action_id, %{}, options)

      assert is_integer(reference_head) and reference_head >= head
    end

    reconcile_prior_canaries!(options, delay_ms)

    create_input = %{
      title: "Jido Connect live #{run_id}",
      notes: "",
      schedule: "inbox",
      tag_ids: []
    }

    assert {:ok, prepared_create} = prepare("things.todo.create", create_input, options)
    id = prepared_create.action.preview.target_id
    assert {:ok, _receipt} = commit_change(prepared_create, create_input, options)
    pause(delay_ms)

    todo = get!(id, options)
    assert todo.title == create_input.title
    assert todo.schedule == "inbox"

    todo =
      change!(
        "things.todo.update",
        todo,
        %{title: "Jido Connect updated #{run_id}"},
        options,
        delay_ms
      )

    todo =
      change!(
        "things.todo.update",
        todo,
        %{notes: "Jido Connect note #{run_id}"},
        options,
        delay_ms
      )

    todo =
      change!(
        "things.todo.update",
        todo,
        %{notes: "Jido Connect replacement #{run_id}"},
        options,
        delay_ms
      )

    todo = change!("things.todo.schedule", todo, %{schedule: "today"}, options, delay_ms)

    deadline = Date.utc_today() |> Date.add(14) |> Date.to_iso8601()

    todo =
      change!("things.todo.deadline.set", todo, %{deadline: deadline}, options, delay_ms)

    todo = change!("things.todo.deadline.clear", todo, %{}, options, delay_ms)
    todo = change!("things.todo.tags.set", todo, %{tag_ids: []}, options, delay_ms)
    todo = change!("things.todo.move", todo, %{}, options, delay_ms)
    todo = change!("things.todo.complete", todo, %{}, options, delay_ms)
    assert todo.status == "completed"
    todo = change!("things.todo.reopen", todo, %{}, options, delay_ms)
    assert todo.status == "open"
    todo = change!("things.todo.cancel", todo, %{}, options, delay_ms)
    assert todo.status == "canceled"
    todo = change!("things.todo.reopen", todo, %{}, options, delay_ms)
    todo = change!("things.todo.trash", todo, %{}, options, delay_ms)
    assert todo.in_trash
    todo = change!("things.todo.restore", todo, %{}, options, delay_ms)
    refute todo.in_trash
    todo = change!("things.todo.trash", todo, %{}, options, delay_ms)
    assert todo.in_trash

    assert {:ok, %{todo: exact}} =
             Jido.Connect.Things.invoke("things.todo.get", %{id: id}, options)

    assert exact.id == id
    assert exact.in_trash

    assert_no_active_canaries!(options)
  end

  defp change!(action_id, todo, changes, options, delay_ms) do
    input =
      %{id: todo.id, expected_modified_at: todo.expected_modified_at}
      |> Map.merge(changes)

    assert {:ok, prepared} = prepare(action_id, input, options)
    assert {:ok, _receipt} = commit_change(prepared, input, options)
    pause(delay_ms)
    get!(todo.id, options)
  end

  defp reconcile_prior_canaries!(options, delay_ms) do
    assert {:ok, %{todos: todos}} =
             Jido.Connect.Things.invoke(
               "things.todo.search",
               %{query: "Jido Connect", view: "all", limit: 100},
               options
             )

    todos
    |> Enum.filter(&(live_canary?(&1) and not &1.in_trash))
    |> Enum.each(fn todo ->
      trashed = change!("things.todo.trash", todo, %{}, options, delay_ms)
      assert trashed.in_trash
    end)
  end

  defp assert_no_active_canaries!(options) do
    assert {:ok, %{todos: todos}} =
             Jido.Connect.Things.invoke(
               "things.todo.search",
               %{query: "Jido Connect", view: "all", limit: 100},
               options
             )

    refute Enum.any?(todos, &(live_canary?(&1) and not &1.in_trash))
  end

  defp live_canary?(todo) do
    String.starts_with?(todo.title, ["Jido Connect live ", "Jido Connect updated "])
  end

  defp prepare(action_id, input, options) do
    Jido.Connect.Things.prepare(action_id, input, options)
  end

  defp commit_change(prepared, input, options) do
    commit_options =
      options ++
        [
          commit?: true,
          high_risk?: true,
          destructive?: true,
          execution_authorization: %{plan_id: prepared.action.id},
          authorization_validator: &authorize/4
        ]

    with {:ok, %{receipt: receipt}} <-
           Jido.Connect.Things.commit(prepared, input, commit_options) do
      assert receipt.delivery == "confirmed"
      assert receipt.verified
      {:ok, receipt}
    end
  end

  defp get!(id, options) do
    assert {:ok, %{todo: todo}} =
             Jido.Connect.Things.invoke("things.todo.get", %{id: id}, options)

    todo
  end

  defp authorize(%{plan_id: id}, %{id: id}, _context, _validator_context), do: :ok
  defp authorize(_evidence, _prepared, _context, _validator_context), do: :error

  defp runtime_contract(email, password) do
    connection =
      Connection.new!(%{
        id: "things-live-disposable",
        provider: :things,
        profile: :things_cloud_password,
        tenant_id: "things-live",
        owner_type: :app_user,
        owner_id: "things-live",
        subject: %{email: email},
        status: :connected,
        credential_ref: "things-live-disposable",
        scopes: [],
        metadata: %{endpoint: Client.production_endpoint()}
      })

    context =
      Context.new!(%{
        tenant_id: "things-live",
        actor: %{type: :user, id: "things-live"},
        connection: connection,
        claims: %{},
        metadata: %{}
      })

    lease =
      CredentialLease.from_connection!(
        connection,
        %{email: email, password: password},
        expires_at: DateTime.add(DateTime.utc_now(), 3_600, :second)
      )

    {context, lease}
  end

  defp require_local_run! do
    assert System.get_env("CI") in [nil, ""], "The Things live suite refuses to run in CI"
  end

  defp require_gate!(name, value) do
    assert System.get_env(name) == value, "Set the exact #{name} acknowledgement"
  end

  defp required_env!(name) do
    case System.get_env(name) do
      value when is_binary(value) and value != "" -> value
      _value -> flunk("Set #{name} for the disposable Things account")
    end
  end

  defp bounded_delay do
    case Integer.parse(System.get_env("JIDO_CONNECT_THINGS_LIVE_DELAY_MS") || "1000") do
      {value, ""} when value in 500..5_000 -> value
      _value -> flunk("JIDO_CONNECT_THINGS_LIVE_DELAY_MS must be from 500 to 5000")
    end
  end

  defp pause(delay_ms), do: Process.sleep(delay_ms)
  defp random_id, do: Jido.Connect.Things.Identifier.new()
end
