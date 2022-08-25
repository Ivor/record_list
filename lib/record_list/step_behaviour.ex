defmodule RecordList.StepBehaviour do
  @moduledoc """
  A behaviour to be implemented by the implementation modules of steps defined in the options to the `RecordList.__using__/1` macro.
  """

  @doc """
  The RecordList pipeline will call `execute/3` on the implementation for each step defined.
  The second `step` argument will be the name of the step, e.g. `:sort`, or `:paginate`.

  ```elixir
    def execute(%RecordList{}, :sort, opts) do
      ...
    end
  ```

  This allows the same module to define `execute/3` implementations for various steps.
  """
  @callback execute(RecordList.t(), step :: atom(), step_opts :: Keyword.t()) :: RecordList.t()
end
