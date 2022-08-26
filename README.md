# RecordList

A stepwise construction of a struct, from a map of parameters, to return a list of records, and meta information about the query. 

Lists of records are useful in web applications and API's. The records returned often depend on paramaters such as sorting, filtering, searching and pagination. 
The RecordList struct is built up by passing it through the steps defined, capturing the information used to define the list as well as the records. 

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `record_list` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:record_list, "~> 0.1.0"}
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
      sort: [callback: fn q, v -> Ecto.Query.order_by(q, ^v) end, default_order: "asc", default_sort: "name"],
      retrieve: [repo: MyApp.Repo]
    ]

  @behaviour RecordList.StepBehaviour

  @impl true
  def execute(%RecordList{params: %{"user_id" => user_id} = _params} = record_list, :base, _opts) do
    query = from(p in Post, where: p.user_id == ^user_id)
    %{ record_list | query: query }
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

In practice search and filter steps have been sufficiently unique, and a default implementation has not presented itself. 
In the example above a default `:sort` and default `:retrieval` (Ecto.Repo) step has been used. There is also a simple, default `:paginate` step, which adds a `%RecordList.Pagination{}` struct with useful information about the count, offset, and page info. 

```elixir
defmodule MyApp.MyPagimatedList do
  import Ecto.Query

  use RecordList, 
    steps: [
      base: [impl: __MODULE__],
      paginate: [offset_callback: fn q, offset -> Ecto.Query.offset(q, ^offset) end, limit_callback: fn q, limit -> Ecto.Query.limit(q, ^limit) end, per_page: 10, repo: MyApp.Repo],
      retrieve: [repo: MyApp.Repo]
    ]

  @behaviour RecordList.StepBehaviour

  @impl true
  def execute(%RecordList{params: %{"user_id" => user_id} = _params} = record_list, :base, _opts) do
    query = from(p in Post, where: p.user_id == ^user_id)
    %{ record_list | query: query }
  end

end
```

```elixir  
%RecordList{records: []], loaded: false, steps: [:paginate, :base], pagination: %RecordList.Pagination{records_count: _, current_page: _}} = paginated_record_list = MyApp.MyRecordList.paginate(params)
%RecordList{records: records, loaded: true, steps: [:retrieve, :paginate, :base]} = retrieved_record_list = MyApp.MyRecordList.retrieve(paginated_record_list)
# Or
%RecordList{records: records, loaded: true, steps: [:retrieve, :paginate, :base]} = retrieved_record_list = MyApp.MyRecordList.retrieve(params)
```

In both these cases the base step is implemented in the module where we use RecordList. A different implementation can also be passed. This way different record lists can use the same base query. The same goes for other steps. Options for a step are passed into the corresponding `execute/3` callback which allows configuring of custom implementations. 
