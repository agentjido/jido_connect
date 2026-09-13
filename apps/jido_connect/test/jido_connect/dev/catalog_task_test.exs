defmodule Jido.Connect.Dev.CatalogTaskTest do
  use ExUnit.Case, async: true

  test "catalog task loads host application config before discovery" do
    assert "app.config" in Mix.Task.requirements(Mix.Tasks.Jido.Connect.Catalog)
  end
end
