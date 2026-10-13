defmodule Ortovicino.Report do
  use Ecto.Schema
  import Ecto.Changeset
  schema "reports" do
    field :kind, :string
    field :target_id, :integer
    field :reason, :string
    field :status, :string, default: "aperta"
    belongs_to :reporter, Ortovicino.User
    timestamps(type: :utc_datetime)
  end
  def changeset(r, attrs) do
    r |> cast(attrs, [:reporter_id, :kind, :target_id, :reason, :status])
      |> validate_required([:reporter_id, :kind, :target_id, :reason])
      |> validate_inclusion(:kind, ["annuncio", "recensione", "messaggio"])
      |> validate_length(:reason, min: 10, max: 500)
      |> validate_inclusion(:status, ["aperta", "chiusa"])
  end
end
