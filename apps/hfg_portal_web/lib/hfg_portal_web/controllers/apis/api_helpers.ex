defmodule HfgPortalWeb.Apis.ApiHelpers do
  def parse_search_stack(nil), do: {:ok, nil}
  def parse_search_stack(json) when is_binary(json) do
    with {:ok, list} when is_list(list) <- Jason.decode(json) do
      entries =
        Enum.flat_map(list, fn entry ->
          with field when is_binary(field) <- Map.get(entry, "field"),
               val   when not is_nil(val)  <- Map.get(entry, "val"),
               atom  when not is_nil(atom) <- existing_atom(field) do
            [%{field: atom, val: val}]
          else
            _ -> []
          end
        end)
      {:ok, entries}
    else
      _ -> {:error, "search_stack must be a JSON array of {field, val} objects"}
    end
  end

  def parse_sort_stack(nil), do: {:ok, nil}
  def parse_sort_stack(json) when is_binary(json) do
    with {:ok, list} when is_list(list) <- Jason.decode(json) do
      entries =
        Enum.flat_map(list, fn entry ->
          with field when is_binary(field) <- Map.get(entry, "field"),
               order when order in ["asc", "desc"] <- Map.get(entry, "order"),
               atom when not is_nil(atom) <- existing_atom(field) do
            [%{field: atom, order: String.to_atom(order)}]
          else
            _ -> []
          end
        end)
      {:ok, entries}
    else
      _ -> {:error, "sort_stack must be a JSON array of {field, order} objects"}
    end
  end

  # unknown fields are ignored rather than minting atoms from user input
  defp existing_atom(field) do
    String.to_existing_atom(field)
  rescue
    ArgumentError -> nil
  end
end
