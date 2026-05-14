defmodule Jido.Connect.Google.Scopes do
  @moduledoc "Shared Google OAuth scope helpers and initial product scope catalog."

  alias Jido.Connect.Scope

  @identity ["openid", "email", "profile"]

  @catalog %{
    identity: @identity,
    sheets: [
      "https://www.googleapis.com/auth/spreadsheets.readonly",
      "https://www.googleapis.com/auth/spreadsheets"
    ],
    gmail: [
      "https://www.googleapis.com/auth/gmail.metadata",
      "https://www.googleapis.com/auth/gmail.labels",
      "https://www.googleapis.com/auth/gmail.readonly",
      "https://www.googleapis.com/auth/gmail.send",
      "https://www.googleapis.com/auth/gmail.compose",
      "https://www.googleapis.com/auth/gmail.modify",
      "https://mail.google.com/"
    ],
    drive: [
      "https://www.googleapis.com/auth/drive.metadata.readonly",
      "https://www.googleapis.com/auth/drive.file",
      "https://www.googleapis.com/auth/drive.readonly"
    ],
    calendar: [
      "https://www.googleapis.com/auth/calendar.calendarlist.readonly",
      "https://www.googleapis.com/auth/calendar.freebusy",
      "https://www.googleapis.com/auth/calendar.events.freebusy",
      "https://www.googleapis.com/auth/calendar.events.readonly",
      "https://www.googleapis.com/auth/calendar.events"
    ],
    contacts: [
      "https://www.googleapis.com/auth/contacts.readonly",
      "https://www.googleapis.com/auth/contacts"
    ],
    meet: [
      "https://www.googleapis.com/auth/meetings.space.created",
      "https://www.googleapis.com/auth/meetings.space.readonly"
    ],
    analytics: [
      "https://www.googleapis.com/auth/analytics.readonly"
    ],
    search_console: [
      "https://www.googleapis.com/auth/webmasters.readonly",
      "https://www.googleapis.com/auth/webmasters"
    ]
  }

  @doc "Returns the default identity scopes for Google user OAuth."
  @spec user_default() :: [String.t()]
  def user_default, do: @identity

  @doc "Returns optional scopes grouped by product for Google user OAuth."
  @spec user_optional() :: [String.t()]
  def user_optional do
    @catalog
    |> Map.drop([:identity])
    |> Map.values()
    |> List.flatten()
    |> Enum.uniq()
  end

  @doc "Returns all known scopes for a product group."
  @spec product(atom()) :: [String.t()]
  def product(product), do: Map.get(@catalog, product, [])

  @doc "Returns the complete shared Google scope catalog."
  @spec catalog() :: map()
  def catalog, do: @catalog

  @doc "Normalizes comma, space, or list scope values."
  @spec normalize(nil | String.t() | [String.t() | atom()]) :: [String.t()]
  def normalize(nil), do: []
  def normalize(scopes) when is_binary(scopes), do: Scope.parse(scopes)
  def normalize(scopes) when is_list(scopes), do: scopes |> Enum.map(&to_string/1) |> Enum.uniq()

  @doc "Encodes scopes for Google OAuth requests."
  @spec encode(String.t() | [String.t()], keyword()) :: String.t()
  def encode(scopes, opts \\ []), do: Scope.encode(scopes, Keyword.put_new(opts, :separator, " "))

  @doc "Returns missing required scopes from a granted scope set."
  @spec missing([String.t()], [String.t()]) :: [String.t()]
  def missing(granted, required), do: normalize(required) -- normalize(granted)

  @doc "Returns true when all required scopes are granted."
  @spec include?([String.t()], [String.t()]) :: boolean()
  def include?(granted, required), do: missing(granted, required) == []
end
