defmodule Jido.Connect.Google.Forms.ScopeResolver do
  @moduledoc """
  Resolves Google Forms scopes.

  Google Forms exposes both read-only and read-write operations for form body
  and responses. The resolver stays package-local so later action families can
  preserve least-privilege behavior without adding generic Forms scope logic to
  `jido_connect` core.
  """

  @readonly_scope "https://www.googleapis.com/auth/forms.body.readonly"
  @write_scope "https://www.googleapis.com/auth/forms.body"
  @responses_readonly_scope "https://www.googleapis.com/auth/forms.responses.readonly"

  @watch_operations MapSet.new([
                      "google.forms.watch.create",
                      "google.forms.watch.renew",
                      "google.forms.watch.delete"
                    ])

  @write_operations MapSet.new([
                      "google.forms.form.create",
                      "google.forms.form.batch_update"
                    ])

  @response_operations MapSet.new([
                         "google.forms.responses.list",
                         "google.forms.responses.get"
                       ])

  def required_scopes(operation, _input, _connection) do
    operation
    |> operation_id()
    |> required_for_operation()
  end

  defp required_for_operation(operation_id) do
    cond do
      MapSet.member?(@write_operations, operation_id) ->
        [@write_scope]

      MapSet.member?(@response_operations, operation_id) ->
        [@responses_readonly_scope]

      MapSet.member?(@watch_operations, operation_id) ->
        [@responses_readonly_scope]

      true ->
        [@readonly_scope]
    end
  end

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(_operation), do: nil
end
