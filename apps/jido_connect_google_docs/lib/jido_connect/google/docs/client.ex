defmodule Jido.Connect.Google.Docs.Client do
  @moduledoc """
  Google Docs API client facade.

  Endpoint-specific client modules are added by capability tasks.
  """

  defdelegate get_document(params, access_token), to: __MODULE__.Documents
  defdelegate create_document(params, access_token), to: __MODULE__.Documents
end
