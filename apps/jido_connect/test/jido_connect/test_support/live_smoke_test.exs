defmodule Jido.Connect.TestSupport.LiveSmokeTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Jido.Connect.Provider.Transport
  alias Jido.Connect.TestSupport.LiveSmoke
  alias Jido.Connect.TestSupport.LiveSmoke.{LeakError, Sanitize}

  require LiveSmoke

  @req_key :live_smoke_test_req_options
  @docs Path.expand("../../../../../docs/live_smoke_tests.md", __DIR__)
  # Unset, so a sourced env file does not add its site hosts to these tests.
  @no_sites %{
    "JIRA_SITE" => nil,
    "CONFLUENCE_SITE" => nil,
    "TEMPO_OAUTH_REDIRECT_URI" => nil,
    "JIDO_PUBLIC_URL" => nil
  }

  defmodule RecordingWebhook do
    def verify_delivery(body, headers, secret, opts) do
      send(self(), {:verify_delivery, body, headers, secret, opts})
      {:ok, :verified}
    end
  end

  setup do
    tmp = Path.join(System.tmp_dir!(), "live-smoke-#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)
    {:ok, tmp: tmp}
  end

  describe "env!/1" do
    test "skips with the names of unset variables" do
      with_env(%{"GOOGLE_ACCESS_TOKEN" => nil, "GOOGLE_GMAIL_QUERY" => ""}, fn ->
        tags = LiveSmoke.env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_QUERY"])

        assert tags[:live_env] == ["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_QUERY"]
        assert tags[:skip] =~ "GOOGLE_ACCESS_TOKEN"
        assert tags[:skip] =~ "GOOGLE_GMAIL_QUERY"
      end)
    end

    test "leaves the test runnable when every variable is set" do
      with_env(%{"SLACK_BOT_TOKEN" => "xoxb-live-smoke-test"}, fn ->
        assert LiveSmoke.env!(["SLACK_BOT_TOKEN"]) == [live_env: ["SLACK_BOT_TOKEN"]]
      end)
    end

    test "prints the reason with the test location only when the run includes :live_smoke" do
      include = ExUnit.configuration()[:include]

      with_env(%{"GOOGLE_ACCESS_TOKEN" => nil}, fn ->
        assert capture_io(fn -> LiveSmoke.env!(["GOOGLE_ACCESS_TOKEN"]) end) == ""

        try do
          ExUnit.configure(include: [:live_smoke])
          output = capture_io(fn -> LiveSmoke.env!(["GOOGLE_ACCESS_TOKEN"]) end)

          assert output =~ "live_smoke skip test/jido_connect/test_support/live_smoke_test.exs:"
          assert output =~ "set GOOGLE_ACCESS_TOKEN to run this live test"
        after
          ExUnit.configure(include: include)
        end
      end)
    end

    test "rejects variables the convention does not list" do
      assert_raise ArgumentError, ~r/SLACK_BOT_TOKN/, fn -> LiveSmoke.env!(["SLACK_BOT_TOKN"]) end
    end

    test "setup passes the values to the test context" do
      with_env(%{"JIRA_SITE" => "https://example.atlassian.net"}, fn ->
        assert %{env: %{"JIRA_SITE" => "https://example.atlassian.net"}} =
                 LiveSmoke.setup_live_env(%{live_env: ["JIRA_SITE"]})
      end)

      assert LiveSmoke.setup_live_env(%{}) == :ok

      with_env(%{"JIRA_SITE" => ""}, fn ->
        assert_raise ArgumentError, ~r/JIRA_SITE/, fn ->
          LiveSmoke.setup_live_env(%{live_env: ["JIRA_SITE"]})
        end
      end)
    end
  end

  describe "docs/live_smoke_tests.md" do
    test "lists exactly the variables of the convention" do
      documented =
        ~r/^\| `([A-Z0-9_]+)` \|/m
        |> Regex.scan(File.read!(@docs), capture: :all_but_first)
        |> List.flatten()
        |> MapSet.new()

      expected =
        LiveSmoke.variables()
        |> Enum.flat_map(fn {provider, groups} ->
          destructive = "#{provider |> Atom.to_string() |> String.upcase()}_LIVE_DESTRUCTIVE"
          [destructive | groups.credentials ++ groups.settings]
        end)
        |> MapSet.new()

      assert documented == expected
    end
  end

  describe "write!/1" do
    test "skips unless the provider's destructive variable is true" do
      for value <- [nil, "", "false", "1"] do
        with_env(%{"SLACK_LIVE_DESTRUCTIVE" => value}, fn ->
          tags = LiveSmoke.write!(:slack)

          assert tags[:live_write] == :slack
          assert tags[:skip] =~ "SLACK_LIVE_DESTRUCTIVE=true"
        end)
      end

      with_env(%{"SLACK_LIVE_DESTRUCTIVE" => "true"}, fn ->
        assert LiveSmoke.write!(:slack) == [live_write: :slack]
      end)
    end

    test "rejects unknown providers" do
      assert_raise ArgumentError, ~r/:github/, fn -> LiveSmoke.write!(:github) end
    end

    test "setup refuses a write test whose gate is closed" do
      with_env(%{"TEMPO_LIVE_DESTRUCTIVE" => nil}, fn ->
        assert_raise ArgumentError, ~r/TEMPO_LIVE_DESTRUCTIVE=true/, fn ->
          LiveSmoke.setup_live_env(%{live_write: :tempo})
        end
      end)

      assert_raise ArgumentError, ~r/write!\/1/, fn ->
        LiveSmoke.setup_live_env(%{live_write: true})
      end
    end
  end

  describe "sanitize" do
    test "drops auth headers and cookies" do
      headers = %{
        "authorization" => ["Bearer secret"],
        "cookie" => ["sid=1"],
        "set-cookie" => ["sid=2"],
        "x-slack-signature" => ["v0=abc"],
        "x-forwarded-for" => ["203.0.113.7"],
        "content-type" => ["application/json"]
      }

      assert LiveSmoke.sanitize_headers(headers) == %{"content-type" => ["application/json"]}
    end

    test "drops the CloudFront edge location header" do
      headers = %{"X-Amz-Cf-Pop" => ["FRA56-P5"], "x-amz-cf-id" => ["abc"], "via" => ["1.1 x"]}

      assert LiveSmoke.sanitize_headers(headers) == %{
               "x-amz-cf-id" => ["abc"],
               "via" => ["1.1 x"]
             }
    end

    test "redacts token fields and keeps Jira issue fields" do
      body = %{
        "access_token" => "ya29.secret",
        "nested" => [%{"refresh_token" => "1//secret", "ok" => true}],
        "fields" => %{"summary" => "Broken build"}
      }

      assert LiveSmoke.sanitize(body) == %{
               "access_token" => "[redacted]",
               "nested" => [%{"refresh_token" => "[redacted]", "ok" => true}],
               "fields" => %{"summary" => "Broken build"}
             }
    end

    test "replaces email addresses and display names with stable placeholders" do
      body = %{
        "attendees" => [
          %{"displayName" => "Ada Lovelace", "email" => "ada@corp.test"},
          %{"displayName" => "Grace Hopper", "email" => "grace@corp.test"}
        ],
        "creator" => %{"email" => "ada@corp.test"},
        "headers" => [
          %{"name" => "From", "value" => "Ada Lovelace <ada@corp.test>"},
          %{"name" => "To", "value" => "Charles Babbage <charles@corp.test>"}
        ],
        "text" => "Ada Lovelace invited Grace Hopper"
      }

      sanitized = LiveSmoke.sanitize(body)

      assert sanitized["attendees"] == [
               %{"displayName" => "Person 1", "email" => "person-1@example.com"},
               %{"displayName" => "Person 2", "email" => "person-2@example.com"}
             ]

      assert sanitized["creator"] == %{"email" => "person-1@example.com"}

      assert sanitized["headers"] == [
               %{"name" => "From", "value" => "Person 1 <person-1@example.com>"},
               %{"name" => "To", "value" => "Person 3 <person-3@example.com>"}
             ]

      assert sanitized["text"] == "Person 1 invited Person 2"

      for original <- ["Ada", "Grace", "Charles", "corp.test"] do
        refute inspect(sanitized) =~ original
      end
    end

    test "replaces configured fields with stable placeholders" do
      body = %{
        "messages" => [
          %{"text" => "first", "ts" => "1"},
          %{"text" => "second", "ts" => "2"},
          %{"text" => "first", "ts" => "3"}
        ],
        "snippet" => %{"lines" => ["a", "b"]}
      }

      assert LiveSmoke.sanitize(body, fields: ["text", "snippet"]) == %{
               "messages" => [
                 %{"text" => "text-1", "ts" => "1"},
                 %{"text" => "text-2", "ts" => "2"},
                 %{"text" => "text-1", "ts" => "3"}
               ],
               "snippet" => %{"lines" => ["snippet-1", "snippet-2"]}
             }
    end

    test "covers map keys, bare addresses, user names and whole words only" do
      body = %{
        "calendars" => %{"ada@corp.test" => %{"busy" => []}},
        "creator" => %{"displayName" => "Admin"},
        "message" => %{
          "username" => "ada.lovelace",
          "text" => "ada lovelace asked the Administrator"
        },
        "to" => "bob@corp.test, Ada Lovelace <ada@corp.test>"
      }

      assert LiveSmoke.sanitize(body) == %{
               "calendars" => %{"person-1@example.com" => %{"busy" => []}},
               "creator" => %{"displayName" => "Person 1"},
               "message" => %{
                 "username" => "Person 2",
                 "text" => "Person 3 asked the Administrator"
               },
               "to" => "person-2@example.com, Person 3 <person-1@example.com>"
             }
    end

    test "keeps keep_keys in form bodies and survives missing bodies and headers" do
      form = "fields=summary&token=xoxp-form-token&note=ada%40corp.test"

      assert {"fields=summary&token=%5Bredacted%5D&note=person-1%40example.com", _state} =
               Sanitize.body(form, "application/x-www-form-urlencoded", Sanitize.new([]))

      capture = %{
        "provider" => "github",
        "captured_at" => 1,
        "headers" => %{"x-github-event" => nil},
        "body" => nil
      }

      assert %{"body" => "", "headers" => %{"x-github-event" => nil}} =
               LiveSmoke.sanitize_capture(capture)
    end

    test "replaces tenant hosts of Atlassian sites and tunnels with stable example hosts" do
      body = %{
        "self" => "https://acme-live.atlassian.net/rest/api/3/issue/10001",
        "_links" => %{"base" => "https://ACME-LIVE.atlassian.net/wiki"},
        "other" => "https://second-site.atlassian.net/browse/KEY-1",
        "callback" => "https://quiet-otter-42.ngrok-free.dev/integrations/jira/webhook",
        "api" => "https://api.atlassian.com/ex/jira/1/rest/api/3/myself"
      }

      with_env(@no_sites, fn ->
        assert LiveSmoke.sanitize(body) == %{
                 "self" => "https://example.atlassian.net/rest/api/3/issue/10001",
                 "_links" => %{"base" => "https://example.atlassian.net/wiki"},
                 "other" => "https://example-2.atlassian.net/browse/KEY-1",
                 "callback" => "https://example.ngrok-free.dev/integrations/jira/webhook",
                 "api" => "https://api.atlassian.com/ex/jira/1/rest/api/3/myself"
               }
      end)
    end

    test "replaces the hosts of configured sites and of the public tunnel" do
      env =
        Map.merge(@no_sites, %{
          "JIRA_SITE" => "https://jira.acme.test",
          "CONFLUENCE_SITE" => "https://wiki.acme.test/wiki",
          "JIDO_PUBLIC_URL" => "https://dev-box.tunnel.test"
        })

      with_env(env, fn ->
        body = %{
          "self" => "https://jira.acme.test/rest/api/3/issue/1",
          "base" => "https://WIKI.acme.test/wiki",
          "redirect" => "https://dev-box.tunnel.test/callback",
          "docs" => "https://acme.test/handbook"
        }

        assert LiveSmoke.sanitize(body) == %{
                 "self" => "https://host-1.example.com/rest/api/3/issue/1",
                 "base" => "https://host-2.example.com/wiki",
                 "redirect" => "https://host-3.example.com/callback",
                 "docs" => "https://acme.test/handbook"
               }
      end)
    end

    test "fails when a configured host in the shape of a placeholder appears" do
      # Such a host is not replaced, since it looks like a placeholder, and
      # so must not pass the leak guard either.
      for {variable, host} <- [
            {"JIRA_SITE", "example-3.atlassian.net"},
            {"JIDO_PUBLIC_URL", "example.acme-dev.test"}
          ] do
        with_env(Map.put(@no_sites, variable, "https://#{host}"), fn ->
          assert_raise LeakError, ~r/#{variable}/, fn ->
            LiveSmoke.sanitize(%{"self" => "https://#{host}/rest/api/3/myself"})
          end
        end)
      end
    end

    test "replaces Atlassian account IDs with stable placeholders, also inside URLs" do
      admin = "5d0000000000000000000001"
      user = "557058:00000000-0000-4000-8000-000000000002"

      body = %{
        "assignee" => %{"accountId" => admin},
        "author" => %{
          "accountId" => user,
          "self" => "https://example.test/rest/api/3/user?accountId=#{user}"
        },
        "link" => "https://example.test/user?accountId=#{URI.encode_www_form(user)}",
        "ownerId" => user,
        "version" => %{"authorId" => admin, "number" => 3}
      }

      assert LiveSmoke.sanitize(body) == %{
               "assignee" => %{"accountId" => "account-1"},
               "author" => %{
                 "accountId" => "account-2",
                 "self" => "https://example.test/rest/api/3/user?accountId=account-2"
               },
               "link" => "https://example.test/user?accountId=account-2",
               "ownerId" => "account-2",
               "version" => %{"authorId" => "account-1", "number" => 3}
             }
    end

    test "learns account IDs from the user fields of Jira changelog items" do
      former = "5d0000000000000000000006"
      new = "557058:00000000-0000-4000-8000-000000000007"

      item = %{
        "fieldId" => "assignee",
        "from" => former,
        "tmpFromAccountId" => former,
        "to" => new,
        "tmpToAccountId" => new
      }

      assert LiveSmoke.sanitize(%{"changelog" => %{"items" => [item]}}) == %{
               "changelog" => %{
                 "items" => [
                   %{
                     "fieldId" => "assignee",
                     "from" => "account-1",
                     "tmpFromAccountId" => "account-1",
                     "to" => "account-2",
                     "tmpToAccountId" => "account-2"
                   }
                 ]
               }
             }
    end

    test "learns account IDs from ADF mentions" do
      id = "557058:00000000-0000-4000-8000-000000000008"

      # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/mention/
      mention = %{
        "type" => "mention",
        "attrs" => %{"id" => id, "text" => "@Person 1", "accessLevel" => ""}
      }

      # The ID of a mentioned collection is too short to be an account ID; it
      # stays, and so does the text that contains it.
      collection = %{"type" => "mention", "attrs" => %{"id" => "all", "text" => "@all"}}
      install = %{"type" => "text", "text" => "Install it for all"}

      body = %{
        "description" => %{
          "type" => "doc",
          "version" => 1,
          "content" => [%{"type" => "paragraph", "content" => [mention, collection, install]}]
        },
        "self" => "https://example.test/rest/api/3/user?accountId=#{URI.encode_www_form(id)}"
      }

      sanitized = LiveSmoke.sanitize(body)

      assert get_in(sanitized, ["description", "content", Access.at(0), "content"]) == [
               %{
                 "type" => "mention",
                 "attrs" => %{"id" => "account-1", "text" => "@Person 1", "accessLevel" => ""}
               },
               collection,
               install
             ]

      assert sanitized["self"] == "https://example.test/rest/api/3/user?accountId=account-1"
    end

    test "learns account IDs from ADF mentions inside a JSON string, as Confluence returns ADF" do
      id = "557058:00000000-0000-4000-8000-000000000015"

      adf = %{
        "type" => "doc",
        "version" => 1,
        "content" => [
          %{
            "type" => "paragraph",
            "content" => [
              %{"type" => "mention", "attrs" => %{"id" => id, "text" => "@Person 1"}},
              %{"type" => "text", "text" => " please review"}
            ]
          }
        ]
      }

      # `GET /api/v2/pages/{id}?body-format=atlas_doc_format`
      body = %{
        "id" => "98305",
        "body" => %{
          "atlas_doc_format" => %{
            "representation" => "atlas_doc_format",
            "value" => Jason.encode!(adf)
          }
        }
      }

      sanitized = with_env(@no_sites, fn -> LiveSmoke.sanitize(body) end)

      value = sanitized["body"]["atlas_doc_format"]["value"]
      refute value =~ id
      assert value == Jason.encode!(adf) |> String.replace(id, "account-1")
      assert LiveSmoke.sanitize(sanitized) == sanitized
    end

    test "learns the account ID of the x-aaccountid response header" do
      id = "5d0000000000000000000009"

      assert LiveSmoke.sanitize_headers(%{"x-aaccountid" => [id], "x-arequestid" => ["abc"]}) ==
               %{"x-aaccountid" => ["account-1"], "x-arequestid" => ["abc"]}
    end

    test "decodes a percent-encoded x-aaccountid header before learning its account ID" do
      # Atlassian sends `<prefix>:<uuid>` IDs in this header with the colon
      # percent-encoded. The user is the same person as the body's accountId.
      id = "712020:00000000-0000-4000-8000-0000000000aa"
      encoded = "712020%3A00000000-0000-4000-8000-0000000000aa"

      fixture = %{
        "request" => %{"method" => "GET", "path" => "/rest/api/3/myself"},
        "status" => 200,
        "headers" => %{"x-aaccountid" => [encoded]},
        "body" => %{
          "accountId" => id,
          "self" => "https://example.atlassian.net/rest/api/3/user?accountId=#{encoded}"
        }
      }

      with_env(@no_sites, fn ->
        assert LiveSmoke.sanitize_fixture(fixture) == %{
                 fixture
                 | "headers" => %{"x-aaccountid" => ["account-1"]},
                   "body" => %{
                     "accountId" => "account-1",
                     "self" => "https://example.atlassian.net/rest/api/3/user?accountId=account-1"
                   }
               }
      end)
    end

    test "fails when a site host, a configured email or an account ID survives encoded" do
      site = "acme-live.atlassian.net"
      email = "tester@acme.test"
      id = "557058:00000000-0000-4000-8000-000000000003"
      env = Map.merge(@no_sites, %{"JIRA_SITE" => "https://#{site}", "JIRA_EMAIL" => email})

      with_env(env, fn ->
        for {body, source} <- [
              {%{"blob" => Base.encode64(site)}, "JIRA_SITE"},
              {%{"blob" => Base.encode64(email)}, "JIRA_EMAIL"},
              {%{"accountId" => id, "blob" => Base.encode64(id)}, "an account ID"}
            ] do
          error = assert_raise LeakError, fn -> LiveSmoke.sanitize(body) end
          assert Exception.message(error) =~ source

          for value <- [site, email, id] do
            refute Exception.message(error) =~ value
          end
        end
      end)

      with_env(@no_sites, fn ->
        assert_raise LeakError, ~r/tenant host/, fn ->
          LiveSmoke.sanitize(%{"self" => "https://#{site}/x", "blob" => Base.encode64(site)})
        end
      end)
    end

    test "fails when a guarded value is Base64-encoded at any offset of a longer value" do
      # With `~~~` each value encodes with `+` or `/` at every offset, so the
      # standard and the URL-safe encodings of the value differ.
      calendar = "tester~~~@acme.test"
      token = "ya29.live-smoke~~~offset-check"

      env =
        Map.merge(@no_sites, %{"GOOGLE_CALENDAR_ID" => calendar, "GOOGLE_ACCESS_TOKEN" => token})

      with_env(env, fn ->
        # The `eid` of a Calendar `htmlLink` is base64url of "<event ID> <calendar ID>".
        for event_id <- ["e", "ev", "evt", "evt0"],
            encode <- [&Base.url_encode64(&1, padding: false), &Base.encode64/1] do
          eid = encode.("#{event_id} #{calendar}")
          link = "https://www.google.com/calendar/event?eid=#{eid}"

          assert_raise LeakError, ~r/GOOGLE_CALENDAR_ID/, fn ->
            LiveSmoke.sanitize(%{"htmlLink" => link})
          end

          blob = encode.("#{event_id}:#{token}:#{event_id}")

          assert_raise LeakError, ~r/GOOGLE_ACCESS_TOKEN/, fn ->
            LiveSmoke.sanitize(%{"state" => blob})
          end
        end
      end)
    end

    test "sanitizes Base64 content under data and raw and encodes it the same way again" do
      # The leading "???" encodes as "Pz8/" in the standard alphabet and as
      # "Pz8_" in the URL-safe one, and both lengths leave padding.
      text = "??? Hello Ada Lovelace,\r\nplease write to ada@corp.test."
      clean = "??? Hello Person 1,\r\nplease write to person-1@example.com."
      # A non-canonical encoding of "Hello": its last character carries bits
      # that decoding drops, so only an unchanged original keeps it.
      untouched = "SGVsbG9="
      binary = Base.url_encode64(<<0xFF, 0xD8, 0xFF, 0x00>> <> "ada@corp.test")
      unpadded = Base.url_encode64("Reply to ada@corp.test", padding: false)

      body = %{
        "payload" => %{
          "headers" => [%{"name" => "From", "value" => "Ada Lovelace <ada@corp.test>"}],
          "parts" => [
            %{"body" => %{"size" => 55, "data" => Base.url_encode64(text)}},
            %{"body" => %{"size" => 5, "data" => untouched}},
            %{"body" => %{"attachmentId" => "ANGjdJ8", "size" => 17, "data" => binary}},
            %{"body" => %{"size" => 22, "data" => unpadded}}
          ]
        },
        "raw" => Base.encode64(text),
        "data" => %{"note" => "write to ada@corp.test"},
        "items" => [%{"data" => "plain text, not Base64"}]
      }

      sanitized = LiveSmoke.sanitize(body)

      assert [
               %{"body" => %{"size" => 55, "data" => data}},
               %{"body" => %{"size" => 5, "data" => ^untouched}},
               %{"body" => %{"data" => ^binary}},
               %{"body" => %{"data" => short}}
             ] = sanitized["payload"]["parts"]

      assert data == Base.url_encode64(clean)
      assert short == Base.url_encode64("Reply to person-1@example.com", padding: false)
      assert sanitized["raw"] == Base.encode64(clean)
      assert sanitized["data"] == %{"note" => "write to person-1@example.com"}
      assert sanitized["items"] == [%{"data" => "plain text, not Base64"}]
      assert LiveSmoke.sanitize(sanitized) == sanitized
    end

    test "takes the alphabet and the padding of Base64 content from the original" do
      # Neither original holds a character that only one alphabet has, so both
      # count as URL-safe, Gmail's alphabet: "Person 1?" encodes as
      # "UGVyc29uIDE_" there and as "UGVyc29uIDE/" in the standard one. The
      # second original has no `=` but a length that padding would give, so
      # its sanitized text is padded again.
      body = %{
        "payload" => %{
          "headers" => [%{"name" => "From", "value" => "Ada Lovelace <ada@corp.test>"}],
          "parts" => [
            %{"body" => %{"data" => "QWRhIExvdmVsYWNlPw=="}},
            %{"body" => %{"data" => "SGkgQWRhIExvdmVsYWNl"}}
          ]
        }
      }

      assert [
               %{"body" => %{"data" => "UGVyc29uIDE_"}},
               %{"body" => %{"data" => "SGkgUGVyc29uIDE="}}
             ] = LiveSmoke.sanitize(body)["payload"]["parts"]
    end

    test "sanitizes a string under data or raw that is not Base64 as plain text" do
      body = %{
        "headers" => [%{"name" => "From", "value" => "Ada Lovelace <ada@corp.test>"}],
        "items" => [
          %{"data" => "Ada Lovelace wrote from ada@corp.test"},
          %{"raw" => "From: Ada Lovelace <ada@corp.test>"}
        ]
      }

      assert LiveSmoke.sanitize(body)["items"] == [
               %{"data" => "Person 1 wrote from person-1@example.com"},
               %{"raw" => "From: Person 1 <person-1@example.com>"}
             ]
    end

    test "keeps documentation addresses inside Base64 content, whose size the provider states" do
      # A seeded original names only addresses under reserved example names.
      # Rewriting them would change the content's length, which Gmail states
      # in `size` and checks when the content is fetched.
      original =
        "From: Opaque Sender <opaque.sender@example.org>\r\n" <>
          "To: ada@corp.test\r\nMessage-ID: <seed-1@jcl-live.invalid>\r\n"

      body = %{
        "headers" => [%{"name" => "Cc", "value" => "opaque.sender@example.org"}],
        "attachment" => %{"size" => byte_size(original), "data" => Base.url_encode64(original)}
      }

      sanitized = LiveSmoke.sanitize(body)

      assert sanitized["headers"] == [%{"name" => "Cc", "value" => "person-1@example.com"}]

      assert Base.url_decode64!(sanitized["attachment"]["data"]) ==
               "From: Opaque Sender <opaque.sender@example.org>\r\n" <>
                 "To: person-2@example.com\r\nMessage-ID: <seed-1@jcl-live.invalid>\r\n"

      documentation_only = %{
        "data" => Base.url_encode64(String.replace(original, "ada@corp.test", "x@example.net"))
      }

      assert LiveSmoke.sanitize(documentation_only) == documentation_only
    end

    test "leaves an already sanitized value unchanged" do
      body = %{
        "self" => "https://acme-live.atlassian.net/rest/api/3/issue/1",
        "callback" => "https://quiet-otter-42.ngrok-free.dev/hook",
        "author" => %{"accountId" => "5d0000000000000000000005", "displayName" => "Ada Lovelace"},
        "note" => "ada@corp.test"
      }

      with_env(@no_sites, fn ->
        once = LiveSmoke.sanitize(body)
        assert LiveSmoke.sanitize(once) == once
      end)
    end

    test "keeps its own placeholders and gives new values numbers no placeholder holds" do
      # The second fixture of a recording continues the numbering of the
      # first, so its placeholders need not start at 1. The changelog item
      # holds the placeholder of `fields: ["tmpFromAccountId"]`.
      body = %{
        "a" => %{
          "displayName" => "Person 2",
          "emailAddress" => "person-2@example.com",
          "accountId" => "account-2",
          "self" => "https://example-2.atlassian.net/rest/api/3/user?accountId=account-2"
        },
        "b" => %{"displayName" => "Person 1", "emailAddress" => "person-1@example.com"},
        "c" => %{
          "displayName" => "Grace Hopper",
          "emailAddress" => "grace@corp.test",
          "accountId" => "5d0000000000000000000011",
          "self" => "https://grace-site.atlassian.net/rest/api/3/myself"
        },
        "items" => [%{"from" => "from-1", "tmpFromAccountId" => "tmpFromAccountId-1"}]
      }

      with_env(@no_sites, fn ->
        assert LiveSmoke.sanitize(body) == %{
                 body
                 | "c" => %{
                     "displayName" => "Person 3",
                     "emailAddress" => "person-3@example.com",
                     "accountId" => "account-1",
                     "self" => "https://example.atlassian.net/rest/api/3/myself"
                   }
               }
      end)
    end

    test "keeps the <field>-<n> placeholders of fields: and numbers new values around them" do
      # The second page of a recording with `fields: ["htmlLink"]` continues
      # the numbering of the first.
      link = "https://www.google.com/calendar/event?eid=ZXZ0MCBjYWw"

      body = %{
        "items" => [
          %{"htmlLink" => "htmlLink-6"},
          %{"htmlLink" => link},
          %{"htmlLink" => "htmlLink-7"},
          %{"htmlLink" => link}
        ]
      }

      assert LiveSmoke.sanitize(body, fields: ["htmlLink"]) == %{
               "items" => [
                 %{"htmlLink" => "htmlLink-6"},
                 %{"htmlLink" => "htmlLink-1"},
                 %{"htmlLink" => "htmlLink-7"},
                 %{"htmlLink" => "htmlLink-1"}
               ]
             }

      sanitized = %{"items" => [%{"htmlLink" => "htmlLink-1"}, %{"htmlLink" => link}]}

      assert LiveSmoke.sanitize(sanitized, fields: ["htmlLink"]) == %{
               "items" => [%{"htmlLink" => "htmlLink-1"}, %{"htmlLink" => "htmlLink-2"}]
             }
    end

    test "replaces the Google project number of GOOGLE_CLIENT_ID wherever it is a whole number" do
      # An invented number in the shape of a Cloud project number.
      number = "987654321098"
      client_id = "#{number}-0abc1def2ghi.apps.googleusercontent.com"

      body = %{
        "headers" => [
          %{
            "name" => "Received",
            "value" => "from #{number} named unknown by gmailapi.google.com with HTTPREST"
          }
        ],
        "client" => client_id,
        "topic" => "projects/#{number}/topics/inbox",
        number => "keyed by the number",
        "shorter" => "98765432109"
      }

      with_env(Map.put(@no_sites, "GOOGLE_CLIENT_ID", client_id), fn ->
        sanitized = LiveSmoke.sanitize(body)

        assert sanitized == %{
                 "headers" => [
                   %{
                     "name" => "Received",
                     "value" =>
                       "from 000000000000 named unknown by gmailapi.google.com with HTTPREST"
                   }
                 ],
                 "client" => "000000000000-0abc1def2ghi.apps.googleusercontent.com",
                 "topic" => "projects/000000000000/topics/inbox",
                 "000000000000" => "keyed by the number",
                 "shorter" => "98765432109"
               }

        assert LiveSmoke.sanitize(sanitized) == sanitized
      end)
    end

    test "fails when the Google project number survives encoded or inside a longer number" do
      number = "987654321098"

      env =
        Map.put(
          @no_sites,
          "GOOGLE_CLIENT_ID",
          "#{number}-0abc1def2ghi.apps.googleusercontent.com"
        )

      with_env(env, fn ->
        # The replacement keeps other numbers intact, so the guard reports this one.
        for body <- [%{"blob" => Base.encode64(number)}, %{"internalDate" => "1#{number}"}] do
          error = assert_raise LeakError, fn -> LiveSmoke.sanitize(body) end
          assert Exception.message(error) =~ "the Google project number"
          refute Exception.message(error) =~ number
        end
      end)
    end

    test "replaces Google user IDs of Meet participants wherever they are whole numbers" do
      # Invented numbers in the shape of Google user IDs.
      signed_in = "123456789012345678901"
      other = "109876543210987654321"
      record = "conferenceRecords/rec-1"

      body = %{
        "participants" => [
          %{
            "name" => "#{record}/participants/#{signed_in}",
            "signedinUser" => %{"user" => "users/#{signed_in}", "displayName" => "Ada Lovelace"}
          },
          %{
            "name" => "#{record}/participants/#{other}",
            "anonymousUser" => %{"displayName" => "Grace Hopper"}
          },
          %{
            "name" => "#{record}/participants/caller-1",
            "phoneUser" => %{"displayName" => "Charles Babbage"}
          }
        ],
        "transcriptEntry" => %{
          "participant" => "#{record}/participants/#{other}",
          "note" => other
        },
        signed_in => "keyed by the ID",
        "longer" => "1#{signed_in}0"
      }

      with_env(@no_sites, fn ->
        # The longer number keeps the ID, so the guard reports it.
        assert_raise LeakError, ~r/a Google user ID/, fn -> LiveSmoke.sanitize(body) end

        sanitized = LiveSmoke.sanitize(Map.delete(body, "longer"))

        assert sanitized == %{
                 "participants" => [
                   %{
                     "name" => "#{record}/participants/user-1",
                     "signedinUser" => %{"user" => "users/user-1", "displayName" => "Person 1"}
                   },
                   %{
                     "name" => "#{record}/participants/user-2",
                     "anonymousUser" => %{"displayName" => "Person 2"}
                   },
                   %{
                     "name" => "#{record}/participants/caller-1",
                     "phoneUser" => %{"displayName" => "Person 3"}
                   }
                 ],
                 "transcriptEntry" => %{
                   "participant" => "#{record}/participants/user-2",
                   "note" => "user-2"
                 },
                 "user-1" => "keyed by the ID"
               }

        assert LiveSmoke.sanitize(sanitized) == sanitized
      end)
    end

    test "learns Google user IDs only from whole numeric user and participant segments" do
      body = %{
        "missing" => "conferenceRecords/rec-1/participants/00000000-0000-0000-0000-000000000000",
        "short" => "users/1234567",
        "gmail" => "/gmail/v1/users/me/messages/1a18d3805a1eca34",
        "suffixed" => "users/12345678901234567890abc",
        "embedded" => "superusers/12345678901234567890",
        "id" => "12345678901234567890"
      }

      with_env(@no_sites, fn -> assert LiveSmoke.sanitize(body) == body end)
    end

    test "fails when a Google user ID survives encoded, naming only the kind of value" do
      id = "123456789012345678901"

      error =
        assert_raise LeakError, fn ->
          LiveSmoke.sanitize(%{"user" => "users/#{id}", "blob" => Base.encode64(id)})
        end

      assert Exception.message(error) =~ "a Google user ID"
      refute Exception.message(error) =~ id
    end

    test "keeps user-<n> placeholders and gives new Google user IDs numbers none of them holds" do
      # A later fixture of a Meet recording names user-1 already.
      id = "123456789012345678901"

      body = %{
        "first" => "conferenceRecords/rec-1/participants/user-1",
        "second" => %{"signedinUser" => %{"user" => "users/#{id}"}}
      }

      with_env(@no_sites, fn ->
        assert LiveSmoke.sanitize(body) == %{
                 "first" => "conferenceRecords/rec-1/participants/user-1",
                 "second" => %{"signedinUser" => %{"user" => "users/user-2"}}
               }
      end)
    end

    test "treats Google user IDs in Base64 content and in users: like account IDs" do
      id = "123456789012345678901"
      known = "109876543210987654321"

      body = %{
        "payload" => %{
          "parts" => [
            %{"body" => %{"data" => Base.url_encode64("Joined as users/#{id} today")}},
            %{"body" => %{"data" => Base.url_encode64("Organizer #{known}")}}
          ]
        },
        "path" => "/v2/conferenceRecords/rec-1/participants/#{known}"
      }

      with_env(@no_sites, fn ->
        sanitized = LiveSmoke.sanitize(body, users: [known])

        assert [first, second] = sanitized["payload"]["parts"]
        assert Base.url_decode64!(first["body"]["data"]) == "Joined as users/user-2 today"
        assert Base.url_decode64!(second["body"]["data"]) == "Organizer user-1"
        assert sanitized["path"] == "/v2/conferenceRecords/rec-1/participants/user-1"

        for blob <- [Base.encode64("x#{known}"), Base.url_encode64("xy:#{known}")] do
          assert_raise LeakError, ~r/a Google user ID/, fn ->
            LiveSmoke.check_leaks!(%{"note" => blob}, users: [known])
          end
        end

        assert LiveSmoke.check_leaks!(sanitized, users: [known]) == :ok
      end)
    end

    test "guards credential-shaped variables that the convention does not list" do
      secret = "seed-only-secret-value"

      with_env(%{"LIVE_SMOKE_EXTRA_API_TOKEN" => secret}, fn ->
        assert_raise LeakError, ~r/LIVE_SMOKE_EXTRA_API_TOKEN/, fn ->
          LiveSmoke.sanitize(%{"note" => secret})
        end
      end)
    end

    test "never shows credential values when the sanitizer state is inspected" do
      token = "xoxb-live-smoke-inspect-check"
      refute inspect(Sanitize.new(credentials: [{"SLACK_BOT_TOKEN", token}])) =~ token
    end

    test "fails when a credential variable's value appears, naming only the variable" do
      token = "xoxb-live-smoke-leak-check"

      with_env(%{"SLACK_BOT_TOKEN" => token}, fn ->
        error =
          assert_raise LeakError, fn ->
            LiveSmoke.sanitize(%{"note" => "token is #{token}"})
          end

        assert Exception.message(error) =~ "SLACK_BOT_TOKEN"
        refute Exception.message(error) =~ token
      end)

      refresh = "1//live-smoke-refresh"

      with_env(%{"GOOGLE_REFRESH_TOKEN" => refresh}, fn ->
        for encoded <- [URI.encode_www_form(refresh), Base.encode64(refresh)] do
          assert_raise LeakError, ~r/GOOGLE_REFRESH_TOKEN/, fn ->
            LiveSmoke.sanitize(%{"next" => "https://example.test/?t=#{encoded}"})
          end
        end
      end)
    end

    test "check_leaks!/2 finds guarded values in a value as it is, also under redacted keys" do
      # A synthetic fixture is written by hand; sanitizing it first would
      # redact the token and replace the host and the address.
      token = "ya29.live-smoke-synthetic-check"

      env =
        Map.merge(@no_sites, %{
          "GOOGLE_ACCESS_TOKEN" => token,
          "JIRA_SITE" => "https://acme-live.atlassian.net",
          "JIRA_EMAIL" => "tester@acme.test"
        })

      with_env(env, fn ->
        for {fixture, source} <- [
              {%{"access_token" => token}, "GOOGLE_ACCESS_TOKEN"},
              {%{"self" => "https://acme-live.atlassian.net/rest/api/3/myself"}, "JIRA_SITE"},
              {%{"emailAddress" => "tester@acme.test"}, "JIRA_EMAIL"}
            ] do
          assert_raise LeakError, ~r/#{source}/, fn -> LiveSmoke.check_leaks!(fixture) end
        end

        clean = %{
          "access_token" => "stub-access-token",
          "self" => "https://example.atlassian.net/rest/api/3/myself",
          "emailAddress" => "person-1@example.com"
        }

        assert LiveSmoke.check_leaks!(clean) == :ok
      end)
    end
  end

  describe "record/4 and fixture!/3" do
    test "records a stub response that fixture!/3 returns unchanged for Req.Test.json/2", %{
      tmp: tmp
    } do
      body = %{"id" => "user-1", "items" => [%{"kind" => "label", "count" => 2}], "ok" => true}
      base_url = start_stub([{200, body}, {200, %{"page" => 2}}])

      with_env(%{"JIDO_CONNECT_RECORD" => "1"}, fn ->
        put_req_options(retry: false)
        assert :ok = LiveSmoke.record({:jido_connect, @req_key}, :stub, "profile", root: tmp)
        assert Application.get_env(:jido_connect, @req_key)[:adapter] == LiveSmoke.Recorder

        assert {:ok, %Req.Response{status: 200, body: ^body}} = get(base_url, "/v1/profile")

        assert {:ok, %Req.Response{body: %{"page" => 2}}} =
                 get(base_url, "/v1/calendars/ada%40corp.test")
      end)

      recorded = Path.join(tmp, "test/fixtures/stub/recorded/profile.json")
      envelope = recorded |> File.read!() |> Jason.decode!()

      assert envelope["status"] == 200
      assert envelope["request"] == %{"method" => "GET", "path" => "/v1/profile"}
      assert envelope["recorded_at"] == Date.to_iso8601(Date.utc_today())
      assert envelope["headers"]["content-type"] == ["application/json"]
      refute Map.has_key?(envelope["headers"], "set-cookie")
      refute File.read!(recorded) =~ "stub-access-token"

      assert LiveSmoke.fixture!(:stub, "profile", root: tmp) == body
      assert LiveSmoke.fixture!(:stub, "profile.2", root: tmp) == %{"page" => 2}

      second = Path.join(tmp, "test/fixtures/stub/recorded/profile.2.json")

      assert %{"path" => "/v1/calendars/person-1@example.com"} =
               second |> File.read!() |> Jason.decode!() |> Map.fetch!("request")

      fixture = LiveSmoke.fixture!(:stub, "profile", root: tmp)
      Req.Test.stub(__MODULE__, &Req.Test.json(&1, fixture))
      put_req_options(plug: {Req.Test, __MODULE__})

      assert {:ok, %Req.Response{status: 200, body: ^body}} =
               get("http://stub.test", "/v1/profile")
    end

    test "fails the recording when a credential value appears in the response", %{tmp: tmp} do
      token = "ya29.live-smoke-recorded-leak"
      base_url = start_stub([{200, %{"echo" => token}}])

      with_env(%{"JIDO_CONNECT_RECORD" => "1", "GOOGLE_ACCESS_TOKEN" => token}, fn ->
        put_req_options(retry: false)
        :ok = LiveSmoke.record({:jido_connect, @req_key}, :stub, "leak", root: tmp)

        error = assert_raise LeakError, fn -> get(base_url, "/v1/echo") end
        assert Exception.message(error) =~ "GOOGLE_ACCESS_TOKEN"
        refute Exception.message(error) =~ token
      end)

      refute File.exists?(Path.join(tmp, "test/fixtures/stub/recorded/leak.json"))
    end

    test "records site hosts and account IDs as placeholders", %{tmp: tmp} do
      body = %{
        "self" => "https://acme-live.atlassian.net/rest/api/3/issue/10001",
        "fields" => %{"assignee" => %{"accountId" => "5d0000000000000000000004"}}
      }

      base_url = start_stub([{200, body}])

      with_env(Map.put(@no_sites, "JIDO_CONNECT_RECORD", "1"), fn ->
        put_req_options(retry: false)
        :ok = LiveSmoke.record({:jido_connect, @req_key}, :stub, "issue", root: tmp)
        assert {:ok, %Req.Response{status: 200}} = get(base_url, "/rest/api/3/issue/10001")
      end)

      assert LiveSmoke.fixture!(:stub, "issue", root: tmp) == %{
               "self" => "https://example.atlassian.net/rest/api/3/issue/10001",
               "fields" => %{"assignee" => %{"accountId" => "account-1"}}
             }
    end

    test "records a Google user ID of the request path as a placeholder", %{tmp: tmp} do
      id = "123456789012345678901"
      path = "/v2/conferenceRecords/rec-1/participants/#{id}"
      not_found = %{"error" => %{"code" => 404, "status" => "NOT_FOUND"}}
      base_url = start_stub([{404, not_found}, {200, %{"user" => "users/#{id}"}}])

      with_env(Map.put(@no_sites, "JIDO_CONNECT_RECORD", "1"), fn ->
        put_req_options(retry: false)
        :ok = LiveSmoke.record({:jido_connect, @req_key}, :stub, "participant", root: tmp)
        assert {:ok, %Req.Response{status: 404}} = get(base_url, path)
        assert {:ok, %Req.Response{status: 200}} = get(base_url, path)
      end)

      dir = Path.join(tmp, "test/fixtures/stub/recorded")

      for file <- ["participant.json", "participant.2.json"] do
        envelope = dir |> Path.join(file) |> File.read!() |> Jason.decode!()
        assert envelope["request"]["path"] == "/v2/conferenceRecords/rec-1/participants/user-1"
        refute Jason.encode!(envelope) =~ id
      end

      assert LiveSmoke.fixture!(:stub, "participant.2", root: tmp) == %{"user" => "users/user-1"}
    end

    test "replaces an account ID that only the x-aaccountid header names, also in the body",
         %{tmp: tmp} do
      # Atlassian percent-encodes the colon of such an ID in the header.
      id = "712020:00000000-0000-4000-8000-0000000000aa"
      body = %{"issues" => [], "query" => "assignee = \"#{id}\""}
      base_url = start_stub([{200, body, [{"x-aaccountid", URI.encode_www_form(id)}]}])

      with_env(Map.put(@no_sites, "JIDO_CONNECT_RECORD", "1"), fn ->
        put_req_options(retry: false)
        :ok = LiveSmoke.record({:jido_connect, @req_key}, :stub, "search", root: tmp)

        assert {:ok, %Req.Response{status: 200, body: ^body}} =
                 get(base_url, "/rest/api/3/search")
      end)

      envelope =
        Path.join(tmp, "test/fixtures/stub/recorded/search.json")
        |> File.read!()
        |> Jason.decode!()

      assert envelope["body"] == %{"issues" => [], "query" => "assignee = \"account-1\""}
      assert envelope["headers"]["x-aaccountid"] == ["account-1"]
    end

    test "replaces known account IDs in path and links even when the first page is empty",
         %{tmp: tmp} do
      id = "557058:00000000-0000-4000-8000-000000000012"
      encoded = URI.encode_www_form(id)

      page = %{
        "self" => "https://api.tempo.io/4/worklogs/user/#{encoded}?from=2026-11-02&to=2026-11-02",
        "metadata" => %{"count" => 0, "offset" => 0, "limit" => 50},
        "results" => []
      }

      base_url = start_stub([{200, page}])

      with_env(Map.put(@no_sites, "JIDO_CONNECT_RECORD", "1"), fn ->
        put_req_options(retry: false)

        :ok =
          LiveSmoke.record({:jido_connect, @req_key}, :stub, "own_worklogs",
            root: tmp,
            accounts: [id]
          )

        assert {:ok, %Req.Response{body: ^page}} = get(base_url, "/4/worklogs/user/#{encoded}")
      end)

      envelope =
        Path.join(tmp, "test/fixtures/stub/recorded/own_worklogs.json")
        |> File.read!()
        |> Jason.decode!()

      assert envelope["request"]["path"] == "/4/worklogs/user/account-1"

      assert envelope["body"]["self"] ==
               "https://api.tempo.io/4/worklogs/user/account-1?from=2026-11-02&to=2026-11-02"
    end

    test "sanitize_fixture/2 leaves every file of a recording unchanged", %{tmp: tmp} do
      ada = %{"accountId" => "5d0000000000000000000013", "displayName" => "Ada Lovelace"}
      grace = %{"accountId" => "5d0000000000000000000014", "displayName" => "Grace Hopper"}

      base_url =
        start_stub([
          {200, %{"author" => ada, "note" => "ada@corp.test"},
           [{"x-aaccountid", ada["accountId"]}]},
          {200,
           %{"author" => grace, "watchers" => [ada], "note" => "grace@corp.test, ada@corp.test"},
           [{"x-aaccountid", ada["accountId"]}]}
        ])

      with_env(Map.put(@no_sites, "JIDO_CONNECT_RECORD", "1"), fn ->
        put_req_options(retry: false)
        :ok = LiveSmoke.record({:jido_connect, @req_key}, :stub, "people", root: tmp)
        assert {:ok, %Req.Response{status: 200}} = get(base_url, "/rest/api/3/issue/1")
        assert {:ok, %Req.Response{status: 200}} = get(base_url, "/rest/api/3/issue/2")
      end)

      for name <- ["people.json", "people.2.json"] do
        fixture =
          Path.join([tmp, "test/fixtures/stub/recorded", name]) |> File.read!() |> Jason.decode!()

        assert LiveSmoke.sanitize_fixture(fixture) == fixture
      end

      assert %{"author" => %{"accountId" => "account-2", "displayName" => "Person 2"}} =
               LiveSmoke.fixture!(:stub, "people.2", root: tmp)
    end

    test "keeps names known only with documentation addresses inside Base64 content",
         %{tmp: tmp} do
      # messages.get, then attachments.get for the enclosed seed message, as in
      # one Gmail recording. The seed names synthetic senders under
      # example.org; Gmail states the attachment's size in the first response.
      original =
        "From: Opaque Sender <opaque.sender@example.org>\r\n" <>
          "To: Opaque Recipient <opaque.recipient@example.org>\r\n\r\n"

      message = %{
        "payload" => %{
          "headers" => [
            %{"name" => "From", "value" => "Ada Lovelace <ada@corp.test>"},
            %{"name" => "To", "value" => "Opaque Recipient <opaque.recipient@example.org>"},
            %{"name" => "Cc", "value" => "Grace Hopper <grace@example.net>"},
            %{"name" => "Reply-To", "value" => "Grace Hopper <grace@corp.test>"}
          ],
          "parts" => [
            %{
              "partId" => "0",
              "body" => %{
                "data" =>
                  Base.url_encode64("Hi Opaque Recipient,\r\nAda Lovelace, Grace Hopper\r\n")
              }
            },
            %{
              "partId" => "1",
              "headers" => [
                %{"name" => "From", "value" => "Opaque Sender <opaque.sender@example.org>"}
              ],
              "body" => %{"attachmentId" => "ANGjdJ8", "size" => byte_size(original)}
            }
          ]
        }
      }

      attachment = %{"size" => byte_size(original), "data" => Base.url_encode64(original)}
      base_url = start_stub([{200, message}, {200, attachment}])

      with_env(Map.put(@no_sites, "JIDO_CONNECT_RECORD", "1"), fn ->
        put_req_options(retry: false)
        :ok = LiveSmoke.record({:jido_connect, @req_key}, :stub, "opaque", root: tmp)
        assert {:ok, %Req.Response{status: 200}} = get(base_url, "/gmail/v1/users/me/messages/1")

        assert {:ok, %Req.Response{status: 200}} =
                 get(base_url, "/gmail/v1/users/me/messages/1/attachments/ANGjdJ8")
      end)

      recorded = LiveSmoke.fixture!(:stub, "opaque", root: tmp)
      [text, enclosed] = recorded["payload"]["parts"]

      # Outside Base64 content every name is replaced. Inside it, a name stays
      # only when the recording knows it with documentation addresses alone.
      refute inspect(recorded["payload"]["headers"]) =~ ~r/Opaque|Ada|Grace/
      refute inspect(enclosed["headers"]) =~ "Opaque"

      assert Base.url_decode64!(text["body"]["data"]) ==
               "Hi Opaque Recipient,\r\nPerson 1, Person 3\r\n"

      assert LiveSmoke.fixture!(:stub, "opaque.2", root: tmp) == attachment
    end

    test "stores size and digest instead of a body that is not UTF-8", %{tmp: tmp} do
      bytes = <<0xFF, 0xD8, 0xFF, 0x00>>
      base_url = start_stub([{200, {:raw, "image/jpeg", bytes}}])

      with_env(%{"JIDO_CONNECT_RECORD" => "1"}, fn ->
        put_req_options(retry: false)
        :ok = LiveSmoke.record({:jido_connect, @req_key}, :stub, "download", root: tmp)
        assert {:ok, %Req.Response{status: 200, body: ^bytes}} = get(base_url, "/v1/file")
      end)

      envelope =
        Path.join(tmp, "test/fixtures/stub/recorded/download.json")
        |> File.read!()
        |> Jason.decode!()

      assert envelope["body"] == nil
      assert envelope["body_bytes"] == 4
      assert envelope["body_sha256"] == Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)
    end

    test "a transform changes or skips what is recorded, not what the caller gets", %{tmp: tmp} do
      page = %{
        "results" => [%{"key" => "OWN-1"}, %{"key" => "OTHER-1", "name" => "Other site data"}],
        "metadata" => %{"count" => 2}
      }

      other = %{"key" => "OTHER-1", "name" => "Other site data"}
      own = %{"key" => "OWN-1"}
      base_url = start_stub([{200, page}, {200, other}, {200, own}])

      transform = fn
        "/v1/items/other 1", _body ->
          :skip

        _path, %{"results" => results} = body ->
          kept = Enum.filter(results, &(&1["key"] == "OWN-1"))
          %{body | "results" => kept, "metadata" => %{"count" => length(kept)}}

        _path, body ->
          body
      end

      with_env(%{"JIDO_CONNECT_RECORD" => "1"}, fn ->
        put_req_options(retry: false)

        :ok =
          LiveSmoke.record({:jido_connect, @req_key}, :stub, "items",
            root: tmp,
            transform: transform
          )

        assert {:ok, %Req.Response{body: ^page}} = get(base_url, "/v1/items")
        assert {:ok, %Req.Response{body: ^other}} = get(base_url, "/v1/items/other%201")
        assert {:ok, %Req.Response{body: ^own}} = get(base_url, "/v1/items/own-1")
      end)

      assert LiveSmoke.fixture!(:stub, "items", root: tmp) == %{
               "results" => [%{"key" => "OWN-1"}],
               "metadata" => %{"count" => 1}
             }

      # The skipped response takes no number, so the next one is items.2.
      assert LiveSmoke.fixture!(:stub, "items.2", root: tmp) == own

      dir = Path.join(tmp, "test/fixtures/stub/recorded")
      assert dir |> File.ls!() |> Enum.sort() == ["items.2.json", "items.json"]

      for file <- File.ls!(dir) do
        refute dir |> Path.join(file) |> File.read!() =~ "Other site data"
      end
    end

    test "marks a fixture whose body the transform changed", %{tmp: tmp} do
      base_url = start_stub([{200, %{"results" => [1, 2]}}, {200, %{"results" => [1]}}])

      transform = fn
        "/v1/changed", %{"results" => results} = body ->
          %{body | "results" => Enum.take(results, 1)}

        _path, body ->
          body
      end

      with_env(%{"JIDO_CONNECT_RECORD" => "1"}, fn ->
        put_req_options(retry: false)

        :ok =
          LiveSmoke.record({:jido_connect, @req_key}, :stub, "marked",
            root: tmp,
            transform: transform
          )

        assert {:ok, %Req.Response{body: %{"results" => [1, 2]}}} = get(base_url, "/v1/changed")
        assert {:ok, %Req.Response{body: %{"results" => [1]}}} = get(base_url, "/v1/same")
      end)

      dir = Path.join(tmp, "test/fixtures/stub/recorded")
      changed = dir |> Path.join("marked.json") |> File.read!() |> Jason.decode!()
      unchanged = dir |> Path.join("marked.2.json") |> File.read!() |> Jason.decode!()

      assert changed["transformed"] == true
      refute Map.has_key?(unchanged, "transformed")
      assert LiveSmoke.sanitize_fixture(changed) == changed
      assert LiveSmoke.fixture!(:stub, "marked", root: tmp) == %{"results" => [1]}
    end

    test "sanitizes and leak-checks the transformed body", %{tmp: tmp} do
      token = "ya29.live-smoke-transform-leak"
      base_url = start_stub([{200, %{"ok" => true}}, {200, %{"ok" => true}}])

      with_env(%{"JIDO_CONNECT_RECORD" => "1", "GOOGLE_ACCESS_TOKEN" => token}, fn ->
        put_req_options(retry: false)

        :ok =
          LiveSmoke.record({:jido_connect, @req_key}, :stub, "owner",
            root: tmp,
            transform: fn _path, body -> Map.put(body, "owner", "ada@corp.test") end
          )

        assert {:ok, %Req.Response{body: %{"ok" => true}}} = get(base_url, "/v1/owner")

        :ok =
          LiveSmoke.record({:jido_connect, @req_key}, :stub, "leak",
            root: tmp,
            transform: fn _path, body -> Map.put(body, "echo", token) end
          )

        assert_raise LeakError, fn -> get(base_url, "/v1/echo") end
      end)

      assert LiveSmoke.fixture!(:stub, "owner", root: tmp) == %{
               "ok" => true,
               "owner" => "person-1@example.com"
             }

      refute File.exists?(Path.join(tmp, "test/fixtures/stub/recorded/leak.json"))
    end

    test "rejects a transform that is not a function of path and body", %{tmp: tmp} do
      with_env(%{"JIDO_CONNECT_RECORD" => "1"}, fn ->
        put_req_options(retry: false)

        assert_raise ArgumentError, ~r/:transform/, fn ->
          LiveSmoke.record({:jido_connect, @req_key}, :stub, "bad",
            root: tmp,
            transform: fn body -> body end
          )
        end
      end)
    end

    test "leaves the Req options alone unless JIDO_CONNECT_RECORD=1", %{tmp: tmp} do
      with_env(%{"JIDO_CONNECT_RECORD" => nil}, fn ->
        put_req_options(retry: false)
        assert :ok = LiveSmoke.record({:jido_connect, @req_key}, :stub, "off", root: tmp)
        assert Application.get_env(:jido_connect, @req_key) == [retry: false]
        refute LiveSmoke.recording?()
      end)
    end

    test "refuses to record while a plug replaces the network", %{tmp: tmp} do
      with_env(%{"JIDO_CONNECT_RECORD" => "1"}, fn ->
        put_req_options(plug: {Req.Test, __MODULE__})

        assert_raise ArgumentError, ~r/:plug/, fn ->
          LiveSmoke.record({:jido_connect, @req_key}, :stub, "plugged", root: tmp)
        end
      end)
    end
  end

  describe "captures" do
    test "sanitizing re-signs a Slack capture for the replay secret" do
      raw = slack_capture(~s({"event":{"type":"message","user_email":"ada@corp.test"}}), "secret")

      sanitized = LiveSmoke.sanitize_capture(raw, secret: "secret")

      assert sanitized["body"] =~ "person-1@example.com"
      refute sanitized["body"] =~ "ada@corp.test"
      refute Map.has_key?(sanitized["headers"], "x-forwarded-for")
      assert sanitized["headers"]["x-slack-request-timestamp"] == "1700000000"

      assert sanitized["headers"]["x-slack-signature"] ==
               slack_signature(LiveSmoke.replay_secret(), "1700000000", sanitized["body"])

      assert sanitized["captured_at"] == raw["captured_at"]
    end

    test "sanitizing replaces the request host of a capture wherever it appears" do
      body =
        ~s({"type":"event_callback","url":"https://demo.tunnel.test/integrations/slack/events"})

      raw =
        body
        |> slack_capture("secret")
        |> put_in(["headers", "host"], "demo.tunnel.test:443")

      sanitized = with_env(@no_sites, fn -> LiveSmoke.sanitize_capture(raw, secret: "secret") end)

      assert sanitized["headers"]["host"] == "host-1.example.com:443"
      assert sanitized["body"] =~ "https://host-1.example.com/integrations/slack/events"
      refute inspect(sanitized) =~ "tunnel.test"
    end

    test "sanitizing a sanitized capture again with the replay secret changes nothing" do
      body = ~s({"user":{"email":"ada@corp.test","link":"https://demo.tunnel.test/u/1"}})

      raw =
        body
        |> slack_capture("secret")
        |> put_in(["headers", "host"], "demo.tunnel.test")

      with_env(@no_sites, fn ->
        once = LiveSmoke.sanitize_capture(raw, secret: "secret")

        assert LiveSmoke.sanitize_capture(once, secret: LiveSmoke.replay_secret()) == once
      end)
    end

    test "sanitizing refuses a capture whose original signature does not verify" do
      raw = slack_capture(~s({"type":"event_callback"}), "secret")
      tampered = Map.put(raw, "body", ~s({"type":"event_callback","forged":true}))

      assert_raise ArgumentError, ~r/secret/, fn -> LiveSmoke.sanitize_capture(raw) end

      assert_raise ArgumentError, ~r/does not verify/, fn ->
        LiveSmoke.sanitize_capture(tampered, secret: "secret")
      end

      assert_raise ArgumentError, ~r/does not verify/, fn ->
        LiveSmoke.sanitize_capture(raw, secret: "other-secret")
      end
    end

    test "replay passes the capture to verify_delivery/4 with the captured time as now", %{
      tmp: tmp
    } do
      capture = slack_capture(~s({"type":"event_callback"}), "secret")

      path =
        LiveSmoke.write_capture!(capture, :slack, "event_callback", root: tmp, secret: "secret")

      assert path == Path.join(tmp, "test/fixtures/slack/captured/event_callback.json")
      assert {:ok, :verified} = LiveSmoke.replay(path, webhook: RecordingWebhook)

      assert_received {:verify_delivery, body, headers, secret, opts}
      assert body == ~s({"type":"event_callback"})
      assert headers["x-slack-request-timestamp"] == "1700000000"
      assert secret == LiveSmoke.replay_secret()
      assert opts[:now] == 1_700_000_003

      assert {:ok, :verified} =
               LiveSmoke.replay(capture,
                 webhook: RecordingWebhook,
                 secret: "secret",
                 seen_delivery_ids: ["Ev1"]
               )

      assert_received {:verify_delivery, _body, _headers, "secret", opts}
      assert opts[:seen_delivery_ids] == ["Ev1"]
    end
  end

  defp slack_capture(body, secret) do
    %{
      "provider" => "slack",
      "method" => "POST",
      "path" => "/integrations/slack/events",
      "captured_at" => 1_700_000_003,
      "headers" => %{
        "content-type" => "application/json",
        "x-forwarded-for" => "203.0.113.7",
        "x-slack-request-timestamp" => "1700000000",
        "x-slack-signature" => slack_signature(secret, "1700000000", body)
      },
      "body" => body
    }
  end

  defp slack_signature(secret, timestamp, body) do
    "v0=" <>
      (:hmac
       |> :crypto.mac(:sha256, secret, "v0:#{timestamp}:#{body}")
       |> Base.encode16(case: :lower))
  end

  defp get(base_url, path) do
    base_url
    |> Transport.bearer_request("stub-access-token",
      req_options: Application.get_env(:jido_connect, @req_key, [])
    )
    |> Req.get(url: path)
  end

  defp put_req_options(options) do
    Application.put_env(:jido_connect, @req_key, options)
    on_exit(fn -> Application.delete_env(:jido_connect, @req_key) end)
  end

  defp with_env(values, fun) do
    previous = Map.new(values, fn {name, _value} -> {name, System.get_env(name)} end)
    Enum.each(values, fn {name, value} -> put_env(name, value) end)

    try do
      fun.()
    after
      Enum.each(previous, fn {name, value} -> put_env(name, value) end)
    end
  end

  defp put_env(name, nil), do: System.delete_env(name)
  defp put_env(name, value), do: System.put_env(name, value)

  defp start_stub(responses) do
    {:ok, listen} =
      :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

    {:ok, port} = :inet.port(listen)
    spawn_link(fn -> serve(listen, responses) end)
    on_exit(fn -> :gen_tcp.close(listen) end)
    "http://127.0.0.1:#{port}"
  end

  defp serve(_listen, []), do: :ok

  defp serve(listen, [{status, body} | responses]),
    do: serve(listen, [{status, body, []} | responses])

  defp serve(listen, [{status, body, headers} | responses]) do
    {:ok, socket} = :gen_tcp.accept(listen)
    :ok = read_head(socket, "")

    {content_type, payload} =
      case body do
        {:raw, content_type, bytes} -> {content_type, bytes}
        body -> {"application/json", Jason.encode!(body)}
      end

    :ok =
      :gen_tcp.send(socket, [
        "HTTP/1.1 #{status} OK\r\n",
        "content-type: #{content_type}\r\n",
        "set-cookie: sid=stub\r\n",
        Enum.map(headers, fn {name, value} -> "#{name}: #{value}\r\n" end),
        "content-length: #{byte_size(payload)}\r\n",
        "connection: close\r\n\r\n",
        payload
      ])

    :gen_tcp.close(socket)
    serve(listen, responses)
  end

  defp read_head(socket, buffer) do
    if String.contains?(buffer, "\r\n\r\n") do
      :ok
    else
      {:ok, data} = :gen_tcp.recv(socket, 0, 5_000)
      read_head(socket, buffer <> data)
    end
  end
end
