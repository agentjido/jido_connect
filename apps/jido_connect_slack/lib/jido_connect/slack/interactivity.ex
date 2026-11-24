defmodule Jido.Connect.Slack.Interactivity do
  @moduledoc """
  Signed form transport for Slack interactivity requests.

  Slack sends button clicks, shortcuts and other interactions to the app's
  interactivity request URL as an `application/x-www-form-urlencoded` POST
  whose single `payload` field holds the interaction as JSON. Pass the exact
  raw body, the request headers and the app's signing secret to
  `verify_delivery/4`; it returns a verified `Jido.Connect.WebhookDelivery`.

  Verification runs in this order:

  1. A body larger than `:max_body_bytes` fails with reason `:body_too_large`
     before the signature is checked.
  2. `Jido.Connect.Slack.Webhook.verify_signature/4` checks the `v0` HMAC
     signature and the five-minute timestamp window and returns its auth
     errors unchanged.
  3. The form body must hold exactly one `payload` field whose JSON value is
     an object; otherwise the reason is `:missing_payload`,
     `:duplicate_payload` or `:invalid_payload`.

  ## Delivery ID

  Slack sends no delivery ID with interactivity requests. The `delivery_id`
  is the lowercase hex SHA-256 of the verified raw body, so a byte-identical
  redelivery gets the same ID and any changed byte gives another one. Pass
  IDs the host has already processed as `:seen_delivery_ids` to have a
  redelivery marked `duplicate?: true`.

  The ID, `duplicate?` and `received_at` stay on the delivery. Unlike a
  signal from `Jido.Connect.Slack.Webhook.normalize_signal/1`, an
  interactivity signal carries no `delivery` map, so a host that handles
  both reads `delivery_id` from the `WebhookDelivery`.

  ## Delivery contents

  `event` is the payload `type`, such as `"block_actions"`. `metadata` holds
  `team_id` (from `team.id`) and `api_app_id`; either is `nil` when the
  payload lacks it. `payload` is the decoded object without the temporary
  capabilities `token`, `bot_access_token`, `response_url`, `response_urls`
  and `trigger_id`. A `view_submission` can also carry `response_urls` inside
  `view`, and an interaction from a workflow step (custom function) carries
  `interactivity.interactivity_pointer`, which opens modals like
  `trigger_id`; both nested fields are dropped as well, while `interactor`
  and `function_data` stay. Other nested objects stay as Slack sent them,
  because `view.state.values` uses keys chosen by the host. The raw body is
  not kept.

  The payload is handed to a normalizer for its `type` together with the
  options. Only `block_actions` has one: a click on one button in a message
  becomes the signal that `Jido.Connect.Slack.BlockAction` describes. Every
  other payload, and a `block_actions` payload the normalizer rejects,
  keeps `normalized_signal: nil`; `normalize_signal/2` returns the reason.
  Verification makes no HTTP request, does not call `response_url` and does
  not answer Slack; the host acknowledges the request.

  ## Block actions

  A `block_actions` payload yields a signal when its `container.type` is
  `message`, it carries exactly one action and that action is a `button`.
  Several actions, another element or another container fail with
  `:unsupported_block_action`. So does a button in an ephemeral message:
  Slack marks the container `is_ephemeral: true` and sends no `message`
  object, so the click names no message the normalizer could check. An
  org-wide install, which sends `is_enterprise_install: true` and no team,
  fails with `:no_workspace`. A missing or empty app, user, channel,
  message or button field, a value that is no string, or a value or ID
  beyond Slack's limits fails with `:invalid_block_action`. The container's `channel_id`, `message_ts` and
  `thread_ts` must match `channel.id`, `message.ts` and `message.thread_ts`,
  otherwise the reason is `:conflicting_block_action`. With the option
  `:api_app_id`, a click for another app fails with `:unexpected_app`.
  Only this normalizer reads the option; the transport does not check the
  app, so such a click verifies with `normalized_signal: nil` and no error.
  A wrong `:api_app_id` therefore drops every click silently. Error details
  name payload paths, never a value.
  """

  alias Jido.Connect.{Error, WebhookDelivery}
  alias Jido.Connect.Slack.Interactivity.{Form, Normalizer}
  alias Jido.Connect.Slack.Webhook
  alias Jido.Connect.Webhook, as: CoreWebhook

  @max_body_bytes 256 * 1024
  @temporary_capabilities [
    "token",
    "bot_access_token",
    "response_url",
    "response_urls",
    "trigger_id"
  ]
  @view_temporary_capabilities ["response_urls"]
  @interactivity_temporary_capabilities ["interactivity_pointer"]

  @doc """
  Verifies a Slack interactivity request and returns it as a verified delivery.

  Options:

    * `:max_body_bytes` - largest accepted raw body in bytes. Defaults to
      262_144 (256 KiB); `nil` also selects the default.
    * `:now` - current Unix time in seconds for the timestamp window.
      Defaults to the system time.
    * `:seen_delivery_ids` - delivery IDs already processed by the host.
      Defaults to `[]`.
    * `:api_app_id` - the host's Slack app ID, read only by the
      `block_actions` normalizer. A click for another app still verifies,
      with `normalized_signal: nil` and no error; `normalize_signal/2` with
      the same option returns `:unexpected_app`. Other payload types and
      the transport ignore it.

  All options are passed on to the payload type normalizer.
  """
  @spec verify_delivery(binary(), map(), String.t() | nil, keyword()) ::
          {:ok, WebhookDelivery.t()} | {:error, Error.error()}
  def verify_delivery(body, headers, signing_secret, opts \\ []) when is_binary(body) do
    with :ok <- check_body_size(body, Keyword.get(opts, :max_body_bytes) || @max_body_bytes),
         :ok <- Webhook.verify_signature(body, headers, signing_secret, opts),
         {:ok, payload} <- Form.decode_payload(body),
         payload = drop_temporary_capabilities(payload),
         delivery_id = delivery_id(body),
         {:ok, delivery} <-
           WebhookDelivery.verified(:slack, %{
             delivery_id: delivery_id,
             event: Map.get(payload, "type"),
             headers: headers,
             payload: payload,
             duplicate?:
               CoreWebhook.duplicate?(delivery_id, Keyword.get(opts, :seen_delivery_ids, [])),
             metadata: %{team_id: team_id(payload), api_app_id: Map.get(payload, "api_app_id")}
           }) do
      {:ok, put_normalized_signal(delivery, opts)}
    end
  end

  @doc """
  Normalizes the payload of a verified interactivity delivery and returns
  its signal or the reason it has none.

  `verify_delivery/4` keeps `normalized_signal: nil` when this fails; call
  this function on such a delivery to learn why. `opts` are those of
  `verify_delivery/4`; pass the same ones, because without `:api_app_id`
  a click for another app normalizes. The signal carries no `delivery`
  map; the delivery ID is the delivery's `delivery_id`.
  """
  @spec normalize_signal(WebhookDelivery.t(), keyword()) ::
          {:ok, map()} | {:error, Error.ProviderError.t()}
  def normalize_signal(%WebhookDelivery{event: type, payload: payload}, opts \\ []) do
    Normalizer.normalize_signal(type, payload, opts)
  end

  defp check_body_size(body, max) when is_integer(max) and max >= 0 do
    if byte_size(body) <= max do
      :ok
    else
      {:error,
       Error.provider("Slack interactivity body is too large",
         provider: :slack,
         reason: :body_too_large,
         details: %{max_body_bytes: max}
       )}
    end
  end

  # Only the named nested objects are touched, because view.state.values
  # carries keys chosen by the host and a recursive drop could remove host data.
  defp drop_temporary_capabilities(payload) do
    payload
    |> Map.drop(@temporary_capabilities)
    |> drop_nested("view", @view_temporary_capabilities)
    |> drop_nested("interactivity", @interactivity_temporary_capabilities)
  end

  defp drop_nested(payload, key, fields) do
    case payload do
      %{^key => %{} = nested} -> Map.put(payload, key, Map.drop(nested, fields))
      _payload -> payload
    end
  end

  defp delivery_id(body), do: :sha256 |> :crypto.hash(body) |> Base.encode16(case: :lower)

  defp team_id(%{"team" => %{"id" => team_id}}), do: team_id
  defp team_id(_payload), do: nil

  defp put_normalized_signal(%WebhookDelivery{} = delivery, opts) do
    case normalize_signal(delivery, opts) do
      {:ok, signal} -> WebhookDelivery.put_signal(delivery, signal)
      {:error, _reason} -> delivery
    end
  end
end
