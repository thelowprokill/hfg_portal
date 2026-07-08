defmodule TaskAutomationController.Jobs.Statuses do
  defstruct name: "", id: ""


  def list(_opts \\ %{}) do
    [
      %__MODULE__{name: "Unassigned", id: "unassigned"},
      %__MODULE__{name: "Waiting",    id: "waiting"},
      %__MODULE__{name: "Running",    id: "running"},
      %__MODULE__{name: "Completed",  id: "completed"},
      %__MODULE__{name: "Failed",     id: "failed"},
    ]
  end

  def get(name) do
    Enum.find(list(), Enum.find(list(), &(&1.name == "None")), &(&1.name == name))
  end
end
