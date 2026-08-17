defmodule Jido.Connect.Things.Client.Response do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Things.Client.{Account, History}

  def account({:ok, %{status: status, body: body}}) when status in 200..299 do
    with {:ok, body} <- object(body),
         email when is_binary(email) and email != "" <- body["email"],
         history_key when is_binary(history_key) and history_key != "" <- body["history-key"],
         status when is_binary(status) <- body["status"] do
      {:ok,
       %Account{
         email: email,
         status: status,
         history_key: history_key,
         issues: body["issues"]
       }}
    else
      _other -> invalid(:invalid_account_response)
    end
  end

  def account({:ok, %{status: 401}}) do
    {:error,
     Error.auth("Things Cloud rejected the credential lease",
       reason: :credential_rejected
     )}
  end

  def account(response), do: provider_response(response, :account_request_failed)

  def history({:ok, %{status: status, body: body}}, history_key) when status in 200..299 do
    with {:ok, body} <- object(body),
         head when is_integer(head) and head >= 0 <- integer(body["latest-server-index"]),
         schema when is_integer(schema) <- integer(body["latest-schema-version"]) do
      {:ok, %History{history_key: history_key, head: head, schema: schema}}
    else
      _other -> invalid(:invalid_history_response)
    end
  end

  def history(response, _history_key), do: provider_response(response, :history_request_failed)

  def page({:ok, %{status: status, body: body}}) when status in 200..299 do
    with {:ok, body} <- object(body),
         items when is_list(items) <- Map.get(body, "items", []) do
      {:ok, Map.put(body, "items", items)}
    else
      _other -> invalid(:invalid_history_page)
    end
  end

  def page(response), do: provider_response(response, :history_page_failed)

  defp provider_response({:ok, %{status: status}}, reason) do
    {:error,
     Error.provider("Things Cloud request failed",
       provider: :things,
       reason: reason,
       status: status
     )}
  end

  defp provider_response({:error, reason}, stable_reason) do
    {:error,
     Error.provider("Things Cloud transport failed",
       provider: :things,
       reason: stable_reason,
       details: %{
         transport: Jido.Connect.Sanitizer.provider_body_summary(reason, :transport)
       }
     )}
  end

  defp provider_response(_response, reason), do: invalid(reason)

  defp invalid(reason) do
    {:error,
     Error.provider("Things Cloud response did not match the supported protocol",
       provider: :things,
       reason: reason
     )}
  end

  defp object(body) when is_map(body), do: {:ok, body}

  defp object(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      _other -> :error
    end
  end

  defp object(_body), do: :error

  defp integer(value) when is_integer(value), do: value

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _other -> nil
    end
  end

  defp integer(_value), do: nil
end
