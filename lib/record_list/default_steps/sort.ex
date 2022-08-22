defmodule RecordList.Sort do
  @moduledoc """
  A default sort implementation. This is written with Ecto in mind but written in such a way that a callback or module is passed in to do the actual ordering.
  The callback will receive the query, as well as a keyword list off the form: [order: sort] where order is one of: `[:asc, :desc, :asc_nulls_last, :desc_nulls_last]`
  where `nulls_last` depends on the configuration option `:nulls_last`.

  In the case of passing in a module as callback, `:order_by` will be called on on the module with same arguments. This maps onto the Ecto.Query.order_by(query, asc: "name") pattern expected by Ecto.Query.

  use RecordList,
  steps: [
    ...,
    sort: [callback: Ecto.Query, default_order: :asc, default_sort: "name", order_keys: ["order"], sort_keys: ["sort"]],
    ...
  ]

  Configuration:
    :callback - An function that accepts to arguments. The query and a tuple with the order and sort key. callback.(query, [{order, sort}]). An example would be callback: fn q, v -> Ecto.Query.order_by(q, ^v) end
    :default_order - default value to use when no order in parameters
    :default_sort -  default value to use when no sort in parameters
    :order_keys - path to be passed `get_in /2` to extract the order value from params. Default is ["order"], meaning the order value lives on the top level of the params. %{"order" => "asc"} = params
    :sort_keys - path to be passed `get_in /2` to extract the sort value from params. Default is ["sort"], meaning the sort value lives on the top level of the params. %{"sort" => "name"} = params

  """
  @behaviour RecordList.StepBehaviour

    @impl true
  def execute(%RecordList{params: params, query: query} = data_list, :sort, opts) do
    sort = get_sort(params, opts)
    order = get_order(params, opts)

    new_query = query |> apply_ordering([{order, sort}], opts)

    %{data_list | query: new_query}
  end

  defp get_sort(params, opts) do
    path = Keyword.get(opts, :sort_keys, ["sort"])

    (get_in(params, path) || Keyword.fetch!(opts, :default_sort))
    |> binary_to_atom()
  end

  defp get_order(params, opts) do
    path = Keyword.get(opts, :order_keys, ["order"])

    (get_in(params, path) || Keyword.fetch!(opts, :default_order))
    |> binary_to_atom()
    |> then(fn atom_order ->
      if Keyword.get(opts, :nulls_last, _default = true) do
        order_nulls_last(atom_order)
      else
        atom_order
      end
    end)
  end

  defp apply_ordering(query, values, opts) do
    callback = Keyword.fetch!(opts, :callback)
    callback.(query, values)
  end

  defp order_nulls_last(:asc), do: :asc_nulls_last
  defp order_nulls_last(:desc), do: :desc_nulls_last

  defp binary_to_atom(order) when is_atom(order) do
    order
  end

  defp binary_to_atom(order) when is_binary(order) do
    String.to_existing_atom(order)
  end
end
