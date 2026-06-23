defmodule LoanRepayment.Users.Roles do
  defstruct name: "", admin: false, edit: false, view: false


  def list(_opts \\ %{}) do
    [
      %__MODULE__{name: "None" , admin: false, edit: false, view: false},
      %__MODULE__{name: "View" , admin: false, edit: false, view: true },
      %__MODULE__{name: "Edit" , admin: false, edit: true , view: true },
      %__MODULE__{name: "Admin", admin: true , edit: true , view: true },
    ]
  end

  def get(name) do
    Enum.find(list(), Enum.find(list(), &(&1.name == "None")), &(&1.name == name))
  end
end
