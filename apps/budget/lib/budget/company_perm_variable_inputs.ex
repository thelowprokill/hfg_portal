defmodule Budget.CompanyPermVariableInputs do
  alias Budget.Companies.VariableInput

  def list(_ \\ %{}) do
    [
      %VariableInput{id: -1, name: "Head Days", active: true},
      %VariableInput{id: -2, name: "Tons Fed",  active: true}
    ]
  end
end
