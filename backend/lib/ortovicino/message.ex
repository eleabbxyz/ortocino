defmodule Ortovicino.Message do
  use Ecto.Schema
  import Ecto.Changeset
  schema "messages" do
    field :body, :string
    belongs_to :conversation, Ortovicino.Conversation
    belongs_to :sender, Ortovicino.User
    timestamps(type: :utc_datetime, updated_at: false)
  end
  def changeset(m, attrs) do
    m |> cast(attrs, [:conversation_id, :sender_id, :body])
      |> validate_required([:conversation_id, :sender_id, :body])
      |> validate_length(:body, min: 1, max: 1000)
  end
end
