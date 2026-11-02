defmodule Jido.Connect.Gmail.TestSupport.LiveGmail do
  @moduledoc false

  # Shared by the Gmail live smoke tests: records the responses of a test,
  # runs Gmail actions through `Jido.Connect` with a connection and a
  # credential lease around a live access token, and inserts and deletes
  # messages with Req outside the connector and the recorder. A helper that
  # one test file uses stays in that file.

  import ExUnit.Assertions

  alias Jido.Connect
  alias Jido.Connect.Gmail
  alias Jido.Connect.TestSupport.LiveSmoke

  @req_options {:jido_connect_google, :google_req_options}

  @readonly_scope "https://www.googleapis.com/auth/gmail.readonly"
  @modify_scope "https://www.googleapis.com/auth/gmail.modify"
  @mail_scope "https://mail.google.com/"

  @gmail_api "https://gmail.googleapis.com/gmail/v1/users/me"

  @doc """
  Records the Gmail responses of the current test under `name`.

  Each call starts the numbering again, so the next response goes to
  `name.json` and replaces what an earlier call under `name` wrote. Without
  `JIDO_CONNECT_RECORD=1` this does nothing.
  """
  def record(name), do: LiveSmoke.record(@req_options, :gmail, name)

  @doc "Returns a context and a credential lease with `gmail.readonly` for `access_token`."
  def read_grant(access_token), do: grant(access_token, [@readonly_scope])

  @doc """
  Returns the context and the credential lease that the write actions need,
  `gmail.modify` and `https://mail.google.com/`, as a map for `invoke/3` and
  `commit/3`.
  """
  def write_grant(access_token) do
    {context, lease} = grant(access_token, [@modify_scope, @mail_scope])
    %{context: context, lease: lease}
  end

  @doc """
  Returns a context and a credential lease for `access_token` with `scopes`
  on both the connection and the lease.

  The declared scopes gate the runtime check; the token itself may carry
  broader Google scopes.
  """
  def grant(access_token, scopes) do
    connection =
      Connect.Connection.new!(%{
        id: "live-gmail",
        provider: :google,
        profile: :user,
        tenant_id: "live",
        owner_type: :app_user,
        owner_id: "live-user",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "live",
        actor: %{id: "live-user", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "live-gmail",
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: access_token},
        scopes: scopes
      })

    {context, lease}
  end

  @doc "Invokes a Gmail action under a grant from `write_grant/1`."
  def invoke(%{context: context, lease: lease}, action_id, input) do
    Connect.invoke(Gmail.integration(), action_id, input,
      context: context,
      credential_lease: lease
    )
  end

  @doc """
  Prepares and commits a Gmail write action under a grant from
  `write_grant/1`, with a host authorization of the prepared action as a host
  would run it.
  """
  def commit(%{context: context, lease: lease}, action_id, input) do
    opts = [context: context, credential_lease: lease]

    with {:ok, prepared} <- Connect.prepare(Gmail.integration(), action_id, input, opts) do
      Connect.commit(
        Gmail.integration(),
        prepared,
        input,
        opts ++
          [
            execution_authorization: %{prepared_action_id: prepared.id},
            authorization_validator: &authorize/4
          ]
      )
    end
  end

  defp authorize(%{prepared_action_id: id}, %{id: id}, _context, _validator_context), do: :ok
  defp authorize(_evidence, _prepared, _context, _validator_context), do: :error

  @doc """
  Calls the Gmail API directly, outside the connector and the recorder, for
  setup and cleanup.
  """
  def gmail_api(method, path, access_token, opts \\ []) do
    Req.request!(
      [method: method, url: @gmail_api <> path, auth: {:bearer, access_token}, retry: false] ++
        opts
    )
  end

  @doc """
  Inserts a plain-text message with synthetic example.org addresses and
  `headers` through messages.insert, which files it like received mail
  without sending it, and deletes it for good when the test exits.
  """
  def insert_message!(access_token, headers, label_ids, thread_id \\ nil) do
    envelope = [
      {"From", "jcl-live.sender@example.org"},
      {"To", "jcl-live.recipient@example.org"},
      {"Date", Calendar.strftime(DateTime.utc_now(), "%a, %d %b %Y %H:%M:%S +0000")}
    ]

    mime = [{"MIME-Version", "1.0"}, {"Content-Type", ~s(text/plain; charset="utf-8")}]

    header_block =
      Enum.map_join(envelope ++ headers ++ mime, &"#{elem(&1, 0)}: #{elem(&1, 1)}\r\n")

    raw = header_block <> "\r\nSynthetic message of a jcl-live check.\r\n"

    body = %{"raw" => Base.url_encode64(raw), "labelIds" => label_ids}
    body = if thread_id, do: Map.put(body, "threadId", thread_id), else: body

    assert %{status: 200, body: %{"id" => message_id} = message} =
             gmail_api(:post, "/messages", access_token, json: body)

    ExUnit.Callbacks.on_exit(fn -> delete_message!(access_token, message_id) end)
    message
  end

  @doc """
  Deletes `message_id` for good through messages.delete. A message that is
  already gone, 404, counts as deleted; any other failure raises with the
  message ID and the HTTP status.
  """
  def delete_message!(access_token, message_id) do
    case gmail_api(:delete, "/messages/#{message_id}", access_token) do
      %{status: status} when status in 200..299 or status == 404 ->
        :ok

      %{status: status} ->
        raise "cleanup could not delete live Gmail message #{message_id}: HTTP #{status}"
    end
  end

  @doc "Returns a per-run suffix for subjects and Message-ID headers."
  def run_id, do: Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)

  @doc "Returns the SHA-256 of `bytes` in lowercase hex."
  def sha256(bytes), do: :sha256 |> :crypto.hash(bytes) |> Base.encode16(case: :lower)
end
