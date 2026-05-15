defmodule Jido.Connect.Google.Forms.Handlers.Actions.BatchUpdateForm do
  @moduledoc false

  alias Jido.Connect.{Error, Google.Forms.BatchUpdateRequest, Google.Forms.Client}

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_requests(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.batch_update(input, Map.get(credentials, :access_token)) do
      {:ok, normalize_result(result)}
    end
  end

  defp validate_requests(%{requests: requests}) do
    case BatchUpdateRequest.validate_requests(requests) do
      :ok ->
        :ok

      {:error, :empty_requests} ->
        {:error,
         Error.validation("Batch update requests must not be empty",
           reason: :invalid_batch_update_requests,
           details: %{expected: "non-empty list"}
         )}

      {:error, {:too_many_requests, count, max}} ->
        {:error,
         Error.validation("Batch update request count exceeds limit",
           reason: :invalid_batch_update_requests,
           details: %{max_requests: max, request_count: count}
         )}

      {:error, {:invalid_request, index, message}} ->
        {:error,
         Error.validation("Invalid batch update request",
           reason: :invalid_batch_update_request,
           details: %{index: index, message: message}
         )}

      {:error, {:unsupported_operation, index, operation}} ->
        {:error,
         Error.validation("Unsupported batch update operation",
           reason: :unsupported_batch_update_operation,
           details: %{index: index, operation: operation}
         )}

      {:error, :not_a_list} ->
        {:error,
         Error.validation("Batch update requests must be a list",
           reason: :invalid_batch_update_requests,
           details: %{expected: :list}
         )}
    end
  end

  defp validate_requests(_input) do
    {:error,
     Error.validation("Batch update requests field is required",
       reason: :invalid_batch_update_requests,
       details: %{expected: "requests field present"}
     )}
  end

  defp fetch_client(%{google_forms_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp normalize_result(result) do
    form = Map.get(result, :form)
    replies = Map.get(result, :replies, [])

    output = %{replies: replies}
    output = if form, do: Map.put(output, :form, form), else: output
    output
  end
end
