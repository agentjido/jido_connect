ExUnit.start()

defmodule MockClient do
  @moduledoc false

  def get_contact(input, token), do: handle(:get_contact, input, token)
  def list_contacts(input, token), do: handle(:list_contacts, input, token)
  def search_contacts(input, token), do: handle(:search_contacts, input, token)
  def create_contact(input, token), do: handle(:create_contact, input, token)
  def update_contact(input, token), do: handle(:update_contact, input, token)
  def get_company(input, token), do: handle(:get_company, input, token)
  def list_companies(input, token), do: handle(:list_companies, input, token)
  def search_companies(input, token), do: handle(:search_companies, input, token)
  def get_deal(input, token), do: handle(:get_deal, input, token)
  def list_deals(input, token), do: handle(:list_deals, input, token)
  def search_deals(input, token), do: handle(:search_deals, input, token)
  def create_deal(input, token), do: handle(:create_deal, input, token)
  def update_deal(input, token), do: handle(:update_deal, input, token)
  def create_note(input, token), do: handle(:create_note, input, token)

  defp handle(action, _input, _token) do
    case Process.get({__MODULE__, action}) do
      nil -> {:error, :not_mocked}
      result -> result
    end
  end

  def stub(responses) when is_list(responses) do
    Enum.each(responses, fn {action, result} ->
      Process.put({__MODULE__, action}, result)
    end)
  end
end

# Ensure Req.Test.Ownership is running so that client tests using
# `setup {Req.Test, :verify_on_exit!}` work even when the umbrella
# cannot start the full application supervision tree.
unless Process.whereis(Req.Test.Ownership) do
  {:ok, _} = Req.Test.Ownership.start_link(name: Req.Test.Ownership)
end
