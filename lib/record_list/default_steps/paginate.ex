defmodule RecordList.Paginate do
  @moduledoc """
  This is a default implementation of pagination. It relies on Ecto and does naive offset + limit pagination.

  Configuration:
    :repo - a module that exposes an `aggregate/3` function, to count the number of records that match the query. This follows the pattern similar to Ecto.Repo.aggregate(query, :count, count_by)
    :count_by - a field, default `:id` by which to count the records. Similar to the third argument to Ecto.Repo.aggregate/3.
    :per_page - default value for how many records to return per page. Required if this value is not passed in via params.
    :per_page_keys - a list of keys to be used as the path for `get_in/2` to extract the per_page value from params. Defaults to `["per_page"]` but is also optional if per_page will never be passed in via params.
    :page_keys - a list of keys to be used as the path for `get_in/2` to extract the current page from params. Default to `["page"]`.
    :limit_callback - a callback that will receive the query and the limit as arguments, or a module that exports `limit/2` which will receive the same arguments.
    :offset_callback - a callback that will receive the query and the offset as arguments, or a module that exports `offset/2` which will receive the same arguments.

  In the execution of this step, a count (on :count_by) is done on the repo to determine the total records that match the query.
  This along with the page and per_page values is then used to build the %RecordList.Pagination{} struct.
  This struct is assigned to the `pagination` attribute of the RecordList.

  %RecordList.Pagination{
    per_page: <number of records per page for the current pagination values>,
    records_count: <number of records that match the query>,
    records_from: <index of the first record on the page, in the context of the entire list>,
    records_to: <index of the last record on the page, in the context of the entire list>,
    records_offset: <The offset in the list before the first record in the record set. `records_from - 1`>,
    total_pages: <total number of pages>,
    current_page: <current page number>,
    previous_page: <page number of the previous page>,
    next_page: <page number of the next page>
  }

  The result of this step has this struct embedded in the record list struct:

  %RecordList{pagination: %RecordList.Pagination{}}

  """

  @behaviour RecordList.StepBehaviour

  @impl true
  def execute(%RecordList{query: query, params: params} = data_list, :paginate, opts \\ []) do
    repo = Keyword.fetch!(opts, :repo)
    count_by = Keyword.get(opts, :count_by, :id)
    count = repo.aggregate(query, :count, count_by)

    current_page = current_page(params, opts)
    per_page = get_per_page(params, opts)

    pagination = RecordList.Pagination.build(current_page, per_page, count)

    new_query =
      query
      |> apply_offset(pagination.records_offset, opts)
      |> apply_limit(pagination.per_page, opts)

    %{data_list | query: new_query, pagination: pagination}
  end

  defp get_per_page(params, opts) do
    params
    |> get_in(Keyword.get(opts, :per_page_keys, ["per_page"]))
    |> then(fn
      nil -> Keyword.fetch!(opts, :per_page)
      per_page_from_params -> per_page_from_params
    end)
    |> ensure_integer()
  end

  defp current_page(params, opts) do
    params
    |> get_in(Keyword.get(opts, :page_keys, ["page"]))
    |> ensure_integer(1)
    |> max(1)
  end

  defp apply_offset(query, offset, opts) do
    callback = Keyword.fetch!(opts, :offset_callback)

    cond do
      is_function(callback) -> callback.(query, offset)
      Enum.member?(callback.__info__(:functions), {:offset, 2}) -> callback.offset(query, offset)
      Enum.member?(callback.__info__(:macros), {:offset, 2}) -> callback.offset(query, offset)
      true -> raise "Please pass in either an anonymous function with arity 2 or a module that exports either a function or a macro named :offset with arity 2 to the `:offset_callback` option. Ecto.Query works as this module."
    end
  end

  defp apply_limit(query, limit, opts) do
    callback = Keyword.fetch!(opts, :limit_callback)

    cond do
      is_function(callback) -> callback.(query, limit)
      Enum.member?(callback.__info__(:functions), {:limit, 2}) -> callback.limit(query, limit)
      Enum.member?(callback.__info__(:macros), {:limit, 2}) -> callback.limit(query, limit)
      true -> raise "Please pass in either an anonymous function with arity 2 or a module that exports either a function or a macro named :limit with arity 2 to the `:limit_callback` option. Ecto.Query works as this module."
    end
  end

  def ensure_integer(value, default \\ nil)

  def ensure_integer(nil, nil),
    do: raise("ensure_integer(value, default) -> value is nil and the default is nil.")

  def ensure_integer(nil, default), do: default
  def ensure_integer("", default), do: default

  def ensure_integer(value, _default) when is_integer(value), do: value

  def ensure_integer(value, _default) do
    with {integer, ""} <- Integer.parse(value) do
      integer
    else
      _ -> raise "value #{value} not parsable as an integer"
    end
  end
end
