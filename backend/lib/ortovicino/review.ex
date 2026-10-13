defmodule Ortovicino.Review do
  use Ecto.Schema
  import Ecto.Changeset
  schema "reviews" do
    field :body, :string
    field :rating, :integer
    belongs_to :product, Ortovicino.Product
    belongs_to :author, Ortovicino.User
    timestamps(type: :utc_datetime)
  end
  def changeset(r, attrs) do
    r |> cast(attrs, [:product_id, :author_id, :body, :rating])
      |> validate_required([:product_id, :author_id, :body, :rating])
      |> validate_length(:body, min: 2, max: 500)
      |> validate_number(:rating, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
      |> unique_constraint([:product_id, :author_id])
  end
end
