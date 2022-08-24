defmodule RecordList.Pagination do
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

  @type t :: %__MODULE__{}
  @type current_page :: nil | binary | integer
  @type per_page :: nil | binary | integer
  @type count :: integer()

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

  # Offset is 0 for the first page.
  def calculate_offset(%{per_page: per_page, current_page: page} = pagination) do
    %{pagination | records_offset: (page - 1) * per_page}
  end

  def add_total_pages(%{records_count: count, per_page: per_page} = pagination) do
    %{pagination | total_pages: Kernel.ceil(count / per_page)}
  end

  def maybe_add_next_page(
        %{total_pages: total_pages_is_current_page, current_page: total_pages_is_current_page} =
          pagination
      ) do
    pagination
  end

  def maybe_add_next_page(%{current_page: current_page} = pagination) do
    %{pagination | next_page: current_page + 1}
  end

  def maybe_add_previous_page(%{current_page: current_page} = pagination)
      when current_page <= 1 do
    pagination
  end

  def maybe_add_previous_page(%{current_page: current_page} = pagination) do
    %{pagination | previous_page: current_page - 1}
  end

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
