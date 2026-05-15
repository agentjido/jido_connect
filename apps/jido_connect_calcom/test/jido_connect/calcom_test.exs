defmodule Jido.Connect.CalcomTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Calcom

  @calcom_action_modules [
    Jido.Connect.Calcom.Actions.ListEventTypes,
    Jido.Connect.Calcom.Actions.ListBookings,
    Jido.Connect.Calcom.Actions.GetBooking,
    Jido.Connect.Calcom.Actions.CancelBooking,
    Jido.Connect.Calcom.Actions.RescheduleBooking,
    Jido.Connect.Calcom.Actions.CreateWebhook,
    Jido.Connect.Calcom.Actions.ListWebhooks,
    Jido.Connect.Calcom.Actions.DeleteWebhook
  ]

  @calcom_dsl_fragments [
    Jido.Connect.Calcom.Actions.EventTypes,
    Jido.Connect.Calcom.Actions.Bookings,
    Jido.Connect.Calcom.Actions.Webhooks
  ]

  @test_scopes [
    "EVENT_TYPE_READ",
    "BOOKING_READ",
    "BOOKING_WRITE",
    "WEBHOOK_READ",
    "WEBHOOK_WRITE"
  ]

  defmodule FakeCalcomClient do
    def list_event_types(_params, "token") do
      {:ok,
       [
         Calcom.EventType.new!(%{
           id: 1,
           slug: "30min",
           title: "30 Minute Meeting",
           length_in_minutes: 30
         })
       ]}
    end

    def list_bookings(_params, "token") do
      {:ok,
       %{
         bookings: [
           Calcom.Booking.new!(%{
             uid: "booking-1",
             title: "Team Sync",
             status: "accepted"
           })
         ],
         next_cursor: "cursor-2",
         has_more: true
       }}
    end

    def get_booking(%{booking_uid: "booking-1"}, "token") do
      {:ok,
       Calcom.Booking.new!(%{
         uid: "booking-1",
         title: "Team Sync",
         status: "accepted"
       })}
    end

    def cancel_booking(%{booking_uid: "booking-1", body: _body}, "token") do
      {:ok,
       Calcom.Booking.new!(%{
         uid: "booking-1",
         title: "Team Sync",
         status: "cancelled",
         cancellation_reason: "conflict"
       })}
    end

    def reschedule_booking(%{booking_uid: "booking-1", body: _body}, "token") do
      {:ok,
       Calcom.Booking.new!(%{
         uid: "booking-1",
         title: "Team Sync",
         status: "accepted",
         start: "2026-06-01T11:00:00Z"
       })}
    end

    def create_webhook(params, "token") do
      {:ok,
       Calcom.Webhook.new!(%{
         id: 1,
         subscriber_url: params.subscriber_url,
         active: params.active,
         triggers: params.triggers
       })}
    end

    def list_webhooks(_params, "token") do
      {:ok,
       [
         Calcom.Webhook.new!(%{
           id: 1,
           subscriber_url: "https://example.com/hook",
           active: true,
           triggers: ["BOOKING_CREATED"]
         })
       ]}
    end

    def delete_webhook(%{webhook_id: 1}, "token") do
      {:ok,
       Calcom.Webhook.new!(%{
         id: 1,
         subscriber_url: "https://example.com/hook",
         active: false,
         triggers: []
       })}
    end
  end

  test "declares Cal.com provider metadata" do
    spec = Calcom.integration()

    assert spec.id == :calcom
    assert spec.package == :jido_connect_calcom
    assert spec.name == "Cal.com"
    assert spec.category == :calendar
    assert spec.status == :experimental
    assert spec.tags == [:calcom, :scheduling, :booking, :webhooks]

    assert Enum.map(spec.actions, & &1.id) == [
             "calcom.event_types.list",
             "calcom.bookings.list",
             "calcom.bookings.get",
             "calcom.bookings.cancel",
             "calcom.bookings.reschedule",
             "calcom.webhooks.create",
             "calcom.webhooks.list",
             "calcom.webhooks.delete"
           ]

    assert spec.triggers == []

    assert [
             %{id: :api_key, kind: :api_key} = api_key_profile,
             %{id: :oauth2_user, kind: :oauth2} = oauth_profile
           ] =
             spec.auth_profiles

    assert api_key_profile.default? == true
    assert oauth_profile.default? == false
    assert oauth_profile.pkce? == true
    assert "EVENT_TYPE_READ" in oauth_profile.default_scopes
    assert "BOOKING_READ" in oauth_profile.default_scopes
    assert "BOOKING_WRITE" in oauth_profile.optional_scopes
  end

  test "compiles generated Jido plugin surface" do
    assert Application.get_env(:jido_connect_calcom, :jido_connect_providers) == [Calcom]
    assert Calcom.jido_action_modules() == @calcom_action_modules
    assert Calcom.jido_sensor_modules() == []
    assert Calcom.jido_plugin_module() == Jido.Connect.Calcom.Plugin

    assert %Jido.Connect.Catalog.Manifest{
             id: :calcom,
             package: :jido_connect_calcom,
             generated_modules: %{
               actions: @calcom_action_modules,
               sensors: [],
               plugin: Jido.Connect.Calcom.Plugin
             }
           } = Calcom.jido_connect_manifest()

    for module <- @calcom_action_modules do
      assert {:module, ^module} = Code.ensure_loaded(module)
      assert function_exported?(module, :run, 2)

      projection = module.jido_connect_projection()
      tool = module.to_tool()

      assert projection.module == module
      assert module.operation_id() == projection.action_id
      assert module.name() == projection.name
      assert tool.name == projection.name
    end

    assert %Jido.Plugin.Spec{
             name: "calcom",
             module: Jido.Connect.Calcom.Plugin,
             actions: @calcom_action_modules
           } = Jido.Connect.Calcom.Plugin.plugin_spec()
  end

  test "loads Cal.com Spark DSL fragments" do
    for fragment <- @calcom_dsl_fragments do
      assert {:module, ^fragment} = Code.ensure_loaded(fragment)
      assert fragment.extensions() == [Jido.Connect.Dsl.Extension]
      assert fragment.opts() == [of: Jido.Connect]
      assert %{extensions: [Jido.Connect.Dsl.Extension]} = fragment.persisted()
      assert is_map(fragment.spark_dsl_config())

      assert [{_section, Jido.Connect.Dsl.Extension, Jido.Connect.Dsl.Extension}] =
               fragment.validate_sections()
    end
  end

  test "exposes curated catalog pack delegates" do
    assert %{id: :calcom_reader} = Calcom.reader_pack()
    assert %{id: :calcom_booking} = Calcom.booking_pack()
    assert %{id: :calcom_webhook} = Calcom.webhook_pack()
    assert Enum.map(Calcom.catalog_packs(), & &1.id) == [:calcom_reader, :calcom_booking, :calcom_webhook]
  end

  test "invokes list event types through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{event_types: [%{id: 1, slug: "30min", title: "30 Minute Meeting"}]}} =
             Connect.invoke(
               Calcom.integration(),
               "calcom.event_types.list",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list bookings through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{bookings: [%{uid: "booking-1"}], next_cursor: "cursor-2", has_more: true}} =
             Connect.invoke(
               Calcom.integration(),
               "calcom.bookings.list",
               %{status: "upcoming"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes get booking through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{booking: %{uid: "booking-1", title: "Team Sync"}}} =
             Connect.invoke(
               Calcom.integration(),
               "calcom.bookings.get",
               %{booking_uid: "booking-1"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes cancel booking through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{booking: %{uid: "booking-1", status: "cancelled"}}} =
             Connect.invoke(
               Calcom.integration(),
               "calcom.bookings.cancel",
               %{booking_uid: "booking-1", cancellation_reason: "conflict"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes reschedule booking through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{booking: %{uid: "booking-1", start: "2026-06-01T11:00:00Z"}}} =
             Connect.invoke(
               Calcom.integration(),
               "calcom.bookings.reschedule",
               %{booking_uid: "booking-1", start: "2026-06-01T11:00:00Z"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes create webhook through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{webhook: %{id: 1, subscriber_url: "https://example.com/hook", active: true}}} =
             Connect.invoke(
               Calcom.integration(),
               "calcom.webhooks.create",
               %{subscriber_url: "https://example.com/hook", triggers: ["BOOKING_CREATED"], active: true},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list webhooks through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{webhooks: [%{id: 1, subscriber_url: "https://example.com/hook"}]}} =
             Connect.invoke(
               Calcom.integration(),
               "calcom.webhooks.list",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes delete webhook through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{webhook: %{id: 1}}} =
             Connect.invoke(
               Calcom.integration(),
               "calcom.webhooks.delete",
               %{webhook_id: 1},
               context: context,
               credential_lease: lease
             )
  end

  defp context_and_lease do
    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :calcom,
        profile: :api_key,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: @test_scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        provider: :calcom,
        profile: :api_key,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{api_key: "token", calcom_client: FakeCalcomClient},
        scopes: @test_scopes
      })

    {context, lease}
  end
end
