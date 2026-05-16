defmodule Jido.Connect.Linear.Webhook do
  @moduledoc """
  Pure helpers for Linear webhook event verification and normalization.

  Linear webhooks deliver signed JSON payloads to a configured URL.
  The signature is a base64-encoded HMAC-SHA256 digest of the raw request
  body using the webhook's signing secret. The signature is sent in the
  `linear-signature` header. Hosts verify the signature before using these
  helpers to normalize the accepted delivery into trigger signals.

  This module does **not** store or expose the signing secret. Verification
  receives a pre-computed HMAC digest from the host layer.

  ## Supported Events

  **Issue events** (`type: "Issue"`):

  - `create` — a new issue was created
  - `update` — an existing issue was updated
  - `remove` — an issue was removed

  **Comment events** (`type: "Comment"`):

  - `create` — a comment was added to an issue
  - `update` — a comment was updated
  """

  alias Jido.Connect.{Data, Error}

  @supported_issue_actions ~w(create update remove)
  @supported_comment_actions ~w(create update)

  @doc """
  Returns the list of supported Linear webhook issue action types.
  """
  @spec supported_actions() :: [String.t()]
  def supported_actions, do: @supported_issue_actions

  @doc """
  Returns the list of supported Linear webhook comment action types.
  """
  @spec supported_comment_actions() :: [String.t()]
  def supported_comment_actions, do: @supported_comment_actions

  @doc """
  Verifies the Linear webhook signature.

  Returns `:ok` when the computed HMAC-SHA256 digest matches the
  `signature`, or an error otherwise. The host is responsible for
  computing `computed` from the raw body and the webhook signing secret;
  neither the secret nor the raw body are passed through this module.
  """
  @spec verify_signature(computed :: String.t(), signature :: String.t()) ::
          :ok | {:error, Error.ProviderError.t()}
  def verify_signature(computed, signature)
      when is_binary(computed) and is_binary(signature) do
    if secure_compare?(computed, signature) do
      :ok
    else
      {:error,
       Error.provider("Linear webhook signature verification failed",
         provider: :linear,
         reason: :webhook_signature_mismatch
       )}
    end
  end

  def verify_signature(_computed, _signature) do
    {:error,
     Error.provider("Linear webhook signature is missing",
       provider: :linear,
       reason: :webhook_signature_missing
     )}
  end

  @doc """
  Computes the HMAC-SHA256 hex digest for a raw body and signing secret.

  This is a convenience function for hosts that have the secret available
  at verification time. Do not log or expose the secret.
  """
  @spec compute_signature(raw_body :: String.t(), signing_secret :: String.t()) :: String.t()
  def compute_signature(raw_body, signing_secret)
      when is_binary(raw_body) and is_binary(signing_secret) do
    :crypto.mac(:hmac, :sha256, signing_secret, raw_body)
    |> Base.encode64()
  end

  @doc """
  Normalizes a Linear webhook event payload into a signal map.

  ## Issue events

  Linear webhook issue payloads contain a `type` of `"Issue"`, an `action`
  field (`create`, `update`, `remove`), and a `data` object with issue details.

  ## Comment events

  Linear webhook comment payloads contain a `type` of `"Comment"`, an
  `action` field (`create`, `update`), and a `data` object with comment
  details including the parent issue reference.

  Returns `{:ok, signal_map}` on success, or `{:error, _}` on failure.
  """
  @spec normalize_event(map()) :: {:ok, map()} | {:error, Error.ProviderError.t()}
  def normalize_event(%{"action" => action, "data" => data, "type" => "Issue"} = payload)
      when action in @supported_issue_actions and is_map(data) do
    labels =
      case Data.get(data, "labels") do
        labels when is_list(labels) ->
          Enum.map(labels, fn
            %{"name" => name} -> name
            other -> other
          end)

        _ ->
          []
      end

    signal =
      %{
        event_type: "Issue",
        action: action,
        issue_id: Data.get(data, "id"),
        identifier: Data.get(data, "identifier"),
        team_id: get_in(data, ["team", "id"]),
        team_key: get_in(data, ["team", "key"]),
        title: Data.get(data, "title"),
        status_name: get_in(data, ["state", "name"]),
        priority_label: Data.get(data, "priorityLabel"),
        assignee_id: get_in(data, ["assignee", "id"]),
        assignee_name: get_in(data, ["assignee", "name"]),
        creator_id: get_in(data, ["creator", "id"]),
        creator_name: get_in(data, ["creator", "name"]),
        labels: labels,
        created_at: Data.get(data, "createdAt"),
        updated_at: Data.get(data, "updatedAt"),
        webhook_id: Data.get(payload, "webhookId"),
        timestamp: Data.get(payload, "createdAt")
      }
      |> Data.compact()

    {:ok, signal}
  end

  def normalize_event(%{"action" => action, "data" => data, "type" => "Comment"} = payload)
      when action in @supported_comment_actions and is_map(data) do
    signal =
      %{
        event_type: "Comment",
        action: action,
        comment_id: Data.get(data, "id"),
        comment_body: Data.get(data, "body"),
        issue_id: get_in(data, ["issue", "id"]),
        issue_identifier: get_in(data, ["issue", "identifier"]),
        user_id: get_in(data, ["user", "id"]),
        user_name: get_in(data, ["user", "name"]),
        created_at: Data.get(data, "createdAt"),
        updated_at: Data.get(data, "updatedAt"),
        webhook_id: Data.get(payload, "webhookId"),
        timestamp: Data.get(payload, "createdAt")
      }
      |> Data.compact()

    {:ok, signal}
  end

  def normalize_event(%{"action" => action, "type" => type}) do
    cond do
      type not in ["Issue", "Comment"] ->
        {:error,
         Error.provider("Unsupported Linear webhook event type",
           provider: :linear,
           reason: :unsupported_webhook_event,
           details: %{type: type, action: action}
         )}

      type == "Issue" and action not in @supported_issue_actions ->
        {:error,
         Error.provider("Unsupported Linear webhook issue action",
           provider: :linear,
           reason: :unsupported_webhook_action,
           details: %{type: type, action: action}
         )}

      type == "Comment" and action not in @supported_comment_actions ->
        {:error,
         Error.provider("Unsupported Linear webhook comment action",
           provider: :linear,
           reason: :unsupported_webhook_action,
           details: %{type: type, action: action}
         )}

      true ->
        {:error,
         Error.provider("Linear webhook event payload is invalid",
           provider: :linear,
           reason: :invalid_webhook_event
         )}
    end
  end

  def normalize_event(%{"type" => type}) do
    {:error,
     Error.provider("Unsupported Linear webhook event type",
       provider: :linear,
       reason: :unsupported_webhook_event,
       details: %{type: type}
     )}
  end

  def normalize_event(_payload) do
    {:error,
     Error.provider("Linear webhook event payload is invalid",
       provider: :linear,
       reason: :invalid_webhook_event
     )}
  end

  @doc """
  Normalizes a batch of Linear webhook events.

  Returns `{:ok, signals}` with all successfully normalized events,
  or `{:error, _}` if any event is invalid.
  """
  @spec normalize_events([map()]) :: {:ok, [map()]} | {:error, Error.ProviderError.t()}
  def normalize_events(events) when is_list(events) do
    events
    |> Enum.reduce_while({:ok, []}, fn event, {:ok, acc} ->
      case normalize_event(event) do
        {:ok, signal} -> {:cont, {:ok, [signal | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, signals} -> {:ok, Enum.reverse(signals)}
      {:error, error} -> {:error, error}
    end
  end

  def normalize_events(_events) do
    {:error,
     Error.provider("Linear webhook events payload must be a list",
       provider: :linear,
       reason: :invalid_webhook_events
     )}
  end

  @doc "Extracts the issue identifier from a Linear webhook event payload."
  @spec issue_identifier(map()) :: String.t() | nil
  def issue_identifier(%{"data" => %{"identifier" => identifier}}), do: identifier
  def issue_identifier(_payload), do: nil

  # Constant-time string comparison to prevent timing attacks.
  defp secure_compare?(left, right) when byte_size(left) != byte_size(right), do: false

  defp secure_compare?(left, right) do
    left
    |> :binary.bin_to_list()
    |> Enum.zip(:binary.bin_to_list(right))
    |> Enum.reduce(0, fn {a, b}, acc -> Bitwise.bxor(a, b) + acc end) == 0
  end
end
