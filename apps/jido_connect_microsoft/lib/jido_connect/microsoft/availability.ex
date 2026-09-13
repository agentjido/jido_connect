defmodule Jido.Connect.Microsoft.Availability do
  @moduledoc """
  Microsoft Graph foundation product-area availability metadata.

  This module describes which Microsoft Graph product areas the shared
  foundation package supports with reusable contracts (scopes, auth profiles,
  transport, pagination). Product connector packages should check this catalog
  to discover which foundation helpers apply to their product area.

  This module intentionally does not declare product-specific tools, actions,
  or triggers. Those belong in product connector packages such as
  `jido_connect_microsoft_outlook` or `jido_connect_microsoft_calendar`.

  ## Usage

      # List all supported product areas
      areas = Jido.Connect.Microsoft.Availability.areas()
      #=> [:mail, :calendar, :files, :sharepoint, :contacts, :tasks, :teams]

      # Check a specific product area
      {:ok, area} = Jido.Connect.Microsoft.Availability.fetch(:mail)

      # Get full catalog
      catalog = Jido.Connect.Microsoft.Availability.catalog()
  """

  alias Jido.Connect.Microsoft.Scopes

  @type status :: :available | :planned

  @type t :: %__MODULE__{
          id: atom(),
          label: String.t(),
          description: String.t(),
          status: status(),
          scopes: [String.t()],
          foundation_contracts: [atom()],
          product_package: atom() | nil,
          metadata: map()
        }

  @enforce_keys [:id, :label, :description, :status, :scopes, :foundation_contracts]
  defstruct [
    :id,
    :label,
    :description,
    :status,
    :scopes,
    :foundation_contracts,
    :product_package,
    metadata: %{}
  ]

  @doc "Returns all supported Microsoft Graph product area ids."
  @spec ids() :: [atom()]
  def ids, do: Enum.map(all(), & &1.id)

  @doc "Returns all supported Microsoft Graph product area metadata."
  @spec all() :: [t()]
  def all do
    [
      %__MODULE__{
        id: :mail,
        label: "Outlook Mail",
        description:
          "Microsoft Graph mail foundations: OAuth scopes, transport, pagination, and error normalization for Outlook mail endpoints.",
        status: :available,
        scopes: Scopes.product(:mail),
        foundation_contracts: [:oauth, :transport, :pagination, :account, :scopes, :checkpoint],
        product_package: :jido_connect_microsoft_outlook,
        metadata: %{
          graph_versions: [:v1_0, :beta],
          read_only_scopes: ["Mail.Read", "Mail.ReadBasic"]
        }
      },
      %__MODULE__{
        id: :calendar,
        label: "Microsoft Calendar",
        description:
          "Microsoft Graph calendar foundations: OAuth scopes, transport, pagination, and error normalization for calendar endpoints.",
        status: :available,
        scopes: Scopes.product(:calendar),
        foundation_contracts: [:oauth, :transport, :pagination, :account, :scopes, :checkpoint],
        product_package: :jido_connect_microsoft_calendar,
        metadata: %{graph_versions: [:v1_0, :beta], read_only_scopes: ["Calendars.Read"]}
      },
      %__MODULE__{
        id: :files,
        label: "OneDrive / SharePoint Files",
        description:
          "Microsoft Graph files foundations: OAuth scopes, transport, pagination, and error normalization for OneDrive and SharePoint file endpoints.",
        status: :available,
        scopes: Scopes.product(:files),
        foundation_contracts: [:oauth, :transport, :pagination, :account, :scopes, :checkpoint],
        product_package: :jido_connect_microsoft_onedrive,
        metadata: %{
          graph_versions: [:v1_0, :beta],
          read_only_scopes: ["Files.Read", "Files.Read.All"]
        }
      },
      %__MODULE__{
        id: :sharepoint,
        label: "Microsoft SharePoint",
        description:
          "Microsoft Graph foundations for SharePoint sites, lists, list items, pages, and selected-resource access.",
        status: :available,
        scopes: Scopes.product(:sharepoint),
        foundation_contracts: [:oauth, :transport, :pagination, :account, :scopes, :checkpoint],
        product_package: :jido_connect_microsoft_sharepoint,
        metadata: %{
          graph_versions: [:v1_0],
          read_only_scopes: ["Sites.Read.All", "Sites.Selected"]
        }
      },
      %__MODULE__{
        id: :contacts,
        label: "Microsoft Contacts",
        description:
          "Microsoft Graph contacts foundations: OAuth scopes, transport, pagination, and error normalization for contacts endpoints.",
        status: :available,
        scopes: Scopes.product(:contacts),
        foundation_contracts: [:oauth, :transport, :pagination, :account, :scopes, :checkpoint],
        product_package: :jido_connect_microsoft_contacts,
        metadata: %{graph_versions: [:v1_0], read_only_scopes: ["Contacts.Read"]}
      },
      %__MODULE__{
        id: :tasks,
        label: "Microsoft Tasks (To Do)",
        description:
          "Microsoft Graph tasks foundations: OAuth scopes, transport, pagination, and error normalization for To Do and Planner task endpoints.",
        status: :available,
        scopes: Scopes.product(:tasks),
        foundation_contracts: [:oauth, :transport, :pagination, :account, :scopes, :checkpoint],
        product_package: :jido_connect_microsoft_tasks,
        metadata: %{graph_versions: [:v1_0, :beta], read_only_scopes: ["Tasks.Read"]}
      },
      %__MODULE__{
        id: :teams,
        label: "Microsoft Teams",
        description:
          "Microsoft Graph teams foundations: OAuth scopes, transport, pagination, and error normalization for Teams chat and channel endpoints.",
        status: :available,
        scopes: Scopes.product(:teams),
        foundation_contracts: [:oauth, :transport, :pagination, :account, :scopes, :checkpoint],
        product_package: :jido_connect_microsoft_teams,
        metadata: %{
          graph_versions: [:v1_0, :beta],
          read_only_scopes: ["Team.ReadBasic.All", "Chat.Read"]
        }
      }
    ]
  end

  @doc "Returns the complete Microsoft Graph product-area availability catalog."
  @spec catalog() :: %{atom() => t()}
  def catalog, do: Map.new(all(), &{&1.id, &1})

  @doc "Fetches availability metadata for a specific product area."
  @spec fetch(atom()) :: {:ok, t()} | :error
  def fetch(area),
    do: Enum.find(all(), &(&1.id == area)) |> then(&if(&1, do: {:ok, &1}, else: :error))

  @doc "Fetches availability metadata for a specific product area or raises."
  @spec fetch!(atom()) :: t()
  def fetch!(area) do
    case fetch(area) do
      {:ok, metadata} -> metadata
      :error -> raise ArgumentError, "unknown Microsoft product area #{inspect(area)}"
    end
  end

  @doc "Returns the read-only scopes for a product area."
  @spec read_only_scopes(atom()) :: [String.t()]
  def read_only_scopes(area) do
    case fetch(area) do
      {:ok, %{metadata: %{read_only_scopes: scopes}}} -> scopes
      _other -> []
    end
  end

  @doc "Returns true when the foundation provides shared contracts for the given product area."
  @spec available?(atom()) :: boolean()
  def available?(area) when is_atom(area), do: area in ids()
  def available?(_other), do: false
end
