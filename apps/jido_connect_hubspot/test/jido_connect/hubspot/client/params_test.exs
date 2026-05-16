defmodule Jido.Connect.HubSpot.Client.ParamsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Client.Params

  describe "default properties" do
    test "exposes default contact properties" do
      props = Params.default_contact_properties()
      assert is_list(props)
      assert "email" in props
      assert "firstname" in props
    end

    test "exposes default company properties" do
      props = Params.default_company_properties()
      assert is_list(props)
      assert "name" in props
      assert "domain" in props
    end

    test "exposes default deal properties" do
      props = Params.default_deal_properties()
      assert is_list(props)
      assert "dealname" in props
      assert "amount" in props
    end
  end

  describe "get_params/2" do
    test "builds query params with default properties" do
      params = Params.get_params(%{}, %{properties: ["email", "firstname"]})

      property_values = Keyword.get_values(params, :properties)
      assert property_values == ["email", "firstname"]
      assert Keyword.get(params, :archived) == false
      refute Keyword.has_key?(params, :propertiesWithHistory)
    end

    test "overrides with input properties" do
      params =
        Params.get_params(
          %{properties: ["email"], archived: true},
          %{properties: ["email", "firstname"]}
        )

      property_values = Keyword.get_values(params, :properties)
      assert property_values == ["email"]
      assert Keyword.get(params, :archived) == true
    end
  end

  describe "list_params/2" do
    test "builds query params with limit and properties" do
      params = Params.list_params(%{}, %{properties: ["email"], limit: 50})

      assert Keyword.get(params, :limit) == 50
      property_values = Keyword.get_values(params, :properties)
      assert property_values == ["email"]
      assert Keyword.get(params, :archived) == false
    end

    test "includes after cursor when provided" do
      params = Params.list_params(%{after: "501"}, %{properties: []})

      assert Keyword.get(params, :after) == "501"
    end
  end

  describe "search_body/2" do
    test "builds search body with query" do
      body = Params.search_body(%{query: "bella"}, %{properties: ["email"]})

      assert body.query == "bella"
      assert body.properties == ["email"]
    end

    test "includes filter groups when provided" do
      filter_groups = [
        %{filters: [%{propertyName: "email", operator: "EQ", value: "test@example.com"}]}
      ]

      body = Params.search_body(%{filter_groups: filter_groups}, %{properties: []})

      assert body.filterGroups == filter_groups
    end

    test "includes archived when true" do
      body = Params.search_body(%{archived: true}, %{properties: []})
      assert body.archived == true
    end

    test "omits archived when false" do
      body = Params.search_body(%{archived: false}, %{properties: []})
      refute Map.has_key?(body, :archived)
    end
  end
end
