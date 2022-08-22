defmodule RecordList.StepBehaviour do
  @type step :: atom()
  @type step_opts :: Keyword.t() | nil
  @callback execute(RecordList.t(), step, step_opts) :: RecordList.t()
end
