defmodule Jido.Connect.Google.Slides.Client do
  @moduledoc """
  Google Slides API client facade.

  Endpoint-specific client modules are added by capability tasks.
  """

  defdelegate get_presentation(params, access_token), to: __MODULE__.Presentations
  defdelegate create_presentation(params, access_token), to: __MODULE__.Presentations
  defdelegate batch_update(params, access_token), to: __MODULE__.Presentations
  defdelegate get_page_thumbnail(params, access_token), to: __MODULE__.Presentations
end
