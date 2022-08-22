# RecordList

RecordList is a library for building a list of records that have gone through a series of steps. This sounds vague because it is very open-ended. 
You can define any steps you want and string them along to form a pipeline. The result is a struct that has some attributes that make it more useful than just the list. 
The use case that lead to RecordList is one where records are retrieved and presented to the user in a table. These tables typically have sortable columns, pagination controls, a search box an sometimes filters. A RecordList could be setup to start with a base query, apply sorting, apply filtering, apply a search, calculate pagination parameters and retrieve the data.

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

The parameters for this pipeline of steps are often driven by the query parameters. As such any of the steps can receive a map with string keys as the argument. 
The steps are executed in the order in which they are defined in the RecordList options. 

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
  
%RecordList{records: []], loaded: false, steps: [:sort, :base]} = sorted_record_list = MyApp.MyRecordList.sort(params)
%RecordList{records: records, loaded: true, steps: [:retrieve, :sort, :base]} = retrieved_record_list = MyApp.MyRecordList.retrieve(sorted_record_list)
# Or
%RecordList{records: records, loaded: true, steps: [:retrieve, :sort, :base]} = retrieved_record_list = MyApp.MyRecordList.retrieve(params)
```

In practice search and filter steps have been sufficiently different that a default implementation has not presented itself. In the example above a default `:sort` and default `:retrieval` (Ecto.Repo) step has been used. There is also a simple, default `:paginate` step, which adds a `%RecordList.Pagination{}` struct with useful information about the count, offset, and page info. 

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
  
%RecordList{records: []], loaded: false, steps: [:paginate, :base], pagination: %RecordList.Pagination{records_count: _, current_page: _}} = paginated_record_list = MyApp.MyRecordList.paginate(params)
%RecordList{records: records, loaded: true, steps: [:retrieve, :paginate, :base]} = retrieved_record_list = MyApp.MyRecordList.retrieve(paginated_record_list)
# Or
%RecordList{records: records, loaded: true, steps: [:retrieve, :paginate, :base]} = retrieved_record_list = MyApp.MyRecordList.retrieve(params)
```

In both these cases the base step is implemented in the module where we use RecordList. A different implementation can also be passed. This way different record lists can use the same base query. The same goes for other steps. Options for a step are passed into the corresponding `execute/3` callback which allows configuring of custom implementations. 
