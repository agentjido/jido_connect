defmodule Jido.Connect.Google.Meet.Client do
  @moduledoc "Google Meet API client boundary."

  alias Jido.Connect.Google.Meet.Client.Spaces

  defdelegate create_space(params, access_token), to: Spaces
  defdelegate get_space(params, access_token), to: Spaces
end
