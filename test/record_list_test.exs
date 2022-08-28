defmodule RecordListTest.StreamRecordList do
  @moduledoc """
  This module is a contrived case where we're using Elixir's Stream module to genrate data that we can paginate.

  """

  use RecordList,
    steps: [
      base: [impl: __MODULE__],
      paginate: [impl: __MODULE__, per_page: 10],
      retrieve: [impl: __MODULE__]
    ]

  @behaviour RecordList.StepBehaviour

  @impl true
  def execute(%RecordList{params: _} = record_list, :base, _opts) do
    %{record_list | query: 1..100}
  end

  @impl true
  def execute(%RecordList{params: params, query: query} = record_list, :paginate, opts) do
    per_page = Keyword.fetch!(opts, :per_page)
    count = Enum.count(query)

    pagination = RecordList.Pagination.build(Map.get(params, "page"), per_page, count)

    query =
      Stream.map(query, & &1)
      |> Stream.drop_while(&(&1 < pagination.records_from))
      |> Stream.take_while(&(&1 <= pagination.records_to))

    %{record_list | pagination: pagination, query: query}
  end

  @impl true
  def execute(%RecordList{query: query} = record_list, :retrieve, _opts) do
    %{record_list | records: Enum.to_list(query), loaded: true}
  end
end

defmodule RecordListTest do
  use ExUnit.Case
  doctest RecordList

  alias RecordListTest.StreamRecordList

  test "calculates the pagination correctly" do
    first_page = StreamRecordList.paginate(%{"page" => "1"})

    refute first_page.loaded
    assert [] = first_page.records

    assert first_page.pagination.records_offset == 0
    assert first_page.pagination.records_from == 1
    assert first_page.pagination.records_to == 10
    assert first_page.pagination.total_pages == 10
    assert first_page.pagination.current_page == 1
    assert is_nil(first_page.pagination.previous_page)
    assert first_page.pagination.next_page == 2
  end

  test "returns the records" do
    second_page = StreamRecordList.retrieve(%{"page" => "2"})

    assert second_page.records == 11..20 |> Enum.to_list()
    assert second_page.loaded
    assert second_page.pagination.records_offset == 10
    assert second_page.pagination.records_from == 11
    assert second_page.pagination.records_to == 20
    assert second_page.pagination.total_pages == 10
    assert second_page.pagination.current_page == 2
    assert second_page.pagination.previous_page == 1
    assert second_page.pagination.next_page == 3

    third_page = StreamRecordList.retrieve(%{"page" => "3"})

    assert third_page.records == 21..30 |> Enum.to_list()
    assert third_page.loaded
    assert third_page.pagination.records_offset == 20
    assert third_page.pagination.records_from == 21
    assert third_page.pagination.records_to == 30
    assert third_page.pagination.total_pages == 10
    assert third_page.pagination.current_page == 3
    assert third_page.pagination.previous_page == 2
    assert third_page.pagination.next_page == 4
  end

  test "returns the right values for the last page" do
    last_page = StreamRecordList.retrieve(%{"page" => 10})

    assert last_page.records == 91..100 |> Enum.to_list()
    assert last_page.loaded
    assert last_page.pagination.records_offset == 90
    assert last_page.pagination.records_from == 91
    assert last_page.pagination.records_to == 100
    assert last_page.pagination.total_pages == 10
    assert last_page.pagination.current_page == 10
    assert last_page.pagination.previous_page == 9
    assert is_nil(last_page.pagination.next_page)
  end

  test "captures the steps" do
    params = %{}
    assert %{steps: [:base]} = _record_list = StreamRecordList.base(params)
    assert %{steps: [:paginate, :base]} = _record_list = StreamRecordList.paginate(params)

    assert %{steps: [:retrieve, :paginate, :base]} =
             _record_list = StreamRecordList.retrieve(params)
  end

  test "also generates the step/2 function" do
    params = %{}
    assert %{steps: [:base]} = _record_list = StreamRecordList.step(params, :base)
    assert %{steps: [:paginate, :base]} = _record_list = StreamRecordList.step(params, :paginate)

    assert %{steps: [:retrieve, :paginate, :base]} =
             _record_list = StreamRecordList.step(params, :retrieve)
  end
end
