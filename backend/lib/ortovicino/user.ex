defmodule Ortovicino.User do
  use Ecto.Schema
  import Ecto.Changeset
  schema "users" do
    field :name, :string
    field :email, :string
    field :password_hash, :string
    field :verified_at, :utc_datetime
    field :suspended_at, :utc_datetime
    field :kind, :string, default: "privato"
    timestamps(type: :utc_datetime)
  end
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :kind])
    |> validate_required([:name, :email, :kind])
    |> validate_length(:name, min: 2, max: 70)
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    |> validate_length(:email, max: 200)
    |> validate_inclusion(:kind, ["privato", "professionista"])
    |> unique_constraint(:email)
  end
end
