defmodule Jido.Connect.Google.Contacts.Client.Response do
  @moduledoc "Google People API response handling for Contacts."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.Contacts.{Client.Transport, Normalizer}

  def handle_person_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, people} <-
           normalize_items(
             body,
             "connections",
             &Normalizer.person/1,
             "Google Contacts person list response was invalid"
           ) do
      {:ok,
       %{
         people: people,
         next_page_token: Data.get(body, "nextPageToken"),
         next_sync_token: Data.get(body, "nextSyncToken"),
         total_items: Data.get(body, "totalItems")
       }
       |> Data.compact()}
    end
  end

  def handle_person_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Contacts person list response was invalid", body)
  end

  def handle_person_list_response(response), do: Transport.handle_error_response(response)

  def handle_person_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.person/1, "Google Contacts person response was invalid")
  end

  def handle_person_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Contacts person response was invalid", body)
  end

  def handle_person_response(response), do: Transport.handle_error_response(response)

  def handle_person_batch_get_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    handle_person_response_items(
      body,
      "responses",
      "Google Contacts person batch get response was invalid"
    )
  end

  def handle_person_batch_get_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response(
      "Google Contacts person batch get response was invalid",
      body
    )
  end

  def handle_person_batch_get_response(response), do: Transport.handle_error_response(response)

  def handle_person_search_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, people} <-
           normalize_items(
             body,
             "results",
             &normalize_search_result/1,
             "Google Contacts person search response was invalid"
           ) do
      {:ok, %{people: people}}
    end
  end

  def handle_person_search_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Contacts person search response was invalid", body)
  end

  def handle_person_search_response(response), do: Transport.handle_error_response(response)

  def handle_directory_people_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, people} <-
           normalize_items(
             body,
             "people",
             &Normalizer.person/1,
             "Google Contacts directory people response was invalid"
           ) do
      {:ok,
       %{
         people: people,
         next_page_token: Data.get(body, "nextPageToken"),
         next_sync_token: Data.get(body, "nextSyncToken")
       }
       |> Data.compact()}
    end
  end

  def handle_directory_people_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response(
      "Google Contacts directory people response was invalid",
      body
    )
  end

  def handle_directory_people_list_response(response),
    do: Transport.handle_error_response(response)

  def handle_directory_people_search_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, people} <-
           normalize_items(
             body,
             "people",
             &Normalizer.person/1,
             "Google Contacts directory people search response was invalid"
           ) do
      {:ok,
       %{
         people: people,
         next_page_token: Data.get(body, "nextPageToken"),
         total_size: Data.get(body, "totalSize")
       }
       |> Data.compact()}
    end
  end

  def handle_directory_people_search_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response(
      "Google Contacts directory people search response was invalid",
      body
    )
  end

  def handle_directory_people_search_response(response),
    do: Transport.handle_error_response(response)

  def handle_other_contacts_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, people} <-
           normalize_items(
             body,
             "otherContacts",
             &Normalizer.person/1,
             "Google Contacts other contacts response was invalid"
           ) do
      {:ok,
       %{
         people: people,
         next_page_token: Data.get(body, "nextPageToken"),
         next_sync_token: Data.get(body, "nextSyncToken"),
         total_size: Data.get(body, "totalSize")
       }
       |> Data.compact()}
    end
  end

  def handle_other_contacts_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response(
      "Google Contacts other contacts response was invalid",
      body
    )
  end

  def handle_other_contacts_list_response(response), do: Transport.handle_error_response(response)

  def handle_person_batch_create_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    handle_person_response_items(
      body,
      "createdPeople",
      "Google Contacts person batch create response was invalid"
    )
  end

  def handle_person_batch_create_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response(
      "Google Contacts person batch create response was invalid",
      body
    )
  end

  def handle_person_batch_create_response(response), do: Transport.handle_error_response(response)

  def handle_person_batch_update_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "updateResult", %{}) do
      update_result when is_map(update_result) ->
        update_result
        |> Enum.reduce_while({:ok, %{}}, fn {resource_name, payload}, {:ok, acc} ->
          case normalize_person_response(payload) do
            {:ok, response} -> {:cont, {:ok, Map.put(acc, resource_name, response)}}
            {:error, _error} -> {:halt, invalid_batch_update_response(body)}
          end
        end)
        |> case do
          {:ok, responses} ->
            people = Enum.map(responses, fn {_key, response} -> response.person end)
            {:ok, %{people: people, responses: responses}}

          {:error, error} ->
            {:error, error}
        end

      _invalid ->
        invalid_batch_update_response(body)
    end
  end

  def handle_person_batch_update_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    invalid_batch_update_response(body)
  end

  def handle_person_batch_update_response(response), do: Transport.handle_error_response(response)

  def handle_person_batch_delete_response({:ok, %{status: status}}, params)
      when status in 200..299 do
    {:ok, %{resource_names: Data.get(params, :resource_names, []), deleted?: true}}
  end

  def handle_person_batch_delete_response(response, _params),
    do: Transport.handle_error_response(response)

  def handle_contact_delete_response({:ok, %{status: status}}, params) when status in 200..299 do
    {:ok,
     %{
       resource_name: Data.get(params, :resource_name),
       deleted?: true
     }}
  end

  def handle_contact_delete_response(response, _params),
    do: Transport.handle_error_response(response)

  def handle_contact_group_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, groups} <-
           normalize_items(
             body,
             "contactGroups",
             &Normalizer.group/1,
             "Google Contacts contact group list response was invalid"
           ) do
      {:ok,
       %{
         groups: groups,
         next_page_token: Data.get(body, "nextPageToken"),
         next_sync_token: Data.get(body, "nextSyncToken")
       }
       |> Data.compact()}
    end
  end

  def handle_contact_group_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response(
      "Google Contacts contact group list response was invalid",
      body
    )
  end

  def handle_contact_group_list_response(response), do: Transport.handle_error_response(response)

  def handle_contact_group_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.group/1, "Google Contacts contact group response was invalid")
  end

  def handle_contact_group_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Contacts contact group response was invalid", body)
  end

  def handle_contact_group_response(response), do: Transport.handle_error_response(response)

  defp normalize_one(body, normalizer, message) do
    case normalizer.(body) do
      {:ok, item} -> {:ok, item}
      {:error, _error} -> Transport.invalid_success_response(message, body)
    end
  end

  defp handle_person_response_items(body, key, message) do
    with {:ok, responses} <- normalize_person_response_items(body, key, message) do
      {:ok, %{people: Enum.map(responses, & &1.person), responses: responses}}
    end
  end

  defp normalize_person_response_items(body, key, message) do
    case Data.get(body, key, []) do
      items when is_list(items) ->
        items
        |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
          case normalize_person_response(payload) do
            {:ok, response} -> {:cont, {:ok, [response | acc]}}
            {:error, _error} -> {:halt, Transport.invalid_success_response(message, body)}
          end
        end)
        |> case do
          {:ok, responses} -> {:ok, Enum.reverse(responses)}
          {:error, error} -> {:error, error}
        end

      _invalid ->
        Transport.invalid_success_response(message, body)
    end
  end

  defp normalize_person_response(payload) when is_map(payload) do
    with person when is_map(person) <- Data.get(payload, "person"),
         {:ok, normalized} <- Normalizer.person(person) do
      {:ok, %{person: normalized, status: Data.get(payload, "status")}}
    else
      _invalid -> {:error, :invalid_person_response}
    end
  end

  defp normalize_person_response(_payload), do: {:error, :invalid_person_response}

  defp invalid_batch_update_response(body) do
    Transport.invalid_success_response(
      "Google Contacts person batch update response was invalid",
      body
    )
  end

  defp normalize_items(body, key, normalizer, message) do
    case Data.get(body, key, []) do
      items when is_list(items) ->
        items
        |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
          case normalizer.(payload) do
            {:ok, item} -> {:cont, {:ok, [item | acc]}}
            {:error, _error} -> {:halt, Transport.invalid_success_response(message, body)}
          end
        end)
        |> case do
          {:ok, items} -> {:ok, Enum.reverse(items)}
          {:error, error} -> {:error, error}
        end

      _invalid ->
        Transport.invalid_success_response(message, body)
    end
  end

  defp normalize_search_result(result) do
    case Data.get(result, "person") do
      person when is_map(person) -> Normalizer.person(person)
      _missing -> {:error, :missing_person}
    end
  end
end
