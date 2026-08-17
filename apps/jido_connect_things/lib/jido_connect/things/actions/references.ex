defmodule Jido.Connect.Things.Actions.References do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @strict %{strict_input?: true, unofficial_api?: true}

  actions do
    action :list_projects do
      id("things.project.list")
      resource(:project)
      verb(:list)
      data_classification(:personal_data)
      label("List Things projects")
      description("List active Things projects with stable source IDs.")
      handler(Jido.Connect.Things.Handlers.Actions.ListProjects)
      effect(:read)
      metadata(@strict)

      access do
        auth(:things_cloud_password)
      end

      output do
        field(:projects, {:array, :map}, required?: true)
        field(:count, :integer, required?: true)
        field(:freshness, :map, required?: true)
      end
    end

    action :list_headings do
      id("things.heading.list")
      resource(:heading)
      verb(:list)
      data_classification(:personal_data)
      label("List Things headings")
      description("List active Things headings with project relations.")
      handler(Jido.Connect.Things.Handlers.Actions.ListHeadings)
      effect(:read)
      metadata(@strict)

      access do
        auth(:things_cloud_password)
      end

      output do
        field(:headings, {:array, :map}, required?: true)
        field(:count, :integer, required?: true)
        field(:freshness, :map, required?: true)
      end
    end

    action :list_areas do
      id("things.area.list")
      resource(:area)
      verb(:list)
      data_classification(:personal_data)
      label("List Things areas")
      description("List active Things areas with stable source IDs.")
      handler(Jido.Connect.Things.Handlers.Actions.ListAreas)
      effect(:read)
      metadata(@strict)

      access do
        auth(:things_cloud_password)
      end

      output do
        field(:areas, {:array, :map}, required?: true)
        field(:count, :integer, required?: true)
        field(:freshness, :map, required?: true)
      end
    end

    action :list_tags do
      id("things.tag.list")
      resource(:tag)
      verb(:list)
      data_classification(:personal_data)
      label("List Things tags")
      description("List active Things tags and parent relations.")
      handler(Jido.Connect.Things.Handlers.Actions.ListTags)
      effect(:read)
      metadata(@strict)

      access do
        auth(:things_cloud_password)
      end

      output do
        field(:tags, {:array, :map}, required?: true)
        field(:count, :integer, required?: true)
        field(:freshness, :map, required?: true)
      end
    end
  end
end
