defmodule Jido.Connect.Slack.Client do
  @moduledoc """
  Compatibility facade for the Slack Web API client.

  API-area modules under `Jido.Connect.Slack.Client.*` keep future handlers and
  tests focused while preserving the original public client boundary.
  """

  alias Jido.Connect.Slack.Client

  defdelegate list_channels(params, access_token), to: Client.Conversations
  defdelegate get_conversation_info(params, access_token), to: Client.Conversations
  defdelegate create_channel(params, access_token), to: Client.Conversations
  defdelegate archive_conversation(params, access_token), to: Client.Conversations
  defdelegate unarchive_conversation(params, access_token), to: Client.Conversations
  defdelegate rename_conversation(params, access_token), to: Client.Conversations
  defdelegate invite_conversation(params, access_token), to: Client.Conversations
  defdelegate kick_conversation(params, access_token), to: Client.Conversations
  defdelegate open_conversation(params, access_token), to: Client.Conversations
  defdelegate list_conversation_members(params, access_token), to: Client.Conversations

  defdelegate post_message(attrs, access_token), to: Client.Messages
  defdelegate post_ephemeral(attrs, access_token), to: Client.Messages
  defdelegate schedule_message(attrs, access_token), to: Client.Messages
  defdelegate delete_scheduled_message(attrs, access_token), to: Client.Messages
  defdelegate update_message(attrs, access_token), to: Client.Messages
  defdelegate delete_message(attrs, access_token), to: Client.Messages
  defdelegate get_thread_replies(params, access_token), to: Client.Messages
  defdelegate search_messages(params, access_token), to: Client.Messages

  defdelegate list_unread_messages(params, access_token), to: Client.ReadState
  defdelegate mark_conversation_read(attrs, access_token), to: Client.ReadState

  defdelegate get_presence(access_token), to: Client.Presence
  defdelegate set_presence(attrs, access_token), to: Client.Presence
  defdelegate set_status(attrs, access_token), to: Client.Presence
  defdelegate clear_status(attrs, access_token), to: Client.Presence
  defdelegate list_emoji(access_token), to: Client.Presence

  defdelegate search_files(params, access_token), to: Client.Files
  defdelegate upload_file(attrs, access_token), to: Client.Files
  defdelegate share_file(attrs, access_token), to: Client.Files
  defdelegate delete_file(attrs, access_token), to: Client.Files

  defdelegate add_reaction(attrs, access_token), to: Client.Reactions
  defdelegate remove_reaction(attrs, access_token), to: Client.Reactions
  defdelegate get_reactions(params, access_token), to: Client.Reactions

  defdelegate list_pins(params, access_token), to: Client.Pins
  defdelegate add_pin(attrs, access_token), to: Client.Pins
  defdelegate remove_pin(attrs, access_token), to: Client.Pins

  defdelegate list_users(params, access_token), to: Client.Users
  defdelegate user_info(params, access_token), to: Client.Users
  defdelegate lookup_user_by_email(params, access_token), to: Client.Users

  defdelegate auth_test(access_token), to: Client.Identity
  defdelegate team_info(params, access_token), to: Client.Identity
end
