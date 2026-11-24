defmodule Jido.Connect.Slack.Client.Normalizer do
  @moduledoc "Slack Web API response normalization helpers."

  alias Jido.Connect.Data
  alias Jido.Connect.Slack.Message

  @history_message_keys ~w(ts thread_ts user bot_id app_id text blocks attachments files subtype edited)

  @doc """
  Builds a `Jido.Connect.Slack.Message` from a `conversations.history` record.

  Values pass through as Slack sends them, without `Data.compact/1`, so an
  empty `text` stays `""` and absent fields stay `nil`.
  """
  def normalize_history_message(message, params) when is_map(message) do
    message
    |> Map.take(@history_message_keys)
    |> Map.merge(%{
      "channel" => Map.get(params, :channel),
      "conversation_type" => Map.get(params, :conversation_type)
    })
    |> Message.new()
  end

  def normalize_history_message(_message, _params), do: {:error, :invalid_message}

  def normalize_channel(channel) when is_map(channel) do
    %{
      id: Data.get(channel, "id"),
      name: Data.get(channel, "name"),
      is_archived: Data.get(channel, "is_archived"),
      is_private: Data.get(channel, "is_private"),
      is_member: Data.get(channel, "is_member")
    }
  end

  def normalize_conversation(conversation) when is_map(conversation) do
    %{
      id: Data.get(conversation, "id"),
      name: Data.get(conversation, "name"),
      is_im: Data.get(conversation, "is_im"),
      is_mpim: Data.get(conversation, "is_mpim"),
      is_private: Data.get(conversation, "is_private"),
      is_open: Data.get(conversation, "is_open"),
      is_user_deleted: Data.get(conversation, "is_user_deleted"),
      user: Data.get(conversation, "user"),
      users: Data.get(conversation, "users")
    }
    |> Data.compact()
  end

  def normalize_user(user) when is_map(user) do
    %{
      id: Data.get(user, "id"),
      team_id: Data.get(user, "team_id"),
      name: Data.get(user, "name"),
      real_name: Data.get(user, "real_name"),
      tz: Data.get(user, "tz"),
      deleted: Data.get(user, "deleted"),
      is_bot: Data.get(user, "is_bot"),
      is_app_user: Data.get(user, "is_app_user"),
      updated: Data.get(user, "updated"),
      profile: Data.get(user, "profile")
    }
    |> Data.compact()
  end

  def normalize_user_info(user) when is_map(user) do
    user
    |> normalize_user()
    |> Map.put(:profile, normalize_profile(Data.get(user, "profile")))
    |> Data.compact()
  end

  def normalize_profile(profile) when is_map(profile) do
    normalized =
      %{
        avatar_hash: Data.get(profile, "avatar_hash"),
        bot_id: Data.get(profile, "bot_id"),
        display_name: Data.get(profile, "display_name"),
        display_name_normalized: Data.get(profile, "display_name_normalized"),
        email: Data.get(profile, "email"),
        first_name: Data.get(profile, "first_name"),
        image_24: Data.get(profile, "image_24"),
        image_32: Data.get(profile, "image_32"),
        image_48: Data.get(profile, "image_48"),
        image_72: Data.get(profile, "image_72"),
        image_192: Data.get(profile, "image_192"),
        image_512: Data.get(profile, "image_512"),
        last_name: Data.get(profile, "last_name"),
        phone: Data.get(profile, "phone"),
        real_name: Data.get(profile, "real_name"),
        real_name_normalized: Data.get(profile, "real_name_normalized"),
        skype: Data.get(profile, "skype"),
        status_emoji: Data.get(profile, "status_emoji"),
        status_text: Data.get(profile, "status_text"),
        team: Data.get(profile, "team"),
        title: Data.get(profile, "title")
      }
      |> Data.compact()

    if map_size(normalized) == 0, do: nil, else: normalized
  end

  def normalize_profile(_profile), do: nil
end
