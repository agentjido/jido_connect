defmodule Jido.Connect.Calendly.Normalizer do
  @moduledoc """
  Normalizes raw Calendly API response maps into typed Jido.Connect structs.
  """

  alias Jido.Connect.Calendly.{
    EventType,
    Invitee,
    Pagination,
    ScheduledEvent,
    WebhookSubscription
  }

  @doc "Normalizes a single Calendly event type resource map."
  def event_type(%{"resource" => %{"uri" => _} = resource}) do
    EventType.new(map_event_type(resource))
  end

  def event_type(%{"uri" => _} = resource), do: EventType.new(map_event_type(resource))
  def event_type(_body), do: {:error, :invalid_event_type}

  @doc "Normalizes a paginated event types list response."
  def event_type_list(%{"collection" => collection, "pagination" => pagination}) do
    with items <- Enum.map(collection, &normalize_event_type_item/1),
         {:ok, page} <- map_pagination(pagination) do
      {:ok, %{items: items, pagination: page}}
    end
  end

  def event_type_list(_body), do: {:error, :invalid_event_type_list}

  @doc "Normalizes a single Calendly scheduled event resource map."
  def scheduled_event(%{"resource" => %{"uri" => _} = resource}) do
    ScheduledEvent.new(map_scheduled_event(resource))
  end

  def scheduled_event(%{"uri" => _} = resource),
    do: ScheduledEvent.new(map_scheduled_event(resource))

  def scheduled_event(_body), do: {:error, :invalid_scheduled_event}

  @doc "Normalizes a paginated scheduled events list response."
  def scheduled_event_list(%{"collection" => collection, "pagination" => pagination}) do
    with items <- Enum.map(collection, &normalize_scheduled_event_item/1),
         {:ok, page} <- map_pagination(pagination) do
      {:ok, %{items: items, pagination: page}}
    end
  end

  def scheduled_event_list(_body), do: {:error, :invalid_scheduled_event_list}

  @doc "Normalizes a single Calendly invitee resource map."
  def invitee(%{"resource" => %{"uri" => _} = resource}) do
    Invitee.new(map_invitee(resource))
  end

  def invitee(%{"uri" => _} = resource), do: Invitee.new(map_invitee(resource))
  def invitee(_body), do: {:error, :invalid_invitee}

  @doc "Normalizes a paginated invitees list response."
  def invitee_list(%{"collection" => collection, "pagination" => pagination}) do
    with items <- Enum.map(collection, &normalize_invitee_item/1),
         {:ok, page} <- map_pagination(pagination) do
      {:ok, %{items: items, pagination: page}}
    end
  end

  def invitee_list(_body), do: {:error, :invalid_invitee_list}

  @doc "Normalizes a single Calendly webhook subscription resource map."
  def webhook_subscription(%{"resource" => %{"uri" => _} = resource}) do
    WebhookSubscription.new(map_webhook_subscription(resource))
  end

  def webhook_subscription(%{"uri" => _} = resource),
    do: WebhookSubscription.new(map_webhook_subscription(resource))

  def webhook_subscription(_body), do: {:error, :invalid_webhook_subscription}

  @doc "Normalizes a paginated webhook subscriptions list response."
  def webhook_subscription_list(%{"collection" => collection, "pagination" => pagination}) do
    with items <- Enum.map(collection, &normalize_webhook_subscription_item/1),
         {:ok, page} <- map_pagination(pagination) do
      {:ok, %{items: items, pagination: page}}
    end
  end

  def webhook_subscription_list(_body), do: {:error, :invalid_webhook_subscription_list}

  # ---------------------------------------------------------------------------
  # Private mappers
  # ---------------------------------------------------------------------------

  defp map_event_type(resource) do
    %{
      uri: resource["uri"],
      name: resource["name"],
      slug: resource["slug"],
      description: resource["description"],
      duration: resource["duration"],
      active: resource["active"],
      kind: resource["kind"],
      scheduling_url: resource["scheduling_url"],
      owner_uri: resource["owner"],
      owner_type: resource["owner_type"],
      location: resource["location"],
      color: resource["color"],
      pooling_type: resource["pooling_type"],
      secret: resource["secret"],
      created_at: resource["created_at"],
      updated_at: resource["updated_at"]
    }
  end

  defp map_scheduled_event(resource) do
    %{
      uri: resource["uri"],
      name: resource["name"],
      status: resource["status"],
      start_time: resource["start_time"],
      end_time: resource["end_time"],
      location: resource["location"],
      event_type_uri: resource["event_type"],
      event_type_name: resource["event_type_name"],
      organization_uri: resource["organization"],
      cancellation: resource["cancellation"],
      invitees_counter: resource["invitees_counter"],
      created_at: resource["created_at"],
      updated_at: resource["updated_at"]
    }
  end

  defp map_invitee(resource) do
    %{
      uri: resource["uri"],
      email: resource["email"],
      name: resource["name"],
      status: resource["status"],
      timezone: resource["timezone"],
      event_uri: resource["event"],
      new_invitee_uri: resource["new_invitee"],
      old_invitee_uri: resource["old_invitee"],
      canceled_by: resource["canceled_by"],
      cancellation_reason: resource["cancellation_reason"],
      reschedule_reason: resource["reschedule_reason"],
      reschedule_url: resource["reschedule_url"],
      cancel_url: resource["cancel_url"],
      questions_and_answers: resource["questions_and_answers"],
      created_at: resource["created_at"],
      updated_at: resource["updated_at"]
    }
  end

  defp map_pagination(%{"previous" => prev, "next" => nxt, "count" => count}) do
    Pagination.new(%{
      previous_page: prev,
      next_page: nxt,
      count: count
    })
  end

  defp map_pagination(_), do: {:error, :invalid_pagination}

  defp normalize_event_type_item(%{"uri" => _} = item) do
    case EventType.new(map_event_type(item)) do
      {:ok, event_type} -> event_type
      {:error, _} -> nil
    end
  end

  defp normalize_event_type_item(_), do: nil

  defp normalize_scheduled_event_item(%{"uri" => _} = item) do
    case ScheduledEvent.new(map_scheduled_event(item)) do
      {:ok, event} -> event
      {:error, _} -> nil
    end
  end

  defp normalize_scheduled_event_item(_), do: nil

  defp normalize_invitee_item(%{"uri" => _} = item) do
    case Invitee.new(map_invitee(item)) do
      {:ok, invitee} -> invitee
      {:error, _} -> nil
    end
  end

  defp normalize_invitee_item(_), do: nil

  defp map_webhook_subscription(resource) do
    %{
      uri: resource["uri"],
      callback_url: resource["callback_url"],
      scope: resource["scope"],
      organization_uri: resource["organization"],
      user_uri: resource["user"],
      events: resource["events"],
      state: resource["state"],
      created_at: resource["created_at"],
      updated_at: resource["updated_at"]
    }
  end

  defp normalize_webhook_subscription_item(%{"uri" => _} = item) do
    case WebhookSubscription.new(map_webhook_subscription(item)) do
      {:ok, webhook} -> webhook
      {:error, _} -> nil
    end
  end

  defp normalize_webhook_subscription_item(_), do: nil
end
