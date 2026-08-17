defmodule Jido.Connect.Things.Protocol do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Things.Client
  alias Jido.Connect.Things.Client.{Account, History}

  @schema 301

  def schema, do: @schema

  def validate_endpoint(%Client{endpoint: endpoint}) do
    if endpoint == Client.production_endpoint() do
      :ok
    else
      protocol_error(:unsupported_endpoint)
    end
  end

  def validate_account(%Client{} = client, %Account{} = account) do
    cond do
      account.email != client.expected_email -> protocol_error(:account_mismatch)
      account.status != "SYAccountStatusActive" -> protocol_error(:account_not_active)
      account.issues not in [nil, []] -> protocol_error(:account_has_issues)
      true -> :ok
    end
  end

  def validate_history(%History{schema: @schema, head: head})
      when is_integer(head) and head >= 0,
      do: :ok

  def validate_history(%History{schema: schema}),
    do: protocol_error(:unsupported_schema, %{observed_schema: schema, supported_schema: @schema})

  def account_binding(%Client{} = client), do: sha256(client.expected_email)
  def history_fingerprint(%Account{} = account), do: sha256(account.history_key)

  def error(reason, details \\ %{}), do: protocol_error(reason, details)

  defp protocol_error(reason, details \\ %{}) do
    {:error,
     Error.provider("Things Cloud protocol check failed",
       provider: :things,
       reason: reason,
       details: details
     )}
  end

  defp sha256(value) do
    value
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
