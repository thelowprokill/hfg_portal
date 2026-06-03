defmodule Budget.ScheduledExpenses.ScheduledExpense do
  use Ecto.Schema
  import Ecto.Changeset

  @frequencies ~w(monthly weekly yearly)
  # 0 = Monday, 6 = Sunday
  @days_of_week 0..6

  schema "scheduled_expenses" do
    field :amount,        :decimal
    field :description,   :string
    field :frequency,     :string
    field :day_of_month,  :integer
    field :day_of_week,   :integer
    field :month_of_year, :integer
    field :next_due_date, :date
    field :active,        :boolean, default: true

    belongs_to :bucket, Budget.Buckets.Bucket

    timestamps()
  end

  def changeset(scheduled_expense, attrs \\ %{}) do
    scheduled_expense
    |> cast(attrs, [
      :bucket_id,
      :amount,
      :description,
      :frequency,
      :day_of_month,
      :day_of_week,
      :month_of_year,
      :next_due_date,
      :active
    ])
    |> validate_required([:bucket_id, :amount, :description, :frequency, :next_due_date])
    |> validate_inclusion(:frequency, @frequencies)
    |> validate_number(:amount, greater_than: Decimal.new(0))
    |> validate_frequency_fields()
  end

  defp validate_frequency_fields(changeset) do
    case get_field(changeset, :frequency) do
      "weekly"  -> validate_weekly(changeset)
      "monthly" -> validate_monthly(changeset)
      "yearly"  -> validate_yearly(changeset)
      _         -> changeset
    end
  end

  defp validate_weekly(changeset) do
    changeset
    |> validate_required([:day_of_week])
    |> validate_inclusion(:day_of_week, @days_of_week)
  end

  defp validate_monthly(changeset) do
    changeset
    |> validate_required([:day_of_month])
    |> validate_number(:day_of_month, greater_than_or_equal_to: 1, less_than_or_equal_to: 28)
  end

  defp validate_yearly(changeset) do
    changeset
    |> validate_required([:day_of_month, :month_of_year])
    |> validate_number(:day_of_month, greater_than_or_equal_to: 1, less_than_or_equal_to: 28)
    |> validate_number(:month_of_year, greater_than_or_equal_to: 1, less_than_or_equal_to: 12)
  end
end
