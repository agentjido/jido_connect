defmodule Jido.Connect.Tempo.Client.AccountsTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.{Connection, Error}
  alias Jido.Connect.Tempo.{Account, Client, Fixture}
  alias Jido.Connect.Tempo.Client.Request

  # Recorded by the live test of the account candidates on 2026-11-03: the
  # links of the test project 10882 with global accounts on
  # `accounts_for_project`, then the details of each linked account in link
  # order, 26 to 29 on `.2` to `.5`. The site's two global accounts outside
  # the test data were left out of the links at record time and their
  # details were not recorded; `metadata.count` counts the four that stay.
  # JCL-PROJECT (26) is the default link, JCL-CLOSED (28) is closed, and
  # JCL-GLOBAL (29) is global, which Tempo reports as a link with ID 0 on
  # the requested project. `account_not_found` is Tempo's 404 for an
  # unknown account ID.
  @project 10_882
  @links "accounts_for_project"
  @details %{
    "26" => "accounts_for_project.2",
    "27" => "accounts_for_project.3",
    "28" => "accounts_for_project.4",
    "29" => "accounts_for_project.5"
  }

  setup {Req.Test, :verify_on_exit!}

  setup do
    previous = Application.fetch_env(:jido_connect_tempo, :tempo_req_options)
    Application.put_env(:jido_connect_tempo, :tempo_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:jido_connect_tempo, :tempo_req_options, value)
        :error -> Application.delete_env(:jido_connect_tempo, :tempo_req_options)
      end
    end)
  end

  describe "list_accounts_for_project/3" do
    test "returns the recorded candidates in link order with their link evidence" do
      serve()

      assert {:ok, accounts} = Client.list_accounts_for_project(request(), @project)

      assert [
               %Account{
                 id: 26,
                 key: "JCL-PROJECT",
                 name: "JCL live: project account",
                 status: "OPEN",
                 global: false,
                 self: "https://api.tempo.io/4/accounts/26",
                 links: [%{id: 24, default: true, scope_type: "PROJECT", scope_id: 10_882}]
               },
               %Account{id: 27, key: "JCL-SECONDARY", status: "OPEN", global: false},
               %Account{id: 28, key: "JCL-CLOSED", status: "CLOSED", global: false},
               %Account{id: 29, key: "JCL-GLOBAL", status: "OPEN", global: true}
             ] = accounts

      assert Enum.map(accounts, & &1.links) == [
               [%{id: 24, default: true, scope_type: "PROJECT", scope_id: 10_882}],
               [%{id: 25, default: false, scope_type: "PROJECT", scope_id: 10_882}],
               [%{id: 26, default: false, scope_type: "PROJECT", scope_id: 10_882}],
               [%{id: 0, default: false, scope_type: "PROJECT", scope_id: 10_882}]
             ]
    end

    test "reads the links with global accounts, then each account once, at the connection origin" do
      serve(report: self())

      assert {:ok, _accounts} = Client.list_accounts_for_project(request(), @project)

      assert_received {:request, "api.us.tempo.io", "/4/account-links/project/10882", query}
      assert query == %{"includeGlobalAccounts" => "true"}

      # The links name https://api.tempo.io; the details are read at the
      # connection's origin, never at the link.
      for id <- ["26", "27", "28", "29"] do
        assert_received {:request, "api.us.tempo.io", "/4/accounts/" <> ^id, %{}}
      end

      refute_received {:request, _host, _path, _query}
    end

    test "keeps only the allowlisted fields of an account" do
      serve()

      assert {:ok, [account | _rest]} = Client.list_accounts_for_project(request(), @project)

      assert account |> Account.to_map() |> Map.keys() |> Enum.sort() ==
               [:global, :id, :key, :links, :name, :self, :status]

      text = inspect(account)
      refute text =~ "lead"
      refute text =~ "account-1"
    end

    # Derived from the recorded links, since the test project has no
    # duplicate link and no link of another project: every link moves to
    # project 10010, a second link of JCL-SECONDARY (ID 30) follows it, and
    # a link of an account 31 is scoped to project 10020.
    test "for project 10010, every account keeps its evidence and a link of 10020 is not a candidate" do
      duplicate = fn links -> links |> Enum.at(1) |> Map.put("id", 30) end

      other_project = fn links ->
        links
        |> Enum.at(1)
        |> Map.merge(%{
          "id" => 31,
          "account" => %{"self" => "https://api.tempo.io/4/accounts/31"}
        })
        |> put_in(["scope", "id"], 10_020)
      end

      serve(
        project: 10_010,
        links: fn body ->
          update_in(body, ["results"], fn links ->
            links = Enum.map(links, &put_in(&1, ["scope", "id"], 10_010))
            List.insert_at(links, 2, duplicate.(links)) ++ [other_project.(links)]
          end)
        end,
        report: self()
      )

      assert {:ok, accounts} = Client.list_accounts_for_project(request(), 10_010)

      assert Enum.map(accounts, &{&1.id, &1.key, &1.status, &1.global}) == [
               {26, "JCL-PROJECT", "OPEN", false},
               {27, "JCL-SECONDARY", "OPEN", false},
               {28, "JCL-CLOSED", "CLOSED", false},
               {29, "JCL-GLOBAL", "OPEN", true}
             ]

      assert Enum.map(accounts, fn account -> Enum.map(account.links, &{&1.id, &1.default}) end) ==
               [[{24, true}], [{25, false}, {30, false}], [{26, false}], [{0, false}]]

      assert Enum.all?(accounts, fn account ->
               Enum.all?(account.links, &(&1.scope_type == "PROJECT" and &1.scope_id == 10_010))
             end)

      assert_received {:request, _host, "/4/account-links/project/10010", _query}

      # JCL-SECONDARY is read once; account 31 of project 10020 is not read.
      for id <- ["26", "27", "28", "29"] do
        assert_received {:request, _host, "/4/accounts/" <> ^id, _query}
      end

      refute_received {:request, _host, _path, _query}
    end

    test "a link of another scope type is not a candidate" do
      serve(
        links: fn body ->
          update_in(body, ["results"], fn links ->
            List.update_at(links, 1, &put_in(&1, ["scope", "type"], "TEAM"))
          end)
        end
      )

      assert {:ok, accounts} = Client.list_accounts_for_project(request(), @project)
      assert Enum.map(accounts, & &1.id) == [26, 28, 29]
    end

    # Derived: two more links of JCL-SECONDARY (27), ID 30 scoped to project
    # 10020 and ID 31 of scope type TEAM. Neither is evidence for the
    # requested project.
    test "an account keeps only the evidence of its candidate links" do
      serve(
        links: fn body ->
          update_in(body, ["results"], fn links ->
            secondary = Enum.at(links, 1)
            other_project = secondary |> Map.put("id", 30) |> put_in(["scope", "id"], 10_020)
            team = secondary |> Map.put("id", 31) |> put_in(["scope", "type"], "TEAM")
            links ++ [other_project, team]
          end)
        end,
        report: self()
      )

      assert {:ok, accounts} = Client.list_accounts_for_project(request(), @project)

      assert %Account{links: [%{id: 25, default: false, scope_type: "PROJECT", scope_id: 10_882}]} =
               Enum.find(accounts, &(&1.id == 27))

      assert_received {:request, _host, "/4/account-links/project/10882", _query}

      for id <- ["26", "27", "28", "29"] do
        assert_received {:request, _host, "/4/accounts/" <> ^id, _query}
      end

      refute_received {:request, _host, _path, _query}
    end

    # Derived: the recorded answer without links.
    test "a project without links returns no accounts" do
      serve(links: &Map.merge(&1, %{"results" => [], "metadata" => %{"count" => 0}}))

      assert {:ok, []} = Client.list_accounts_for_project(request(), @project)
    end

    # Derived: the recorded details of JCL-CLOSED with another status.
    test "an archived or unfamiliar status stays the raw string" do
      for status <- ["ARCHIVED", "SUSPENDED"] do
        serve(details: %{"28" => &Map.put(&1, "status", status)})

        assert {:ok, accounts} = Client.list_accounts_for_project(request(), @project)
        assert %Account{status: ^status} = Enum.find(accounts, &(&1.id == 28))
      end
    end

    test "a self reference on another Tempo origin is read at the connection origin" do
      serve(
        links: &relink(&1, 0, "https://api.eu.tempo.io/4/accounts/26"),
        report: self()
      )

      assert {:ok, [%Account{id: 26} | _rest]} =
               Client.list_accounts_for_project(request(), @project)

      assert_received {:request, "api.us.tempo.io", "/4/account-links/project/10882", _query}
      assert_received {:request, "api.us.tempo.io", "/4/accounts/26", _query}
    end
  end

  describe "a read fails as a whole" do
    test "when a self reference names a foreign origin or an unexpected path, before any account read" do
      for self <- [
            "https://collector.example.com/4/accounts/26",
            "http://api.tempo.io/4/accounts/26",
            "https://api.tempo.io:8443/4/accounts/26",
            "https://api.tempo.io/4/accounts/26/links",
            "https://api.tempo.io/4/accounts/JCL-PROJECT",
            "https://api.tempo.io/4/accounts/0",
            "https://api.tempo.io/4/worklogs/26",
            "https://api.tempo.io/4/accounts/26?redirect=https://collector.example.com",
            "https://api.tempo.io/4/accounts/26#x",
            "https://api.tempo.io/4/accounts/%32%36",
            "/4/accounts/26"
          ] do
        serve(links: &relink(&1, 3, self), report: self())

        assert {:error,
                %Error.ProviderError{
                  provider: :tempo,
                  reason: :foreign_account_reference,
                  delivery: :response_received,
                  details: %{index: 3, link_id: 0}
                } = error} = Client.list_accounts_for_project(request(), @project)

        refute inspect(error) =~ "collector"
        assert_received {:request, "api.us.tempo.io", "/4/account-links/project/10882", _query}
        refute_received {:request, _host, _path, _query}
      end
    end

    # Derived: the last recorded link moved to project 10020 with a foreign
    # reference. It is no candidate, and its reference is checked all the
    # same.
    test "when a link that is no candidate names a foreign origin, before any account read" do
      serve(
        links: fn body ->
          body
          |> relink(3, "https://collector.example.com/4/accounts/29")
          |> update_in(["results"], fn links ->
            List.update_at(links, 3, &put_in(&1, ["scope", "id"], 10_020))
          end)
        end,
        report: self()
      )

      assert {:error,
              %Error.ProviderError{
                reason: :foreign_account_reference,
                details: %{index: 3, link_id: 0}
              }} = Client.list_accounts_for_project(request(), @project)

      assert_received {:request, _host, "/4/account-links/project/10882", _query}
      refute_received {:request, _host, _path, _query}
    end

    test "when an account read fails, with its status and reason" do
      serve(details: %{"28" => {:fixture, "account_not_found"}})

      assert {:error,
              %Error.ProviderError{reason: :not_found, status: 404, details: details} = error} =
               Client.list_accounts_for_project(request(), @project)

      assert details.message == "Invalid account"
      refute inspect(error) =~ "tempo-api-token-273"
    end

    test "when an account read is forbidden or fails on the server" do
      for {status, reason} <- [{403, :forbidden}, {500, :server_error}, {429, :rate_limited}] do
        serve(details: %{"27" => {:status, status}})

        assert {:error, %Error.ProviderError{reason: ^reason, status: ^status}} =
                 Client.list_accounts_for_project(request(), @project)
      end
    end

    test "when the links read fails" do
      Req.Test.expect(__MODULE__, &Fixture.respond(&1, "forbidden"))

      assert {:error, %Error.ProviderError{reason: :forbidden, status: 403}} =
               Client.list_accounts_for_project(request(), @project)
    end

    # Derived: the details of account 29 answered for link 27.
    test "when an account read names another account" do
      serve(details: %{"27" => {:fixture, "accounts_for_project.5"}})

      assert {:error,
              %Error.ProviderError{
                reason: :account_mismatch,
                delivery: :response_received,
                details: %{account_id: 27, returned_id: 29}
              }} = Client.list_accounts_for_project(request(), @project)
    end

    test "when the links answer has no results list" do
      for body <- [%{"metadata" => %{"count" => 0}}, %{"results" => "none"}, []] do
        serve(links: fn _body -> body end)

        assert {:error,
                %Error.ProviderError{reason: :invalid_account_links, delivery: :response_received}} =
                 Client.list_accounts_for_project(request(), @project)
      end
    end

    test "when a link is malformed" do
      for {change, field} <- [
            {&Map.delete(&1, "account"), "account.self"},
            {&put_in(&1, ["account", "self"], 26), "account.self"},
            {&Map.delete(&1, "default"), "default"},
            {&Map.put(&1, "default", "true"), "default"},
            {&Map.delete(&1, "id"), "id"},
            {&Map.put(&1, "id", -1), "id"},
            {&Map.delete(&1, "scope"), "scope.type"},
            {&put_in(&1, ["scope", "id"], "10882"), "scope.id"},
            {fn _link -> "link" end, "link"}
          ] do
        serve(links: fn body -> update_in(body, ["results"], &List.update_at(&1, 2, change)) end)

        assert {:error,
                %Error.ProviderError{
                  reason: :invalid_account_link,
                  details: %{index: 2, field: ^field}
                }} = Client.list_accounts_for_project(request(), @project)
      end
    end

    test "when an account is malformed" do
      for {change, field} <- [
            {&Map.delete(&1, "id"), "id"},
            {&Map.delete(&1, "key"), "key"},
            {&Map.put(&1, "key", ""), "key"},
            {&Map.delete(&1, "name"), "name"},
            {&Map.delete(&1, "status"), "status"},
            {&Map.put(&1, "global", "false"), "global"},
            {&Map.put(&1, "self", 29), "self"},
            {fn _account -> ["account"] end, "account"}
          ] do
        serve(details: %{"29" => change})

        assert {:error,
                %Error.ProviderError{
                  reason: :invalid_account,
                  details: %{account_id: 29, field: ^field}
                }} = Client.list_accounts_for_project(request(), @project)
      end
    end
  end

  describe "bounds and input" do
    test "more accounts than :max_accounts fail before the first account read" do
      serve(report: self())

      assert {:error,
              %Error.ProviderError{
                reason: :account_limit_exceeded,
                details: %{max_accounts: 3, accounts: 4}
              }} = Client.list_accounts_for_project(request(), @project, max_accounts: 3)

      assert_received {:request, _host, "/4/account-links/project/10882", _query}
      refute_received {:request, _host, _path, _query}
    end

    test "exactly :max_accounts accounts succeed; the default is 100" do
      serve()

      assert {:ok, [_, _, _, _]} =
               Client.list_accounts_for_project(request(), @project, max_accounts: 4)

      assert Client.Accounts.defaults() == [max_accounts: 100]
    end

    test "an invalid project ID or bound fails before any request" do
      test_pid = self()

      Req.Test.stub(__MODULE__, fn conn ->
        send(test_pid, :requested)
        Fixture.respond(conn, @links)
      end)

      for project <- [0, -1, "10882", 1.5, nil] do
        assert {:error, %Error.ValidationError{reason: :invalid_project_id, subject: :project_id}} =
                 Client.list_accounts_for_project(request(), project)
      end

      for bound <- [0, -1, "100", nil] do
        assert {:error, %Error.ValidationError{reason: :invalid_account_option}} =
                 Client.list_accounts_for_project(request(), @project, max_accounts: bound)
      end

      refute_received :requested
    end
  end

  # Answers the links read with the recorded links and each account read
  # with the recorded details of that ID. Options: `:project`, the expected
  # project ID in the links path; `:links`, a function that changes the
  # links body; `:details`, a map from account ID to a function that
  # changes those details, `{:fixture, name}` or `{:status, status}`; and
  # `:report`, a process that receives `{:request, host, path, query}`.
  defp serve(opts \\ []) do
    project = Keyword.get(opts, :project, @project)
    links = Keyword.get(opts, :links, & &1)
    details = Keyword.get(opts, :details, %{})
    report = Keyword.get(opts, :report)
    links_path = "/4/account-links/project/#{project}"

    Req.Test.stub(__MODULE__, fn conn ->
      query = URI.decode_query(conn.query_string)
      if report, do: send(report, {:request, conn.host, conn.request_path, query})

      case conn.request_path do
        ^links_path ->
          Fixture.respond(conn, @links, body: links)

        "/4/accounts/" <> id ->
          case Map.get(details, id, & &1) do
            {:fixture, name} -> Fixture.respond(conn, name)
            {:status, status} -> Fixture.respond(conn, "account_not_found", status: status)
            change -> Fixture.respond(conn, Map.fetch!(@details, id), body: change)
          end
      end
    end)
  end

  defp relink(body, index, self),
    do:
      update_in(
        body,
        ["results"],
        &List.update_at(&1, index, fn link -> put_in(link, ["account", "self"], self) end)
      )

  defp request do
    connection =
      Connection.new!(%{
        id: "tempo_conn_1",
        provider: :tempo,
        profile: :api_token,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        subject: %{account_id: "account-1"},
        status: :connected,
        scopes: ["tempo.accounts.read"],
        metadata: %{api_origin: "https://api.us.tempo.io"}
      })

    {:ok, request} = Request.new(connection, %{api_token: "tempo-api-token-273"})
    request
  end
end
