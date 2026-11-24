defmodule Jido.Connect.Jira.Webhook.Payload do
  @moduledoc """
  Reads the parts that Jira issue and comment deliveries share.

  The readers return `{:ok, value}` or `{:error, %Jido.Connect.Error.ProviderError{}}`
  with reason `:invalid_webhook_event`. The error details name the event type
  and the payload path, such as `"issue.id"`, and never hold a payload value.

  An optional object that is missing or `null` reads as `nil`; any value other
  than a map fails. Nested reads with `dig/2` return `nil` instead of raising
  when an intermediate value is not a map.
  """

  alias Jido.Connect.{Data, Error}

  @type result(value) :: {:ok, value} | {:error, Error.ProviderError.t()}

  @doc "Returns the object under `key`, or `nil` when it is missing or `null`."
  @spec object(map(), String.t(), String.t(), String.t()) :: result(map() | nil)
  def object(map, key, event_type, path) do
    case Data.get(map, key) do
      nil -> {:ok, nil}
      %{} = object -> {:ok, object}
      _other -> {:error, invalid(event_type, path)}
    end
  end

  @doc "Returns the object under `key`, which must be present."
  @spec required_object(map(), String.t(), String.t(), String.t()) :: result(map())
  def required_object(map, key, event_type, path) do
    case Data.get(map, key) do
      %{} = object -> {:ok, object}
      _other -> {:error, invalid(event_type, path)}
    end
  end

  @doc "Returns the `id` of an object, which must be a non-empty string."
  @spec id(map(), String.t(), String.t()) :: result(String.t())
  def id(object, event_type, path) do
    case Data.get(object, "id") do
      id when is_binary(id) and id != "" -> {:ok, id}
      _other -> {:error, invalid(event_type, path)}
    end
  end

  @doc """
  Returns the delivery's epoch-millisecond `timestamp` as an ISO 8601 string.

  A missing timestamp reads as `nil`. Any value that `epoch_to_iso8601/1`
  rejects fails.
  """
  @spec timestamp(map(), String.t()) :: result(String.t() | nil)
  def timestamp(payload, event_type) do
    with epoch when not is_nil(epoch) <- Data.get(payload, "timestamp"),
         {:ok, iso8601} <- epoch_to_iso8601(epoch) do
      {:ok, iso8601}
    else
      nil -> {:ok, nil}
      :error -> {:error, invalid(event_type, "timestamp")}
    end
  end

  @doc """
  Converts epoch milliseconds, as an integer or a string of digits, to an
  ISO 8601 UTC string. Returns `:error` for any other value, a sign in a
  string included, and for an epoch outside the range of `DateTime`.
  """
  @spec epoch_to_iso8601(term()) :: {:ok, String.t()} | :error
  def epoch_to_iso8601(epoch) when is_integer(epoch) do
    case DateTime.from_unix(epoch, :millisecond) do
      {:ok, datetime} -> {:ok, DateTime.to_iso8601(datetime)}
      {:error, _reason} -> :error
    end
  end

  def epoch_to_iso8601(epoch) when is_binary(epoch) do
    if epoch =~ ~r/\A[0-9]+\z/,
      do: epoch |> String.to_integer() |> epoch_to_iso8601(),
      else: :error
  end

  def epoch_to_iso8601(_epoch), do: :error

  @doc """
  Returns `matchedWebhookIds` as a list of strings.

  Jira sends the IDs of the webhooks a delivery matched as numbers in
  deliveries of app-registered webhooks. Administrator webhooks leave the
  key out, so it reads as `nil`. A value that is not a list of numbers or
  non-empty strings fails.
  """
  @spec matched_webhook_ids(map(), String.t()) :: result([String.t()] | nil)
  def matched_webhook_ids(payload, event_type) do
    case Data.get(payload, "matchedWebhookIds") do
      nil ->
        {:ok, nil}

      ids when is_list(ids) ->
        if Enum.all?(ids, &webhook_id?/1),
          do: {:ok, Enum.map(ids, &to_string/1)},
          else: {:error, invalid(event_type, "matchedWebhookIds")}

      _other ->
        {:error, invalid(event_type, "matchedWebhookIds")}
    end
  end

  @doc "Reads a nested value; returns `nil` when a step is missing or not a map."
  @spec dig(term(), [String.t()]) :: term()
  def dig(value, []), do: value
  def dig(%{} = map, [key | keys]), do: map |> Data.get(key) |> dig(keys)
  def dig(_value, _keys), do: nil

  @doc "Builds the `:invalid_webhook_event` error for a payload path."
  @spec invalid(String.t(), String.t()) :: Error.ProviderError.t()
  def invalid(event_type, path) do
    Error.provider("Jira webhook event field is missing or invalid",
      provider: :jira,
      reason: :invalid_webhook_event,
      details: %{event_type: event_type, field: path}
    )
  end

  defp webhook_id?(id) when is_integer(id), do: true
  defp webhook_id?(id) when is_binary(id), do: id != ""
  defp webhook_id?(_id), do: false
end
