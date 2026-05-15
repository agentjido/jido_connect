defmodule Jido.Connect.Google.Forms.Client do
  @moduledoc """
  Google Forms API client facade.

  Endpoint-specific client modules are added by capability tasks.
  """

  defdelegate get_form(params, access_token), to: __MODULE__.Forms
  defdelegate create_form(params, access_token), to: __MODULE__.Forms
  defdelegate batch_update(params, access_token), to: __MODULE__.Forms

  defdelegate list_responses(params, access_token), to: __MODULE__.Responses
  defdelegate get_response(params, access_token), to: __MODULE__.Responses

  defdelegate create_watch(params, access_token), to: __MODULE__.Watches
  defdelegate renew_watch(params, access_token), to: __MODULE__.Watches
  defdelegate delete_watch(params, access_token), to: __MODULE__.Watches
end
