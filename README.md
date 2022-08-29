# RecordList

A stepwise construction of a struct, from a map of parameters, to return a list of records, and meta information about the query. 

Lists of records are useful in web applications and API's. The records returned often depend on parameters such as sorting, filtering, searching and pagination. 
The RecordList struct is built up by passing it through the steps defined, capturing the information used to define the list as well as the records. 

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `record_list` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:record_list, "~> 0.1.3"}
  ]
end
```

## Usage

Depending on the steps defined, a RecordList can be built up based on a database query, an Elixir Stream, an enumarable, etc. 
No sequence of steps is enforced. However, the steps are called in the order in which they are defined. 

```elixir
defmodule MyApp.MyRecordList do
  import Ecto.Query

  use RecordList, 
    steps: [
      base: [impl: __MODULE__],
      sort: [impl: __MODULE__, default_order: "asc", default_sort: "name"],
      retrieve: [impl: __MODULE__, repo: MyApp.Repo]
    ]

  @behaviour RecordList.StepBehaviour

  @impl true
  def execute(%RecordList{params: %{"user_id" => user_id} = _params} = record_list, :base, _opts) do
    query = from(p in Post, where: p.user_id == ^user_id)
    %{ record_list | query: query }
  end

  @impl true
  def execute(%RecordList{params: params, query: query} = record_list, :sort, opts) do
    sort = get_in(params, ["sort"]) || Keyword.fetch!(opts, :default_sort)
    order = get_in(params, ["order"]) || Keyword.fetch!(opts, :default_order)
    query = order_by(query, [^order, ^sort])

    %{ record_list | query: query }
  end

  @impl true
  def execute(%RecordList{query: query} = record_list, :retrieve, opts) do
    %{ record_list | records: MyApp.Repo.all(query), loaded: true }
  end  

end
```

```elixir
%RecordList{records: [], loaded: false, steps: [:sort, :base]} = 
  sorted_record_list = MyApp.MyRecordList.sort(params)
%RecordList{records: records, loaded: true, steps: [:retrieve, :sort, :base]} 
  = retrieved_record_list = MyApp.MyRecordList.retrieve(sorted_record_list)
# Or
%RecordList{records: records, loaded: true, steps: [:retrieve, :sort, :base]} 
  = retrieved_record_list = MyApp.MyRecordList.retrieve(params)
```

In the example above the implementation is in the module implementing `RecordList`. To allow defining multiple steps in the same module the step `atom` is passed as the second argument. 
By passing in a different module you can share implemenation of a step between different RecordLists. 

If you are using RecordList with Ecto, add [RecordListEcto](https://hexdocs.pm/record_list_ecto) to your depedencies. Then pass the steps in that library as implementations when defining your record list. 

```elixir
  def deps do
    [
      {:record_list, "~> 0.1.3"},
      {:record_list_ecto, "~> 0.1.2"}
    ]
  end
```

```elixir
defmodule MyEctoApp.MyRecordList do
  use RecordList, 
    steps: [
      ...,
      sort: [impl: RecordListEcto.SortStep, ...],
      paginate: [impl: RecordListEcto.PaginateStep, ...],
      ...
    ]
end
```


```elixir  
%RecordList{records: []], loaded: false, steps: [:paginate, :base], pagination: %RecordList.Pagination{records_count: _, current_page: _}} 
  = paginated_record_list = MyEctoApp.MyRecordList.paginate(params)
%RecordList{records: records, loaded: true, steps: [:retrieve, :paginate, :base]} 
  = retrieved_record_list = MyEctoApp.MyRecordList.retrieve(paginated_record_list)
# Or
%RecordList{records: records, loaded: true, steps: [:retrieve, :paginate, :base]} 
  = retrieved_record_list = MyEctoApp.MyRecordList.retrieve(params)
```

The `RecordList.__using__` macro would have added the following functions for `sort` to your `MyEctoApp.MyRecordList` module. 

```elixir
  def sort(%RecordList{} = record_list) do
    apply(RecordListEcto.SortStep, :execute, [record_list, :sort, options_for_step_other_than_impl])
  end

  # When called with the params map, record list will run through all the prior steps before calling the version of this 
  # step that takes the record_list. 
  def sort(params) do
    step_keys
    |> Enum.reduce_while(%RecordList{params: params}, fn step, record_list -> 
        :sort, record_list ->
          {:halt, record_list}

        missing_step, record_list ->
          {:cont, step(record_list, missing_step)}
      end)
      |> step(:sort)
    end)
  end

  def step(%RecordList{} = record_list, :sort) do
    apply(__MODULE__, :sort, [record_list])
  end

  def step(params, sort) when is_map(params) do
    apply(__MODULE__, :sort, [params])
  end
  
```
