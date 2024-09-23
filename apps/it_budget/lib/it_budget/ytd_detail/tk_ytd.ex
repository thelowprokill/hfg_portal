defmodule ItBudget.YtdDetail.TkYtd do
  use Ecto.Schema

  prefix = "turnkey"
  #prefix = case Application.compile_env(:it_budget, :env) do
  #  :dev   -> prefix <> "_dev"
  #  :test  -> prefix <> "_test"
  #  :trial -> prefix <> "_trial"
  #  _      -> prefix
  #end
  
  @primary_key false

  @schema_prefix prefix

  schema "ytdglt" do
    field :gl_account,       :integer
    field :trx_amount,       :decimal
    field :trx_date,         :date
    field :reference,        :string
    field :detail_reference, :string
  end
end



