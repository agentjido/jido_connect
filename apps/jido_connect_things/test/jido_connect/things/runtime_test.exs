defmodule Jido.Connect.Things.RuntimeTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.{Connection, Context, CredentialLease, Error}

  alias Jido.Connect.Things.{
    Client,
    PreparedWrite,
    Todo,
    Writer
  }

  @id "VJ1edXTP9q3PmFDUuy8EQh"
  @now ~U[2026-08-17 15:00:00Z]
  @modified_at ~U[2026-08-17 12:00:00Z]

  test "lists open Inbox to-dos through fresh provider history" do
    parent = self()

    transport = fn method, url, opts ->
      send(parent, {:request, method, url, opts})

      cond do
        String.contains?(url, "/account/") ->
          account_response("user@example.com", "history-A")

        String.ends_with?(url, "/history/history-A") ->
          history_response(1)

        String.ends_with?(url, "/history/history-A/items") ->
          page_response([task_event(@id, @modified_at)])
      end
    end

    {context, lease} = runtime_contract("connection-A", "user@example.com")

    assert {:ok, result} =
             Jido.Connect.Things.invoke("things.todo.list", %{},
               context: context,
               credential_lease: lease,
               transport: transport
             )

    assert result.view == "inbox"
    assert result.count == 1

    assert [todo] = result.todos
    assert todo.id == @id
    assert todo.title == "Existing task"
    assert todo.status == "open"
    assert todo.schedule == "inbox"

    assert result.freshness == %{
             source: "provider",
             provider_head: 1,
             state_complete: true,
             issue_count: 0
           }

    assert_received {:request, :get, _url, _opts}
    refute_received {:request, :post, _url, _opts}
  end

  test "gets, searches, and lists references through fresh provider state" do
    transport = history_event_transport(task_event(@id, @modified_at))
    {context, lease} = runtime_contract("connection-A", "user@example.com")

    options = [
      context: context,
      credential_lease: lease,
      transport: transport,
      today: ~D[2026-08-17]
    ]

    assert {:ok, %{todo: %{id: @id}}} =
             Jido.Connect.Things.invoke("things.todo.get", %{id: @id}, options)

    assert {:ok, %{count: 1, todos: [%{id: @id}]}} =
             Jido.Connect.Things.invoke(
               "things.todo.search",
               %{query: "existing", limit: 10},
               options
             )

    for {action_id, key} <- [
          {"things.project.list", :projects},
          {"things.heading.list", :headings},
          {"things.area.list", :areas},
          {"things.tag.list", :tags}
        ] do
      assert {:ok, %{count: 0} = result} =
               Jido.Connect.Things.invoke(action_id, %{}, options)

      assert Map.fetch!(result, key) == []
    end
  end

  test "fails closed when provider history stops before its declared head" do
    transport = fn _method, url, _opts ->
      cond do
        String.contains?(url, "/account/") -> account_response("user@example.com", "history-A")
        String.ends_with?(url, "/history/history-A") -> history_response(1)
        String.ends_with?(url, "/history/history-A/items") -> page_response([])
      end
    end

    {context, lease} = runtime_contract("connection-A", "user@example.com")

    assert {:error, %Error.ProviderError{reason: :incomplete_history}} =
             Jido.Connect.Things.invoke("things.todo.list", %{},
               context: context,
               credential_lease: lease,
               transport: transport
             )
  end

  test "prepare is read-only, secret-free, and has a safe create preview" do
    parent = self()
    transport = planning_transport(parent)
    {context, lease} = runtime_contract("connection-A", "user@example.com")

    assert {:ok, prepared} =
             prepare_create(context, lease, transport, %{
               title: "Create me",
               notes: "Private note"
             })

    assert prepared.action.confirmation_required?

    assert prepared.action.preview.operation == "create"
    assert prepared.action.preview.target_id == @id
    assert prepared.action.preview.before == nil
    assert prepared.action.preview.after.title == "Create me"
    assert prepared.action.preview.after.schedule == "inbox"
    assert prepared.action.preview.after.notes.length == 12
    refute inspect(prepared.action.preview) =~ "Private note"

    public = PreparedWrite.to_public_map(prepared)
    serialized = inspect(public)
    inspected_prepared = inspect(prepared)

    refute serialized =~ "secret-password"
    refute serialized =~ "history-A"
    refute serialized =~ "Private note"
    refute Map.has_key?(public.provider_plan, :body)
    refute Map.has_key?(public.provider_plan, :history_key)
    refute inspected_prepared =~ "secret-password"
    refute inspected_prepared =~ "Private note"
    refute_received {:request, :post, _url, _opts}
  end

  test "commits one exact request and verifies it with a provider read" do
    parent = self()
    transport = successful_create_transport(parent)
    {context, lease} = runtime_contract("connection-A", "user@example.com")
    input = %{title: "Create me", notes: "Private note"}

    assert {:ok, prepared} = prepare_create(context, lease, transport, input)
    flush_requests()

    assert {:ok, %{receipt: receipt}} = commit(prepared, input, context, lease, transport)
    assert receipt.action_id == "things.todo.create"
    assert receipt.external_id == @id
    assert receipt.connection_id == "connection-A"
    assert receipt.delivery == "confirmed"
    assert receipt.verified
    assert receipt.provider_head == 2

    requests = drain_requests()
    assert [{:request, :post, post_url, post_opts}] = requests_for(requests, :post)
    assert String.ends_with?(post_url, "/history/history-A/commit")
    assert Keyword.fetch!(post_opts, :params) == [{"ancestor-index", "1"}, {"_cnt", "1"}]

    refute Enum.any?(Keyword.fetch!(post_opts, :headers), fn {name, _value} ->
             name == "authorization"
           end)

    assert Enum.any?(requests_for(requests, :get), fn {:request, :get, url, _opts} ->
             String.ends_with?(url, "/history/history-A/items")
           end)
  end

  test "denies direct mutation and a guarded commit without the explicit option" do
    parent = self()
    transport = successful_create_transport(parent)
    {context, lease} = runtime_contract("connection-A", "user@example.com")
    input = %{title: "Create me"}

    assert {:error, %Error.AuthError{reason: :execution_authorization_required}} =
             Jido.Connect.Things.invoke("things.todo.create", input,
               context: context,
               credential_lease: lease,
               transport: transport,
               direct_mutation_mode: :deny
             )

    assert {:ok, prepared} = prepare_create(context, lease, transport, input)
    flush_requests()

    assert {:error, %Error.AuthError{reason: :commit_option_required}} =
             Jido.Connect.Things.commit(prepared, input,
               context: context,
               credential_lease: lease,
               transport: transport,
               now: @now,
               execution_authorization: %{plan_id: prepared.action.id},
               authorization_validator: &authorize/4
             )

    refute_received {:request, :post, _url, _opts}
  end

  test "classifies a transport failure after send as sent_outcome_unknown without retry" do
    parent = self()
    transport = failed_send_transport(parent)
    {context, lease} = runtime_contract("connection-A", "user@example.com")
    input = %{title: "Create me"}

    assert {:ok, prepared} = prepare_create(context, lease, transport, input)
    flush_requests()

    assert {:error, %Error.ProviderError{reason: :sent_outcome_unknown} = error} =
             commit(prepared, input, context, lease, transport)

    assert error.details.delivery == :sent_outcome_unknown
    requests = drain_requests()
    assert [_post] = requests_for(requests, :post)

    refute Enum.any?(requests_for(requests, :get), fn {:request, :get, url, _opts} ->
             String.ends_with?(url, "/history/history-A/items")
           end)
  end

  test "returns sent_unverified when the acknowledgement succeeds but verification does not" do
    parent = self()
    transport = unverified_create_transport(parent)
    {context, lease} = runtime_contract("connection-A", "user@example.com")
    input = %{title: "Create me"}

    assert {:ok, prepared} = prepare_create(context, lease, transport, input)
    flush_requests()

    assert {:ok, %{receipt: %{delivery: "sent_unverified", verified: false}}} =
             commit(prepared, input, context, lease, transport)

    requests = drain_requests()
    assert [_post] = requests_for(requests, :post)

    assert Enum.any?(requests_for(requests, :get), fn {:request, :get, url, _opts} ->
             String.ends_with?(url, "/items")
           end)
  end

  test "polls verification reads without sending the write again" do
    parent = self()
    transport = eventually_verified_create_transport(parent)
    {context, lease} = runtime_contract("connection-A", "user@example.com")
    input = %{title: "Create me"}

    assert {:ok, prepared} = prepare_create(context, lease, transport, input)
    flush_requests()

    assert {:ok, %{receipt: %{delivery: "confirmed", verified: true}}} =
             commit(prepared, input, context, lease, transport,
               verification_attempts: 2,
               verification_delay_ms: 0
             )

    requests = drain_requests()
    assert [_post] = requests_for(requests, :post)

    assert 2 ==
             Enum.count(requests_for(requests, :get), fn {:request, :get, url, _opts} ->
               String.ends_with?(url, "/history/history-A/items")
             end)
  end

  test "rejects an account mismatch and unsupported schema during prepare" do
    {context, lease} = runtime_contract("connection-A", "user@example.com")

    account_mismatch = fn _method, url, _opts ->
      if String.contains?(url, "/account/") do
        account_response("other@example.com", "history-A")
      else
        history_response(1)
      end
    end

    assert {:error, %Error.ProviderError{reason: :account_mismatch}} =
             prepare_create(context, lease, account_mismatch, %{title: "Create me"})

    unsupported_schema = fn _method, url, _opts ->
      cond do
        String.contains?(url, "/account/") -> account_response("user@example.com", "history-A")
        true -> history_response(1, 302)
      end
    end

    assert {:error, %Error.ProviderError{reason: :unsupported_schema}} =
             prepare_create(context, lease, unsupported_schema, %{title: "Create me"})
  end

  test "rejects an unsupported endpoint before it sends credentials with any transport" do
    parent = self()

    {context, lease} =
      runtime_contract("connection-A", "user@example.com", endpoint: "https://example.test")

    assert {:ok, client} = Client.from_runtime(context, lease)

    assert {:error, %Error.ProviderError{reason: :unsupported_endpoint}} =
             Writer.prepare(
               "things.todo.create",
               %{title: "Create me"},
               client,
               context.connection,
               id_generator: fn -> @id end,
               now: @now
             )

    transport = fn method, url, opts ->
      send(parent, {:request, method, url, opts})
      account_response("user@example.com", "history-A")
    end

    assert {:ok, injected_client} = Client.from_runtime(context, lease, transport: transport)

    assert {:error, %Error.ProviderError{reason: :unsupported_endpoint}} =
             Writer.prepare(
               "things.todo.create",
               %{title: "Create me"},
               injected_client,
               context.connection,
               id_generator: fn -> @id end,
               now: @now
             )

    refute_received {:request, _method, _url, _opts}
  end

  test "reports incomplete state for new or malformed task events" do
    {context, lease} = runtime_contract("connection-A", "user@example.com")

    variants = [
      {@id, %{"e" => "Task6", "t" => 9, "p" => %{}}},
      {@id, %{"e" => "Task6", "t" => 1, "p" => "invalid"}}
    ]

    for {id, event} <- variants do
      transport = history_event_transport(%{id => event})

      assert {:ok, %{count: 0, freshness: freshness}} =
               Jido.Connect.Things.invoke("things.todo.list", %{},
                 context: context,
                 credential_lease: lease,
                 transport: transport
               )

      refute freshness.state_complete
      assert freshness.issue_count == 1
    end

    assert {:ok, %{count: 0, freshness: freshness}} =
             Jido.Connect.Things.invoke("things.todo.list", %{},
               context: context,
               credential_lease: lease,
               transport: history_event_transport(%{@id => %{"e" => "Task7", "t" => 0}})
             )

    refute freshness.state_complete
    assert freshness.issue_count == 1
  end

  test "rejects a stale provider head before the commit send" do
    parent = self()
    counter = :counters.new(1, [])

    transport = fn method, url, opts ->
      send(parent, {:request, method, url, opts})

      cond do
        String.contains?(url, "/account/") ->
          account_response("user@example.com", "history-A")

        String.ends_with?(url, "/history/history-A") ->
          :counters.add(counter, 1, 1)
          call = :counters.get(counter, 1)
          history_response(if(call == 1, do: 1, else: 2))
      end
    end

    {context, lease} = runtime_contract("connection-A", "user@example.com")
    input = %{title: "Create me"}
    assert {:ok, prepared} = prepare_create(context, lease, transport, input)
    flush_requests()

    assert {:error, %Error.ProviderError{reason: :stale_provider_head}} =
             commit(prepared, input, context, lease, transport)

    refute_received {:request, :post, _url, _opts}
  end

  test "rejects changed body and confirmation bindings without network access" do
    parent = self()
    transport = successful_create_transport(parent)
    {context, lease} = runtime_contract("connection-A", "user@example.com")
    input = %{title: "Create me"}
    assert {:ok, prepared} = prepare_create(context, lease, transport, input)
    flush_requests()

    changed_body = %{
      prepared
      | provider_plan: %{prepared.provider_plan | body_hash: String.duplicate("0", 64)}
    }

    assert {:error, %Error.AuthError{reason: :prepared_write_changed}} =
             commit(changed_body, input, context, lease, transport)

    changed_confirmation = %{
      prepared
      | provider_plan: %{prepared.provider_plan | confirmation: "changed"}
    }

    assert {:error, %Error.AuthError{reason: :prepared_write_changed}} =
             commit(changed_confirmation, input, context, lease, transport)

    refute_received {:request, _method, _url, _opts}
  end

  test "checks update eligibility and expected_modified_at during prepare and commit" do
    parent = self()
    transport = successful_update_transport(parent, @modified_at, @modified_at)
    {context, lease} = runtime_contract("connection-A", "user@example.com")

    input = %{
      id: @id,
      expected_modified_at: DateTime.to_iso8601(@modified_at),
      title: "Updated title"
    }

    assert {:ok, prepared} =
             Jido.Connect.Things.prepare("things.todo.update", input,
               context: context,
               credential_lease: lease,
               transport: transport,
               now: @now,
               lock: &direct_lock/2
             )

    assert prepared.action.preview == %{
             operation: "update",
             target_id: @id,
             before: %{title: "Existing task"},
             after: %{title: "Updated title"},
             changed_fields: ["title"],
             expected_modified_at: DateTime.to_iso8601(@modified_at)
           }

    flush_requests()

    assert {:ok, %{receipt: %{delivery: "confirmed", external_id: @id}}} =
             commit(prepared, input, context, lease, transport)

    assert_received {:request, :post, _url, _opts}
    refute_received {:request, :post, _url, _opts}
  end

  test "prepares and commits an explicit organization action" do
    parent = self()
    transport = successful_update_transport(parent, @modified_at, @modified_at)
    {context, lease} = runtime_contract("connection-A", "user@example.com")

    input = %{
      id: @id,
      expected_modified_at: DateTime.to_iso8601(@modified_at),
      schedule: "today"
    }

    assert {:ok, prepared} =
             Jido.Connect.Things.prepare("things.todo.schedule", input,
               context: context,
               credential_lease: lease,
               transport: transport,
               now: @now,
               today: ~D[2026-08-17],
               lock: &direct_lock/2
             )

    assert prepared.action.preview.operation == "schedule"
    assert prepared.action.preview.before.schedule == "inbox"
    assert prepared.action.preview.after.schedule == "today"
    flush_requests()

    assert {:ok, %{receipt: %{action_id: "things.todo.schedule", delivery: "confirmed"}}} =
             commit(prepared, input, context, lease, transport)

    assert_received {:request, :post, _url, _opts}
    refute_received {:request, :post, _url, _opts}
  end

  test "prepares and commits an exact lifecycle transition" do
    parent = self()
    transport = successful_update_transport(parent, @modified_at, @modified_at)
    {context, lease} = runtime_contract("connection-A", "user@example.com")
    input = %{id: @id, expected_modified_at: DateTime.to_iso8601(@modified_at)}

    assert {:ok, prepared} =
             Jido.Connect.Things.prepare("things.todo.complete", input,
               context: context,
               credential_lease: lease,
               transport: transport,
               now: @now,
               lock: &direct_lock/2
             )

    assert prepared.action.preview.before.status == "open"
    assert prepared.action.preview.after.status == "completed"
    flush_requests()

    assert {:ok, %{receipt: %{action_id: "things.todo.complete", delivery: "confirmed"}}} =
             commit(prepared, input, context, lease, transport)

    assert_received {:request, :post, _url, _opts}
    refute_received {:request, :post, _url, _opts}
  end

  test "requires destructive authorization before one exact Trash commit" do
    parent = self()
    transport = successful_update_transport(parent, @modified_at, @modified_at)
    {context, lease} = runtime_contract("connection-A", "user@example.com")
    input = %{id: @id, expected_modified_at: DateTime.to_iso8601(@modified_at)}

    assert {:ok, prepared} =
             Jido.Connect.Things.prepare("things.todo.trash", input,
               context: context,
               credential_lease: lease,
               transport: transport,
               now: @now,
               lock: &direct_lock/2
             )

    assert prepared.provider_plan.risk == :destructive
    assert prepared.action.preview.before.in_trash == false
    assert prepared.action.preview.after.in_trash
    flush_requests()

    assert {:error, %Error.AuthError{reason: :destructive_confirmation_required}} =
             Jido.Connect.Things.commit(prepared, input,
               context: context,
               credential_lease: lease,
               transport: transport,
               commit?: true,
               now: @now,
               lock: &direct_lock/2,
               execution_authorization: %{plan_id: prepared.action.id},
               authorization_validator: &authorize/4
             )

    refute_received {:request, :post, _url, _opts}

    assert {:ok, %{receipt: %{action_id: "things.todo.trash", delivery: "confirmed"}}} =
             commit(prepared, input, context, lease, transport)

    assert_received {:request, :post, _url, _opts}
    refute_received {:request, :post, _url, _opts}
  end

  test "rejects stale expected_modified_at again immediately before commit" do
    parent = self()
    changed = DateTime.add(@modified_at, 60, :second)
    transport = successful_update_transport(parent, @modified_at, changed)
    {context, lease} = runtime_contract("connection-A", "user@example.com")

    input = %{
      id: @id,
      expected_modified_at: DateTime.to_iso8601(@modified_at),
      notes: "Updated notes"
    }

    assert {:ok, prepared} =
             Jido.Connect.Things.prepare("things.todo.update", input,
               context: context,
               credential_lease: lease,
               transport: transport,
               now: @now,
               lock: &direct_lock/2
             )

    flush_requests()

    assert {:error, %Error.ProviderError{reason: :stale_expected_modified_at}} =
             commit(prepared, input, context, lease, transport)

    refute_received {:request, :post, _url, _opts}
  end

  test "requires the high-risk gate for a non-empty note replacement" do
    parent = self()
    transport = successful_update_transport(parent, @modified_at, @modified_at)
    {context, lease} = runtime_contract("connection-A", "user@example.com")

    input = %{
      id: @id,
      expected_modified_at: DateTime.to_iso8601(@modified_at),
      notes: "Replacement"
    }

    assert {:ok, prepared} =
             Jido.Connect.Things.prepare("things.todo.update", input,
               context: context,
               credential_lease: lease,
               transport: transport,
               now: @now,
               lock: &direct_lock/2
             )

    assert prepared.provider_plan.risk == :high
    flush_requests()

    assert {:error, %Error.AuthError{reason: :high_risk_confirmation_required}} =
             Jido.Connect.Things.commit(prepared, input,
               context: context,
               credential_lease: lease,
               transport: transport,
               commit?: true,
               now: @now,
               lock: &direct_lock/2,
               execution_authorization: %{plan_id: prepared.action.id},
               authorization_validator: &authorize/4
             )

    refute_received {:request, :post, _url, _opts}
  end

  test "allows non-Inbox task updates and rejects trash, structural, and deleted targets" do
    {context, lease} = runtime_contract("connection-A", "user@example.com")

    for patch <- [%{"ss" => 3}, %{"ss" => 2}, %{"st" => 1}] do
      assert {:ok, _prepared} =
               Jido.Connect.Things.prepare(
                 "things.todo.update",
                 %{
                   id: @id,
                   expected_modified_at: DateTime.to_iso8601(@modified_at),
                   title: "Updated"
                 },
                 context: context,
                 credential_lease: lease,
                 transport: update_planning_transport(patch),
                 now: @now,
                 lock: &direct_lock/2
               )
    end

    for {patch, reason} <- [
          {%{"tr" => true}, :target_in_trash},
          {%{"tp" => 1}, :unsupported_write_target}
        ] do
      transport = update_planning_transport(patch)

      assert {:error, %Error.ProviderError{reason: ^reason}} =
               Jido.Connect.Things.prepare(
                 "things.todo.update",
                 %{
                   id: @id,
                   expected_modified_at: DateTime.to_iso8601(@modified_at),
                   title: "Updated"
                 },
                 context: context,
                 credential_lease: lease,
                 transport: transport,
                 now: @now,
                 lock: &direct_lock/2
               )
    end

    deleted_transport = update_planning_transport(%{}, 2)

    assert {:error, %Error.ProviderError{reason: :todo_not_found}} =
             Jido.Connect.Things.prepare(
               "things.todo.update",
               %{
                 id: @id,
                 expected_modified_at: DateTime.to_iso8601(@modified_at),
                 title: "Updated"
               },
               context: context,
               credential_lease: lease,
               transport: deleted_transport,
               now: @now,
               lock: &direct_lock/2
             )
  end

  test "keeps concurrent account connections isolated" do
    parent = self()
    transport_a = successful_create_transport(parent, "alpha@example.com", "history-A")
    transport_b = successful_create_transport(parent, "beta@example.com", "history-B")
    {context_a, lease_a} = runtime_contract("connection-A", "alpha@example.com")
    {context_b, lease_b} = runtime_contract("connection-B", "beta@example.com")
    input = %{title: "Same title"}

    assert {:ok, prepared_a} = prepare_create(context_a, lease_a, transport_a, input)
    assert {:ok, prepared_b} = prepare_create(context_b, lease_b, transport_b, input)
    refute prepared_a.provider_plan.account_binding == prepared_b.provider_plan.account_binding
    refute prepared_a.provider_plan.confirmation == prepared_b.provider_plan.confirmation
    flush_requests()

    assert {:error, %Error.AuthError{reason: :prepared_action_stale}} =
             commit(prepared_a, input, context_b, lease_b, transport_b)

    refute_received {:request, :post, _url, _opts}
  end

  test "redacts client and lease Inspect output" do
    {context, lease} = runtime_contract("connection-A", "user@example.com")

    assert {:ok, client} =
             Client.from_runtime(context, lease, transport: planning_transport(self()))

    client_text = inspect(client)
    lease_text = inspect(lease)

    refute client_text =~ "secret-password"
    refute client_text =~ "user@example.com"
    refute lease_text =~ "secret-password"
    assert lease_text =~ "password"
  end

  test "supports a head-bound host read adapter during prepare" do
    parent = self()
    transport = successful_update_transport(parent, @modified_at, @modified_at)
    {context, lease} = runtime_contract("connection-A", "user@example.com")

    adapter = fn "connection-A", @id, 1 ->
      {:ok,
       %{
         provider_head: 1,
         todo:
           Todo.new!(%{
             id: @id,
             title: "Projected",
             notes: "",
             modified_at: @modified_at,
             status: :open,
             schedule: :inbox,
             type: :task,
             in_trash: false,
             deleted: false
           })
       }}
    end

    input = %{
      id: @id,
      expected_modified_at: DateTime.to_iso8601(@modified_at),
      notes: "Changed"
    }

    assert {:ok, prepared} =
             Jido.Connect.Things.prepare("things.todo.update", input,
               context: context,
               credential_lease: lease,
               transport: transport,
               read_adapter: adapter,
               now: @now,
               lock: &direct_lock/2
             )

    assert prepared.provider_plan.ancestor_index == 1
  end

  defp prepare_create(context, lease, transport, input) do
    Jido.Connect.Things.prepare("things.todo.create", input,
      context: context,
      credential_lease: lease,
      transport: transport,
      id_generator: fn -> @id end,
      now: @now,
      lock: &direct_lock/2
    )
  end

  defp commit(prepared, input, context, lease, transport, extra_options \\ []) do
    options =
      Keyword.merge(
        [
          context: context,
          credential_lease: lease,
          transport: transport,
          commit?: true,
          high_risk?: true,
          destructive?: true,
          now: @now,
          lock: &direct_lock/2,
          execution_authorization: %{plan_id: prepared.action.id},
          authorization_validator: &authorize/4
        ],
        extra_options
      )

    Jido.Connect.Things.commit(prepared, input, options)
  end

  defp authorize(%{plan_id: id}, %{id: id}, _context, _validator_context), do: :ok
  defp authorize(_evidence, _prepared, _context, _validator_context), do: :error

  defp direct_lock(_account, function), do: function.()

  defp runtime_contract(connection_id, email, opts \\ []) do
    connection =
      Connection.new!(%{
        id: connection_id,
        provider: :things,
        profile: :things_cloud_password,
        tenant_id: "tenant-1",
        owner_type: :app_user,
        owner_id: "user-1",
        subject: %{email: email},
        status: :connected,
        credential_ref: "credential-#{connection_id}",
        scopes: [],
        metadata: %{endpoint: Keyword.get(opts, :endpoint, Client.production_endpoint())}
      })

    context =
      Context.new!(%{
        tenant_id: "tenant-1",
        actor: %{type: :ai, id: "agent-1"},
        connection: connection,
        claims: %{},
        metadata: %{}
      })

    lease =
      CredentialLease.from_connection!(
        connection,
        %{email: email, password: "secret-password"},
        expires_at: DateTime.add(DateTime.utc_now(), 3_600, :second)
      )

    {context, lease}
  end

  defp planning_transport(parent) do
    fn method, url, opts ->
      send(parent, {:request, method, url, opts})

      cond do
        String.contains?(url, "/account/") -> account_response("user@example.com", "history-A")
        String.ends_with?(url, "/history/history-A") -> history_response(1)
      end
    end
  end

  defp successful_create_transport(
         parent,
         email \\ "user@example.com",
         history_key \\ "history-A"
       ) do
    body_key = {:posted_body, make_ref()}

    fn method, url, opts ->
      send(parent, {:request, method, url, opts})

      cond do
        String.contains?(url, "/account/") ->
          account_response(email, history_key)

        String.ends_with?(url, "/history/#{history_key}") ->
          history_response(1)

        method == :post ->
          Process.put(body_key, Jason.decode!(Keyword.fetch!(opts, :body)))
          {:ok, %{status: 200, body: %{"server-head-index" => 2}}}

        String.ends_with?(url, "/history/#{history_key}/items") ->
          page_response([Process.get(body_key)])
      end
    end
  end

  defp failed_send_transport(parent) do
    fn method, url, opts ->
      send(parent, {:request, method, url, opts})

      cond do
        String.contains?(url, "/account/") -> account_response("user@example.com", "history-A")
        String.ends_with?(url, "/history/history-A") -> history_response(1)
        method == :post -> {:error, %{message: "timeout", password: "must-redact"}}
      end
    end
  end

  defp unverified_create_transport(parent) do
    fn method, url, opts ->
      send(parent, {:request, method, url, opts})

      cond do
        String.contains?(url, "/account/") -> account_response("user@example.com", "history-A")
        String.ends_with?(url, "/history/history-A") -> history_response(1)
        method == :post -> {:ok, %{status: 200, body: %{"server-head-index" => 2}}}
        String.ends_with?(url, "/history/history-A/items") -> page_response([])
      end
    end
  end

  defp eventually_verified_create_transport(parent) do
    item_calls = :counters.new(1, [])
    body_key = {:posted_body, make_ref()}

    fn method, url, opts ->
      send(parent, {:request, method, url, opts})

      cond do
        String.contains?(url, "/account/") ->
          account_response("user@example.com", "history-A")

        String.ends_with?(url, "/history/history-A") ->
          history_response(1)

        method == :post ->
          Process.put(body_key, Jason.decode!(Keyword.fetch!(opts, :body)))
          {:ok, %{status: 200, body: %{"server-head-index" => 2}}}

        String.ends_with?(url, "/history/history-A/items") ->
          :counters.add(item_calls, 1, 1)

          if :counters.get(item_calls, 1) == 1 do
            page_response([])
          else
            page_response([Process.get(body_key)])
          end
      end
    end
  end

  defp successful_update_transport(parent, prepare_modified_at, commit_modified_at) do
    item_calls = :counters.new(1, [])
    body_key = {:posted_update_body, make_ref()}

    fn method, url, opts ->
      send(parent, {:request, method, url, opts})

      cond do
        String.contains?(url, "/account/") ->
          account_response("user@example.com", "history-A")

        String.ends_with?(url, "/history/history-A") ->
          history_response(1)

        method == :post ->
          Process.put(body_key, Jason.decode!(Keyword.fetch!(opts, :body)))
          {:ok, %{status: 200, body: %{"server-head-index" => 2}}}

        String.ends_with?(url, "/history/history-A/items") ->
          :counters.add(item_calls, 1, 1)
          call = :counters.get(item_calls, 1)

          cond do
            Process.get(body_key) -> page_response([Process.get(body_key)])
            call == 1 -> page_response([task_event(@id, prepare_modified_at)])
            true -> page_response([task_event(@id, commit_modified_at)])
          end
      end
    end
  end

  defp update_planning_transport(patch, action \\ 0) do
    fn _method, url, _opts ->
      cond do
        String.contains?(url, "/account/") ->
          account_response("user@example.com", "history-A")

        String.ends_with?(url, "/history/history-A") ->
          history_response(1)

        String.ends_with?(url, "/history/history-A/items") ->
          page_response([task_event(@id, @modified_at, patch, action)])
      end
    end
  end

  defp history_event_transport(event) do
    fn _method, url, _opts ->
      cond do
        String.contains?(url, "/account/") -> account_response("user@example.com", "history-A")
        String.ends_with?(url, "/history/history-A") -> history_response(1)
        String.ends_with?(url, "/history/history-A/items") -> page_response([event])
      end
    end
  end

  defp account_response(email, history_key) do
    {:ok,
     %{
       status: 200,
       body: %{
         "email" => email,
         "history-key" => history_key,
         "status" => "SYAccountStatusActive",
         "issues" => nil
       }
     }}
  end

  defp history_response(head, schema \\ 301) do
    {:ok,
     %{
       status: 200,
       body: %{
         "latest-server-index" => head,
         "latest-schema-version" => schema
       }
     }}
  end

  defp page_response(items), do: {:ok, %{status: 200, body: %{"items" => items}}}

  defp task_event(id, modified_at, patch \\ %{}, action \\ 0) do
    timestamp = DateTime.to_unix(modified_at, :microsecond) / 1_000_000

    payload =
      %{
        "tp" => 0,
        "ss" => 0,
        "st" => 0,
        "tr" => false,
        "tt" => "Existing task",
        "nt" => %{"v" => "Existing notes"},
        "cd" => timestamp,
        "md" => timestamp
      }
      |> Map.merge(patch)

    %{id => %{"e" => "Task6", "t" => action, "p" => payload}}
  end

  defp flush_requests do
    receive do
      {:request, _method, _url, _opts} -> flush_requests()
    after
      0 -> :ok
    end
  end

  defp drain_requests(acc \\ []) do
    receive do
      {:request, _method, _url, _opts} = request -> drain_requests([request | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp requests_for(requests, method) do
    Enum.filter(requests, fn {:request, request_method, _url, _opts} ->
      request_method == method
    end)
  end
end
