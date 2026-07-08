defmodule TaskAutomationController.Jobs.Types do
  defstruct name: "", id: ""


  def list(_opts \\ %{}) do
    [
      %__MODULE__{name: "User",      id: "user"},
      %__MODULE__{name: "Scheduled", id: "scheduled"},
    ]
  end

  def get(name) do
    Enum.find(list(), Enum.find(list(), &(&1.name == "None")), &(&1.name == name))
  end
end
