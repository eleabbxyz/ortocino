defmodule Ortovicino.EmailToken do
  use Ecto.Schema
  import Ecto.Changeset
  schema "email_tokens" do
    field :token_hash, :binary
    field :purpose, :string
    field :expires_at, :utc_datetime
    belongs_to :user, Ortovicino.User
    timestamps(type: :utc_datetime, updated_at: false)
  end
  def changeset(t, attrs) do
    t |> cast(attrs, [:user_id, :token_hash, :purpose, :expires_at])
      |> validate_required([:user_id, :token_hash, :purpose, :expires_at])
  end
end
