defmodule Jido.Connect.Dev.CatalogTaskTest do
  use ExUnit.Case, async: true

  test "catalog task loads host application config before discovery" do
    assert "app.config" in Mix.Task.requirements(Mix.Tasks.Jido.Connect.Catalog)
  end

  test "catalog task rejects resource and verb options that cannot filter entries" do
    for args <- [["--resource", "missing"], ["--verb", "missing"]] do
      assert_raise Mix.Error, ~r/do not filter provider entries/, fn ->
        Mix.Tasks.Jido.Connect.Catalog.run(args)
      end
    end
  end
end
