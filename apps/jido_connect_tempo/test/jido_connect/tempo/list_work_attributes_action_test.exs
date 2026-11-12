defmodule Jido.Connect.Tempo.ListWorkAttributesActionTest do
  use ExUnit.Case, async: false

  # `tempo.work_attribute.list` through the runtime and through the
  # generated Jido action, against the pages the live test recorded on
  # 2026-11-03 in two work-attribute windows, with the five test attributes
  # optional (`work_attributes_optional`) and all but `_JclNote_` required
  # (`work_attributes_required`). The three attributes outside the test data
  # were neutralized at record time to `_Other1_` to `_Other3_`.

  alias Jido.Connect
  alias Jido.Connect.{Connection, Context, CredentialLease, Error}
  alias Jido.Connect.Tempo
  alias Jido.Connect.Tempo.Actions.ListWorkAttributes
  alias Jido.Connect.Tempo.Fixture

  @action "tempo.work_attribute.list"
  @page "work_attributes_optional"
  @api_token "tempo-api-token-273-secret"
  @access_token "tempo-oauth-token-273-secret"

  defmodule RecordingClient do
    @moduledoc false

    # A provider client that reports its call and returns no attributes.
    def list_work_attributes(request, opts) do
      send(self(), {:list_work_attributes, request, opts})
      {:ok, []}
    end
  end

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

  describe "output" do
    test "returns every attribute as a plain map; optional ones leave the requirements complete" do
      Req.Test.expect(__MODULE__, &Fixture.respond(&1, @page))

      assert {:ok, %{attributes: attributes, complete: true, incomplete: []} = result} =
               invoke(:api_token, %{})

      assert length(attributes) == 8
      assert Enum.all?(attributes, &(&1.required == false))
      refute Enum.any?(attributes, &is_struct/1)

      assert %{
               key: "_JclPhase_",
               type: "STATIC_LIST",
               values: [%{label: "analysis"}, %{label: "build"}, %{label: "review"}]
             } = Enum.find(attributes, &(&1.key == "_JclPhase_"))

      assert {:ok, _json} = Jason.encode(result)
    end

    test "required attributes of supported types leave the requirements complete" do
      Req.Test.expect(__MODULE__, &Fixture.respond(&1, "work_attributes_required"))

      assert {:ok, %{attributes: attributes, complete: true, incomplete: []}} =
               invoke(:oauth2_user, %{})

      assert attributes |> Enum.filter(& &1.required) |> Enum.map(&{&1.key, &1.type}) == [
               {"_JclPhase_", "STATIC_LIST"},
               {"_JclBillable_", "CHECKBOX"},
               {"_JclHours_", "INPUT_NUMERIC"},
               {"_JclAccount_", "ACCOUNT"}
             ]

      assert %{type: "INPUT_FIELD", required: false} =
               Enum.find(attributes, &(&1.key == "_JclNote_"))
    end

    # Derived: the recorded page with _JclPhase_ required and without its
    # choice list, and _JclHours_ required with a type the package does not
    # describe.
    test "an unknown required type and a required list without choices make the requirements incomplete" do
      Req.Test.expect(__MODULE__, fn conn ->
        Fixture.respond(conn, @page,
          body: fn body ->
            update_in(body, ["results"], fn results ->
              Enum.map(results, fn
                %{"key" => "_JclPhase_"} = phase ->
                  phase |> Map.delete("values") |> Map.put("required", true)

                %{"key" => "_JclHours_"} = hours ->
                  Map.merge(hours, %{"type" => "DYNAMIC_DROPDOWN", "required" => true})

                attribute ->
                  attribute
              end)
            end)
          end
        )
      end)

      assert {:ok, %{attributes: attributes, complete: false, incomplete: incomplete}} =
               invoke(:oauth2_user, %{})

      assert incomplete == [
               %{key: "_JclPhase_", reason: :missing_choices},
               %{key: "_JclHours_", reason: :unsupported_type}
             ]

      assert %{type: "DYNAMIC_DROPDOWN", required: true, values: nil} =
               Enum.find(attributes, &(&1.key == "_JclHours_"))

      assert %{type: "STATIC_LIST", values: nil} =
               Enum.find(attributes, &(&1.key == "_JclPhase_"))
    end

    test "the generated action reads with the OAuth profile" do
      Req.Test.expect(__MODULE__, &Fixture.respond(&1, @page))
      context = context(:oauth2_user)

      assert {:ok, %{attributes: [_ | _], complete: true}} =
               ListWorkAttributes.run(%{}, %{
                 integration_context: context,
                 credential_lease: lease(context)
               })
    end

    test "an empty list through the provider client seam is complete" do
      context = context(:api_token)

      assert {:ok, %{attributes: [], complete: true, incomplete: []}} =
               ListWorkAttributes.run(%{}, %{
                 integration_context: context,
                 credential_lease: lease(context),
                 provider_client: RecordingClient
               })

      assert_received {:list_work_attributes, %{connection_id: "tempo_conn_1"}, []}
    end

    test "a failed page fails the action without any attribute" do
      Req.Test.expect(__MODULE__, &Fixture.respond(&1, @page, status: 503))

      assert {:error, %Error.ProviderError{reason: :server_error, status: 503} = error} =
               invoke(:api_token, %{})

      refute inspect(error) =~ "_JclPhase_"
      refute inspect(error) =~ @api_token
    end
  end

  describe "gates before HTTP" do
    setup do
      test_pid = self()

      Req.Test.stub(__MODULE__, fn conn ->
        send(test_pid, :requested)
        Fixture.respond(conn, @page)
      end)

      :ok
    end

    test "any input fails validation" do
      for input <- [%{project_id: 10_882}, %{issue_id: 46_097}, %{key: "_JclPhase_"}] do
        assert {:error, %Error.ValidationError{}} = invoke(:api_token, input)
      end

      refute_received :requested
    end

    test "a missing tempo.worklogs.read grant stops the call" do
      assert {:error,
              %Error.AuthError{reason: :missing_scopes, missing_scopes: ["tempo.worklogs.read"]}} =
               invoke(:api_token, %{}, scopes: ["tempo.accounts.read", "tempo.worklogs.write"])

      refute_received :requested
    end

    test "an expired lease or a lease of another connection stops the call" do
      context = context(:api_token)
      other = context(:api_token, connection_id: "tempo_conn_other")
      expired = lease(context, expires_at: DateTime.add(DateTime.utc_now(), -1, :second))

      for lease <- [expired, lease(other)] do
        assert {:error, %Error.AuthError{}} =
                 Connect.invoke(Tempo, @action, %{}, context: context, credential_lease: lease)
      end

      refute_received :requested
    end

    test "a lease without the profile's token field stops the call" do
      context = context(:api_token)
      lease = lease(context, fields: %{access_token: @access_token})

      assert {:error, %Error.AuthError{reason: :tempo_credentials_required}} =
               Connect.invoke(Tempo, @action, %{}, context: context, credential_lease: lease)

      refute_received :requested
    end
  end

  defp invoke(profile, input, opts \\ []) do
    context = context(profile, Keyword.take(opts, [:scopes]))
    Connect.invoke(Tempo, @action, input, context: context, credential_lease: lease(context))
  end

  defp context(profile, opts \\ []) do
    connection =
      Connection.new!(%{
        id: Keyword.get(opts, :connection_id, "tempo_conn_1"),
        provider: :tempo,
        profile: profile,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        subject: %{account_id: "account-1"},
        status: :connected,
        scopes: Keyword.get(opts, :scopes, ["tempo.worklogs.read"]),
        metadata: %{api_origin: "https://api.us.tempo.io"}
      })

    Context.new!(%{
      tenant_id: "tenant_1",
      actor: %{id: "user_1", type: :app_user},
      connection: connection
    })
  end

  defp lease(%Context{connection: connection}, opts \\ []) do
    fields =
      Keyword.get_lazy(opts, :fields, fn ->
        case connection.profile do
          :api_token -> %{api_token: @api_token}
          :oauth2_user -> %{access_token: @access_token}
        end
      end)

    CredentialLease.from_connection!(connection, fields,
      expires_at:
        Keyword.get_lazy(opts, :expires_at, fn -> DateTime.add(DateTime.utc_now(), 60) end)
    )
  end
end
