defmodule ChatApp.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :body, :string
    field :username, :string
    field :room, :string
    # Make sure this line exists
    field :attachment_url, :string

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    # Include attachment_url here
    |> cast(attrs, [:body, :username, :room, :attachment_url])
    # body is not required if we have attachments
    |> validate_required([:username, :room])
  end
end
