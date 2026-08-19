defmodule Jido.Connect.Confluence.Handlers.Actions.ListPages do
  @moduledoc false

  alias Jido.Connect.Confluence.Handlers.Actions.Support

  def run(input, runtime) do
    Support.call(runtime, & &1.list_pages(input, &2))
  end
end

defmodule Jido.Connect.Confluence.Handlers.Actions.GetPage do
  @moduledoc false

  alias Jido.Connect.Confluence.Handlers.Actions.Support

  def run(input, runtime) do
    Support.call(runtime, & &1.get_page(input, &2))
  end
end

defmodule Jido.Connect.Confluence.Handlers.Actions.CreatePage do
  @moduledoc false

  alias Jido.Connect.Confluence.Handlers.Actions.Support

  def run(input, runtime) do
    Support.call(runtime, & &1.create_page(input, &2))
  end
end

defmodule Jido.Connect.Confluence.Handlers.Actions.UpdatePage do
  @moduledoc false

  alias Jido.Connect.Confluence.Handlers.Actions.Support

  def run(input, runtime) do
    Support.call(runtime, & &1.update_page(input, &2))
  end
end

defmodule Jido.Connect.Confluence.Handlers.Actions.DeletePage do
  @moduledoc false

  alias Jido.Connect.Confluence.Handlers.Actions.Support

  def run(input, runtime) do
    Support.call(runtime, & &1.delete_page(input, &2))
  end
end
