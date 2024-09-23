defmodule BnwPortal.Helpers.App do
  defstruct [
    id:         nil,
    name:       nil,
    module:     nil,
    links:      [],
    show_admin: false,
    opts:       %{}
  ]
end
