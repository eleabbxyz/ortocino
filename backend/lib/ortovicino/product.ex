defmodule Ortovicino.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    belongs_to :owner, Ortovicino.User
    field :name, :string
    field :description, :string
    field :category, :string
    field :exchange, :string
    field :price, :string
    field :seller, :string
    field :seller_type, :string
    field :latitude, :float
    field :longitude, :float
    timestamps(type: :utc_datetime)
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, [:owner_id, :name, :description, :category, :exchange, :price, :seller, :seller_type, :latitude, :longitude])
    |> validate_required([:name, :category, :exchange, :seller, :seller_type, :latitude, :longitude])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:seller, min: 2, max: 80)
    |> validate_length(:description, max: 1000)
    |> validate_inclusion(:category, ["Verdura", "Frutta", "Uova", "Miele", "Altro"])
    |> validate_inclusion(:exchange, ["Vendo", "Regalo", "Baratto"])
    |> validate_inclusion(:seller_type, ["privato", "professionista"])
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
  end
end
