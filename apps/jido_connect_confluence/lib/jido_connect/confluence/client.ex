defmodule Jido.Connect.Confluence.Client do
  @moduledoc "Confluence Cloud REST v2 client boundary."

  alias Jido.Connect.Confluence.Client.Request

  defdelegate request_context(runtime), to: Request, as: :from_runtime

  def resolve(%{provider_client: client}) when is_atom(client) and not is_nil(client), do: client
  def resolve(_runtime), do: __MODULE__

  defdelegate get_space(input, request), to: Jido.Connect.Confluence.Client.Spaces, as: :get

  defdelegate list_pages(input, request),
    to: Jido.Connect.Confluence.Client.Pages,
    as: :list

  defdelegate get_page(input, request),
    to: Jido.Connect.Confluence.Client.Pages,
    as: :get

  defdelegate create_page(input, request),
    to: Jido.Connect.Confluence.Client.Pages,
    as: :create

  defdelegate update_page(input, request),
    to: Jido.Connect.Confluence.Client.Pages,
    as: :update

  defdelegate delete_page(input, request), to: Jido.Connect.Confluence.Client.Pages, as: :delete
end
