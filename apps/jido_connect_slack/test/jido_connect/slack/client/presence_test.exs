defmodule Jido.Connect.Slack.Client.PresenceTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.Slack.Client

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_slack, :slack_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_slack, :slack_req_options)
    end)
  end

  test "gets current availability and custom status" do
    Req.Test.stub(__MODULE__, fn conn ->
      case conn.request_path do
        "/api/auth.test" ->
          Req.Test.json(conn, %{ok: true, user_id: "U123"})

        "/api/users.getPresence" ->
          assert %{"user" => "U123"} = URI.decode_query(conn.query_string)

          Req.Test.json(conn, %{
            ok: true,
            presence: "away",
            online: false,
            auto_away: false,
            manual_away: true,
            connection_count: 2,
            last_activity: 1_720_000_000
          })

        "/api/users.profile.get" ->
          Req.Test.json(conn, %{
            ok: true,
            profile: %{
              status_text: "In a meeting",
              status_emoji: ":calendar:",
              status_expiration: 1_786_482_000
            }
          })
      end
    end)

    assert {:ok,
            %{
              availability: %{
                state: "away",
                manual_away: true,
                connection_count: 2,
                last_activity_at: "2024-07-03T09:46:40Z"
              },
              status: %{
                text: "In a meeting",
                emoji: ":calendar:",
                expires_at: "2026-08-11T21:00:00Z"
              }
            }} = Client.get_presence("token")
  end

  test "sets a custom status with a structured JSON profile" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/users.profile.set"
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "profile" => %{
                 "status_text" => "In a meeting",
                 "status_emoji" => ":calendar:",
                 "status_expiration" => 1_786_482_000
               }
             }

      Req.Test.json(conn, %{
        ok: true,
        profile: %{
          status_text: "In a meeting",
          status_emoji: ":calendar:",
          status_expiration: 1_786_482_000
        }
      })
    end)

    assert {:ok, %{status: %{text: "In a meeting", emoji: ":calendar:"}}} =
             Client.set_status(
               %{
                 profile: %{
                   status_text: "In a meeting",
                   status_emoji: ":calendar:",
                   status_expiration: 1_786_482_000
                 }
               },
               "token"
             )
  end

  test "lists sorted image and alias emoji" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        ok: true,
        emoji: %{
          shipit: "alias:squirrel",
          squirrel: "https://example.slack.test/squirrel.png"
        }
      })
    end)

    assert {:ok,
            %{
              emoji: [
                %{name: "shipit", type: "alias", alias_for: "squirrel"},
                %{
                  name: "squirrel",
                  type: "image",
                  image_url: "https://example.slack.test/squirrel.png"
                }
              ]
            }} = Client.list_emoji("token")
  end

  test "rejects invalid optional presence fields" do
    Req.Test.stub(__MODULE__, fn conn ->
      case conn.request_path do
        "/api/auth.test" ->
          Req.Test.json(conn, %{ok: true, user_id: "U123"})

        "/api/users.getPresence" ->
          Req.Test.json(conn, %{ok: true, presence: "away", manual_away: "yes"})

        "/api/users.profile.get" ->
          Req.Test.json(conn, %{ok: true, profile: %{}})
      end
    end)

    assert {:error, %Error.ProviderError{reason: :invalid_response}} =
             Client.get_presence("token")
  end
end
