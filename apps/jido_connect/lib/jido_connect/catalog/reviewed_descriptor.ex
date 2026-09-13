defmodule Jido.Connect.Catalog.ReviewedDescriptor do
  @moduledoc false

  alias Jido.Connect.Catalog.{Fingerprint, Item, Pack, Serializer}

  @spec project_item(Item.t(), Pack.t()) :: Item.t()
  def project_item(%Item{} = item, %Pack{} = pack) do
    pack = Pack.reviewed_provenance(pack)

    reviewed = %{
      item
      | pack: pack,
        metadata: Map.merge(item.metadata, reviewed_item_metadata(item, pack)),
        reviewed_fingerprint: nil
    }

    fingerprint =
      reviewed
      |> Serializer.to_map()
      |> Map.delete(:reviewed_fingerprint)
      |> Fingerprint.reviewed_descriptor()

    %{reviewed | reviewed_fingerprint: fingerprint}
  end

  defp reviewed_item_metadata(%Item{} = item, pack) do
    %{
      provider: item.provider,
      package: item.package,
      pack: pack,
      risk: item.risk,
      confirmation: item.confirmation,
      scopes: item.scopes,
      policies: Enum.map(item.policies, & &1.id),
      host_policy_required?: item.host_policy_required?
    }
  end
end
