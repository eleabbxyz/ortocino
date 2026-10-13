defmodule Ortovicino.Conversation do
  use Ecto.Schema
  import Ecto.Changeset
  schema "conversations" do
    belongs_to :product, Ortovicino.Product
    belongs_to :buyer, Ortovicino.User
    timestamps(type: :utc_datetime)
  end
  def changeset(c, attrs) do
    c |> cast(attrs, [:product_id, :buyer_id])
      |> validate_required([:product_id, :buyer_id])
      |> unique_constraint([:product_id, :buyer_id])
  end
end
