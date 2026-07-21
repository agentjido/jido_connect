defmodule Jido.Connect.Microsoft do
  @moduledoc """
  Shared Microsoft Graph foundation helpers for Jido Connect provider packages.

  This module intentionally exposes only provider-family metadata. Product
  connectors such as Outlook, Calendar, and OneDrive own their provider DSL
  declarations and endpoint handlers.
  """

  @provider :microsoft

  @doc "Returns the shared provider family atom used by Microsoft packages."
  @spec provider() :: :microsoft
  def provider, do: @provider

  @doc "Returns auth profiles known to the shared Microsoft foundation."
  @spec auth_profiles() :: [atom()]
  defdelegate auth_profiles, to: Jido.Connect.Microsoft.AuthProfiles, as: :ids

  @doc "Returns supported Microsoft Graph product-area ids."
  @spec availability() :: [atom()]
  defdelegate availability, to: Jido.Connect.Microsoft.Availability, as: :ids
end
