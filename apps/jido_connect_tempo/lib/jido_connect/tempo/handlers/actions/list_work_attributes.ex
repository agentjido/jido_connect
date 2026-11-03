defmodule Jido.Connect.Tempo.Handlers.Actions.ListWorkAttributes do
  @moduledoc false

  # The input is empty: Tempo lists the site's work attributes, not those
  # of one booking target. complete reports whether every required
  # attribute's value can be described; a failed read is an error instead.

  alias Jido.Connect.Tempo.{Client, WorkAttribute}

  def run(_input, runtime) do
    with {:ok, request} <- Client.request_context(runtime),
         client = Client.resolve(runtime),
         {:ok, attributes} <- client.list_work_attributes(request, []) do
      incomplete =
        for attribute <- attributes,
            reason = WorkAttribute.incomplete(attribute),
            do: %{key: attribute.key, reason: reason}

      {:ok,
       %{
         attributes: Enum.map(attributes, &WorkAttribute.to_map/1),
         complete: incomplete == [],
         incomplete: incomplete
       }}
    end
  end
end
