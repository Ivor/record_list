defmodule RecordList do
  @moduledoc """
  A struct that builds a list of records defined by a query by initialising with a set of parameters and passing the struct through a sequence of steps.
  A pagination struct `RecordList.Pagination` is built to capture the paging information.

  The libary is built to be open-ended but a typical pipeline could look something like:

  ```
  params -> base query -> apply sorting -> search against some criteria
    -> apply filtering -> calculate paging values -> retrieve the records.
  ```

  A RecordList can be created by calling

  ```elixir
    use RecordList,
      steps: [
        base: [impl: MyBaseStep],
        sort: [impl: MySortStep, default_sort: "name", default_order: "asc"],
        paginate: [impl: MyPaginationStep, per_page: 20, count_by: :id, repo: MyApp.Repo]
        retrieve: [impl: MyRetrieveStep]
      ]
  ```

  ## Steps

  Steps implement the `RecordList.StepBehaviour` behaviour.
  The `execute/3` function takes the record list in the making, the step name as an atom and any options that were passed in, for example, the `default_sort` and `default_order` options above.

  Steps are executed in the order in which they are defined in the `:steps` option to the `RecordList.__using__/1` macro.
  Calling a step will execute all the steps higher in the list of steps.

  ```elixir
    %RecordList{params: ^params, query: _base_query, steps: [:base]}
      = MyRecordList.base(params)
    %RecordList{loaded: true, records: _populated_with_results_of_query, params: ^params, query: _, steps: [:retrieve, :paginate, :sort, :base]}
      = MyRecordList.retrieve(params)
  ```

  Notice that calling `retrieve/1` returns a record list with the prior steps executed as well. Calling `paginate/1` will build the pagination struct, but not retrieve the records.

  ```elixir
    %RecordList{loaded: false, records: [], pagination: %RecordList.Pagination{records_count: _, records_offset: _}, steps: [:retrieve, :paginate, :sort, :base]}
      = MyRecordList.paginate(params)
  ```

  See `__struct__/0` for details about the attributes.
  """

  @typedoc """
  The RecordList struct collects meta data along with the list of records.

  ## Attributes
  * `:query`- the variable where the query is built up. In the case of Ecto this will be an Ecto.Query struct.
  * `:params`- Queries to create a record list are typically driven by parameters. These can be captured in the `params` attribute to be referenced in subsequent steps.
  * `:pagination`- paginating a list of data is common. RecordList comes with a `%RecordList.Pagination{}` struct that can be used to capture information describing the pages in the list.
  * `:loaded`- a boolean value indiciating whether the records have been loaded. An empty list of records does not capture the same information since the result of a query can be an empty list.
  * `:records`- a list of records retrieved by executing the query.
  * `:steps`- a list of the steps that have been executed. This makes it possible to not have to run a step.
  * `:extra`- a map of any extra information that might be needed along the way.
  """
  @type t :: %RecordList{}

  defstruct [:query, :params, :pagination, loaded: false, records: [], steps: [], extra: %{}]

  @doc false
  def add_step(%__MODULE__{steps: [step | _steps]} = record_list, step), do: record_list

  def add_step(%__MODULE__{steps: steps} = record_list, step) do
    # This clause should not be necessary since steps should be called in sequence.
    if Enum.member?(steps, step) do
      record_list
    else
      %{record_list | steps: [step | steps]}
    end
  end

  defmacro __using__(opts) do
    steps = Keyword.get(opts, :steps, [])
    step_keys = Keyword.keys(steps)

    # This defines the transformation steps that are executed on the initial record_list, usually to modify
    # the record_list.query which is used to retrieve the data in the `:retrieve` step.
    steps
    |> Enum.map(fn
      {step, step_opts} ->
        {impl, other_opts} = Keyword.pop!(step_opts, :impl)

        quote do
          def unquote(step)(%RecordList{} = record_list) do
            apply(unquote(impl), :execute, [record_list, unquote(step), unquote(other_opts)])
            |> RecordList.add_step(unquote(step))
          end

          def unquote(step)(params) when is_map(params) do
            unquote(step_keys)
            |> Enum.reduce_while(%RecordList{params: params}, fn
              unquote(step), record_list ->
                {:halt, record_list}

              missing_step, record_list ->
                {:cont, step(record_list, missing_step)}
            end)
            |> step(unquote(step))
          end

          def step(%RecordList{} = record_list, unquote(step)) do
            apply(__MODULE__, unquote(step), [record_list])
          end

          def step(params, unquote(step)) when is_map(params) do
            apply(__MODULE__, unquote(step), [params])
          end
        end
    end)
  end
end
