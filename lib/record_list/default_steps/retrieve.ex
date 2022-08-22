defmodule RecordList.Retrieve do
  @moduledoc """
  A default implementation to retrieve records from the module passed in as `:repo`. This is build with an implementation of Ecto.Repo in mind.
  The returned record list has the results assigns to the :records attribute and sets the `loaded` attribute to true.

  Configuration:
    :repo - a module that implements `all/1` and returns the results from the query received as the only argument. A module that uses Ecto.Repo will work.
  """

  @behaviour RecordList.StepBehaviour

  @impl true
  def execute(%RecordList{query: query} = record_list, :retrieve, opts \\ []) do
    repo = Keyword.fetch!(opts, :repo)
    records = repo.all(query)
    %{record_list | records: records, loaded: true}
  end

end
