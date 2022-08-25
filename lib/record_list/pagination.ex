defmodule RecordList.Pagination do
  @moduledoc """
  A module that builds a `RecordList.Pagination.t()` struct with information about the paging of the records.
  """

  defstruct [
    :per_page,
    # Records info
    :records_count,
    :records_from,
    :records_to,
    :records_offset,
    # Pages info
    :total_pages,
    :next_page,
    :previous_page,
    :current_page
  ]

  @typedoc """
  A struct to capture paging information for use with, for example, paging controls.

  ## Attributes
  * `:per_page`- the number of records to return per page.
  * `:records_count`- The number of records in the query, prior to applying pagination. The result set to be paged through.
  * `:records_from`- The `:id` or `:index` of the first record in the paged result set.
  * `:records_to`- The `:id` or `:index` of the last record in the paged result set.
  * `:records_offset`- The offset from the start of the result set. This is 1 less than `:records_from`.
  * `:total_pages`- The number of pages, given `per_page` to get through the total results.
  * `:next_page`- the next page number.
  * `:previous_page`- the previous page number.
  * `:current_page`- the current page number.
  """
  @type t :: %__MODULE__{}

  @typedoc """
  The current page.
  """
  @type current_page :: nil | binary | integer
  @typedoc """
  The number of records per page.
  """
  @type per_page :: nil | binary | integer
  @typedoc """
  The total number of records returned by the query - typically from doing a count prior to paging.
  """
  @type count :: integer()

  @doc """
  Builds a `%RecordList.Pagination{}` struct from the `current_page`, `per_page` and `count` arguments.
  """
  @spec build(current_page(), per_page(), count()) :: __MODULE__.t()
  def build(current_page, per_page, count) do
    %__MODULE__{
      per_page: per_page,
      records_count: count,
      current_page: current_page
    }
    |> parse_pages()
    |> calculate_offset()
    |> add_total_pages()
    |> maybe_add_next_page()
    |> maybe_add_previous_page()
    |> maybe_add_from()
    |> maybe_add_to()
  end

  @doc """
  The per_page and current_page values can potentially be passed in as strings, e.g. "20" or "2".
  We ensure that the values are converted to integers in order to do the required calculations.
  """
  def parse_pages(%{per_page: per_page, current_page: current_page} = pagination) do
    %{pagination | per_page: ensure_int(per_page), current_page: ensure_int(current_page, 1)}
  end

  defp ensure_int(value, default \\ nil)

  defp ensure_int(value, default) when is_binary(value) do
    value
    |> String.to_integer()
    |> ensure_int(default)
  end

  defp ensure_int(value, _default) when is_integer(value) and value < 1 do
    raise "Value needs to be bigger than 0"
  end

  defp ensure_int(nil, default) when not is_nil(default), do: default

  defp ensure_int(value, _default) when is_integer(value), do: value

  @doc """
  Calculates the offset.
  """
  def calculate_offset(%{per_page: per_page, current_page: page} = pagination) do
    %{pagination | records_offset: (page - 1) * per_page}
  end

  @doc """
  Calculates the tota; number of pages.
  """
  def add_total_pages(%{records_count: count, per_page: per_page} = pagination) do
    %{pagination | total_pages: Kernel.ceil(count / per_page)}
  end

  @doc """
  Adds the next page unless current page is the last page.
  """
  def maybe_add_next_page(
        %{total_pages: total_pages_is_current_page, current_page: total_pages_is_current_page} =
          pagination
      ) do
    pagination
  end

  def maybe_add_next_page(%{current_page: current_page} = pagination) do
    %{pagination | next_page: current_page + 1}
  end

  @doc """
  Adds the previous page unless current page is the first page.
  """
  def maybe_add_previous_page(%{current_page: current_page} = pagination)
      when current_page <= 1 do
    pagination
  end

  def maybe_add_previous_page(%{current_page: current_page} = pagination) do
    %{pagination | previous_page: current_page - 1}
  end

  @doc """
  Adds the records_from value. 0 if count is nil, or 0. 1 if the previous_page is `nil` and otherwise 1 + offset.
  """
  def maybe_add_from(%{records_count: count} = pagination) when count in [nil, 0] do
    %{pagination | records_from: 0}
  end

  def maybe_add_from(%{previous_page: nil} = pagination) do
    %{pagination | records_from: 1}
  end

  def maybe_add_from(%{current_page: current_page, per_page: per_page} = pagination) do
    offset = (current_page - 1) * per_page
    %{pagination | records_from: offset + 1}
  end

  @doc """
  Adds the records_to value. 0 if count is nil, or 0. `count` if `count < per_page`. `records_count` if `is_nil(next_page). Otherwise current_page * per_page.
  """
  def maybe_add_to(%{records_count: count} = pagination) when count in [nil, 0] do
    pagination
  end

  def maybe_add_to(%{records_count: count, per_page: per_page} = pagination)
      when count < per_page do
    %{pagination | records_to: count}
  end

  def maybe_add_to(%{next_page: nil} = pagination) do
    %{pagination | records_to: pagination.records_count}
  end

  def maybe_add_to(%{current_page: current_page, per_page: per_page} = pagination) do
    to = current_page * per_page
    %{pagination | records_to: to}
  end
end
