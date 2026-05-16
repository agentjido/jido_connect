ExUnit.start()

defmodule MockClient do
  @moduledoc false

  # Contact operations
  def get_contact(input, credentials), do: handle(:get_contact, input, credentials)
  def list_contacts(input, credentials), do: handle(:list_contacts, input, credentials)
  def create_contact(input, credentials), do: handle(:create_contact, input, credentials)
  def update_contact(input, credentials), do: handle(:update_contact, input, credentials)

  # Lead operations
  def create_lead(input, credentials), do: handle(:create_lead, input, credentials)
  def update_lead(input, credentials), do: handle(:update_lead, input, credentials)

  # Task operations
  def create_task(input, credentials), do: handle(:create_task, input, credentials)
  def update_task(input, credentials), do: handle(:update_task, input, credentials)

  # Generic SObject operations
  def query(input, credentials), do: handle(:query, input, credentials)
  def get_record(input, credentials), do: handle(:get_record, input, credentials)
  def create_record(input, credentials), do: handle(:create_record, input, credentials)
  def update_record(input, credentials), do: handle(:update_record, input, credentials)
  def describe_object(input, credentials), do: handle(:describe_object, input, credentials)
  def list_recent(input, credentials), do: handle(:list_recent, input, credentials)
  def query_more(input, credentials), do: handle(:query_more, input, credentials)

  defp handle(action, _input, _credentials) do
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
