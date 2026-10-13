defmodule Ortovicino.Session do
  use Ecto.Schema
  import Ecto.Changeset
  schema "sessions" do
    field :token_hash, :binary
    field :csrf_hash, :binary
    field :expires_at, :utc_datetime
    belongs_to :user, Ortovicino.User
    timestamps(type: :utc_datetime, updated_at: false)
  end
  def changeset(s, attrs) do
    s |> cast(attrs, [:token_hash, :csrf_hash, :expires_at, :user_id])
      |> validate_required([:token_hash, :csrf_hash, :expires_at, :user_id])
      |> unique_constraint(:token_hash)
  end
end
