defmodule Jido.Connect.Microsoft.Scopes do
  @moduledoc "Shared Microsoft Graph OAuth scope helpers and initial product scope catalog."

  alias Jido.Connect.Scope

  @identity ["openid", "email", "profile", "offline_access"]

  @catalog %{
    identity: @identity,
    mail: [
      "Mail.Read",
      "Mail.ReadBasic",
      "Mail.ReadWrite",
      "Mail.Send",
      "MailboxSettings.Read"
    ],
    calendar: [
      "Calendars.Read",
      "Calendars.ReadWrite",
      "Calendars.Read.Shared",
      "Calendars.ReadWrite.Shared"
    ],
    files: [
      "Files.Read",
      "Files.Read.All",
      "Files.ReadWrite",
      "Files.ReadWrite.All"
    ],
    contacts: [
      "Contacts.Read",
      "Contacts.ReadWrite"
    ],
    tasks: [
      "Tasks.Read",
      "Tasks.ReadWrite"
    ],
    teams: [
      "Team.ReadBasic.All",
      "Channel.ReadBasic.All",
      "Chat.Read",
      "Chat.ReadWrite"
    ]
  }

  @doc "Returns the default identity scopes for Microsoft user OAuth."
  @spec user_default() :: [String.t()]
  def user_default, do: @identity

  @doc "Returns optional scopes grouped by product for Microsoft user OAuth."
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

  @doc "Returns the complete shared Microsoft scope catalog."
  @spec catalog() :: map()
  def catalog, do: @catalog

  @doc "Normalizes comma, space, or list scope values."
  @spec normalize(nil | String.t() | [String.t() | atom()]) :: [String.t()]
  def normalize(nil), do: []
  def normalize(scopes) when is_binary(scopes), do: Scope.parse(scopes)
  def normalize(scopes) when is_list(scopes), do: scopes |> Enum.map(&to_string/1) |> Enum.uniq()

  @doc "Encodes scopes for Microsoft OAuth requests."
  @spec encode(String.t() | [String.t()], keyword()) :: String.t()
  def encode(scopes, opts \\ []),
    do: Scope.encode(scopes, Keyword.put_new(opts, :separator, " "))

  @doc "Returns missing required scopes from a granted scope set."
  @spec missing([String.t()], [String.t()]) :: [String.t()]
  def missing(granted, required), do: normalize(required) -- normalize(granted)

  @doc "Returns true when all required scopes are granted."
  @spec include?([String.t()], [String.t()]) :: boolean()
  def include?(granted, required), do: missing(granted, required) == []
end
