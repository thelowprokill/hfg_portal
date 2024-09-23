defmodule BnwPortal.Helpers.Modal do
  defstruct [
    modal:     nil,
    id:        nil,
    module:    nil,
    changeset: nil,
    data:      nil,
    user:      nil,
    live:      false,
    opts:      %{}
  ]
end
