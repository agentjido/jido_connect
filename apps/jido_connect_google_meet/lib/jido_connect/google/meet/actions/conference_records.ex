defmodule Jido.Connect.Google.Meet.Actions.ConferenceRecords do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @readonly_scope "https://www.googleapis.com/auth/meetings.space.readonly"
  @scope_resolver Jido.Connect.Google.Meet.ScopeResolver

  actions do
    action :list_conference_records do
      id("google.meet.conference_record.list")
      resource(:conference_record)
      verb(:list)
      data_classification(:personal_data)
      label("List Meet conference records")
      description("List Google Meet conference records visible to the user.")
      handler(Jido.Connect.Google.Meet.Handlers.Actions.ListConferenceRecords)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:page_size, :integer, default: 25)
        field(:page_token, :string)
        field(:filter, :string)
        field(:fields, :string)
      end

      output do
        field(:conference_records, {:array, :map})
        field(:next_page_token, :string)
      end
    end

    action :get_conference_record do
      id("google.meet.conference_record.get")
      resource(:conference_record)
      verb(:get)
      data_classification(:personal_data)
      label("Get Meet conference record")
      description("Fetch a Google Meet conference record by resource name.")
      handler(Jido.Connect.Google.Meet.Handlers.Actions.GetConferenceRecord)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:conference_record_name, :string,
          required?: true,
          example: "conferenceRecords/abc"
        )

        field(:fields, :string)
      end

      output do
        field(:conference_record, :map)
      end
    end
  end
end
