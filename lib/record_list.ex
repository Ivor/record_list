defmodule RecordList do
  @moduledoc """
  A record list is a struct that contains a query that is sequentially built up by passing it through a pipeline of steps.
  The struct collects the steps that have been executed and can finally contain the records as well as pagination information describing a simple implementation of pagination.

  The libary is built to be open-ended but a typical pipeline could look something like:

  %RecordList{}
  |> base()
  |> sort()
  |> search()
  |> filter()
  |> paginate()
  |> retrieve()

  The steps are defined in a list and implemented to call all the steps that we're defined higher in the list.
  This means that you can call paginate to get the pagination information without actually retrieving the records.
  Then when required, you can call retrieve to populate the `records` attribute of the struct.
  The `loaded` attribute can be used to help indicate wether the records have been loaded.

  Attributes:
   - query: the variable where the query is built up. In the case of Ecto this will be an Ecto.Query struct.
   - params: queries to create a record list are typically driven by parameters. These can be captured in the `params` attribute to be referenced in subsequent steps.
   - pagination: paginating a list of data is common. RecordList comes with a %RecordList.Pagination{} struct that can be used to capture information describing the pages in the list.
   - loaded: a boolean value indiciating whether the records have been loaded. An empty list of records does not capture the same information since the result of a query can be an empty list.
   - records: a list of records retrieved by executing the query.
   - steps: a list of the steps that have been executed. This makes it possible to not have to run a step.
   - extra: a map of any extra information that might be needed along the way.
  """

  defstruct [:query, :params, :pagination, loaded: false, records: [], steps: [], extra: %{}]

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
          # TODO: perhaps pass in the step options as default but allow overriding?
          def unquote(step)(%RecordList{} = record_list) do
            # TODO: we can maintain a list of all the step keys.
            # Then they can all be called in sequence until this point
            # TODO: ensure that the steps before the current step are in the list of steps.
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
            # Now we have a record list up to just before this step.
            |> step(unquote(step))
          end

          # TODO: do we need this form if we're going with the top form?
          # This does allow for more dynamism by allowing for passing in a list of steps that can be reduced over.
          def step(%RecordList{} = record_list, unquote(step)) do
            unquote(step)(record_list)
            # apply(unquote(impl), :execute, [record_list, unquote(step), unquote(other_opts)])
          end
        end
    end)
  end
end
