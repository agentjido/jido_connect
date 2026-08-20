defmodule Jido.Connect.Trello.OAuth.DefaultFlow.ExMCPBackend do
  @moduledoc false

  alias ExMCP.Authorization.{
    ClientRegistration,
    OAuthFlow,
    OAuthTransactionStore,
    OIDCDiscovery,
    ProtectedResourceMetadata
  }

  defdelegate discover_resource(resource, opts), to: ProtectedResourceMetadata, as: :discover
  defdelegate discover_authorization(issuer, opts), to: OIDCDiscovery, as: :discover
  defdelegate register_client(request), to: ClientRegistration
  defdelegate start_authorization(params), to: OAuthFlow, as: :start_authorization_flow
  defdelegate abort(transaction_id), to: OAuthTransactionStore

  defdelegate validate_callback(response, transaction),
    to: OAuthFlow,
    as: :validate_authorization_response

  defdelegate exchange_code(params), to: OAuthFlow, as: :exchange_code_for_token
  defdelegate refresh_token(refresh_token, client_id, token_endpoint, opts), to: OAuthFlow
end
