defmodule Jido.Connect.Microsoft.AvailabilityTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Microsoft.Availability

  @expected_areas [:mail, :calendar, :files, :contacts, :tasks, :teams]

  test "exposes all supported Microsoft product areas" do
    assert Availability.ids() == @expected_areas
  end

  test "all returns one entry per product area" do
    all = Availability.all()
    assert length(all) == length(@expected_areas)
    assert Enum.map(all, & &1.id) == @expected_areas
  end

  test "catalog returns a map keyed by product area id" do
    catalog = Availability.catalog()

    for area <- @expected_areas do
      assert Map.has_key?(catalog, area)
      assert %Availability{} = catalog[area]
    end
  end

  test "each product area has required fields" do
    for area <- Availability.all() do
      assert %Availability{
               id: id,
               label: label,
               description: description,
               status: :available,
               scopes: scopes,
               foundation_contracts: contracts
             } = area

      assert id in @expected_areas
      assert is_binary(label) and label != ""
      assert is_binary(description) and description != ""
      assert is_list(scopes) and length(scopes) > 0
      assert is_list(contracts) and :oauth in contracts
      assert :transport in contracts
      assert :pagination in contracts
      assert :scopes in contracts
    end
  end

  test "each product area scopes match Scopes.product/1" do
    alias Jido.Connect.Microsoft.Scopes

    for area <- Availability.all() do
      assert area.scopes == Scopes.product(area.id)
    end
  end

  test "fetch returns known product areas" do
    for area_id <- @expected_areas do
      assert {:ok, %Availability{id: ^area_id}} = Availability.fetch(area_id)
    end
  end

  test "fetch returns :error for unknown product areas" do
    assert :error = Availability.fetch(:unknown)
    assert :error = Availability.fetch(:sharepoint)
  end

  test "fetch! raises for unknown product areas" do
    assert_raise ArgumentError, ~r/unknown Microsoft product area/, fn ->
      Availability.fetch!(:unknown)
    end
  end

  test "available? returns true for known product areas" do
    for area_id <- @expected_areas do
      assert Availability.available?(area_id)
    end
  end

  test "available? returns false for unknown product areas" do
    refute Availability.available?(:unknown)
    refute Availability.available?("mail")
  end

  test "read_only_scopes returns scopes for known product areas" do
    mail_ro = Availability.read_only_scopes(:mail)
    assert is_list(mail_ro)
    assert "Mail.Read" in mail_ro

    calendar_ro = Availability.read_only_scopes(:calendar)
    assert "Calendars.Read" in calendar_ro
  end

  test "read_only_scopes returns empty list for unknown product areas" do
    assert Availability.read_only_scopes(:unknown) == []
  end

  test "no product area carries product-specific actions or triggers" do
    for area <- Availability.all() do
      refute Map.has_key?(area, :actions)
      refute Map.has_key?(area, :triggers)
      assert is_nil(area.product_package) or is_atom(area.product_package)
    end
  end
end
