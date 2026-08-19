defmodule Jido.Connect.Catalog.ReviewedDescriptor do
  @moduledoc false

  alias Jido.Connect.Catalog.{Fingerprint, Pack, Serializer, ToolDescriptor}

  @spec project(ToolDescriptor.t(), Pack.t()) :: ToolDescriptor.t()
  def project(%ToolDescriptor{} = descriptor, %Pack{} = pack) do
    pack = Pack.reviewed_provenance(pack)

    reviewed = %{
      descriptor
      | pack: pack,
        metadata: Map.merge(descriptor.metadata, reviewed_metadata(descriptor, pack)),
        reviewed_fingerprint: nil
    }

    fingerprint =
      reviewed
      |> Serializer.to_map()
      |> Map.delete(:reviewed_fingerprint)
      |> Fingerprint.reviewed_descriptor()

    %{reviewed | reviewed_fingerprint: fingerprint}
  end

  defp reviewed_metadata(%ToolDescriptor{} = descriptor, pack) do
    %{
      provider: descriptor.tool.provider,
      package: descriptor.tool.package,
      pack: pack,
      risk: descriptor.risk,
      confirmation: descriptor.confirmation,
      scopes: descriptor.scopes,
      policies: Enum.map(descriptor.policies, & &1.id)
    }
  end
end
