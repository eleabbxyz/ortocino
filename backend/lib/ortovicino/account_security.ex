defmodule Ortovicino.AccountSecurity do
  import Ecto.Query
  alias Ortovicino.{Repo, User, Session, EmailToken, Auth, Mailer}
  @base_env "PUBLIC_URL"
  def issue(user, purpose) when purpose in ["verify", "reset"] do
    raw = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    ttl = if purpose == "verify", do: 86_400, else: 1_800
    expires = DateTime.utc_now() |> DateTime.add(ttl, :second) |> DateTime.truncate(:second)
    Repo.insert!(EmailToken.changeset(%EmailToken{}, %{user_id: user.id, purpose: purpose, token_hash: Auth.hash(raw), expires_at: expires}))
    base = System.get_env(@base_env, "http://localhost:5173") |> String.trim_trailing("/")
    link = "#{base}/?#{if purpose == "verify", do: "verify", else: "reset"}=#{raw}"
    Mailer.deliver(user.email, if(purpose == "verify", do: "Conferma la tua email", else: "Recupera la password"), link)
  end
  def consume(raw, purpose) when is_binary(raw) and byte_size(raw) <= 256 do
    now = DateTime.utc_now()
    case Repo.one(from t in EmailToken, where: t.token_hash == ^Auth.hash(raw) and t.purpose == ^purpose and t.expires_at > ^now) do
      nil -> {:error, "Collegamento non valido o scaduto"}
      token -> {:ok, token}
    end
  end
  def consume(_, _), do: {:error, "Collegamento non valido"}
  def verify(raw) do
    with {:ok, t} <- consume(raw, "verify") do
      Repo.transaction(fn ->
        Repo.update!(Ecto.Changeset.change(Repo.get!(User, t.user_id), verified_at: DateTime.utc_now() |> DateTime.truncate(:second)))
        Repo.delete!(t)
      end)
      :ok
    end
  end
  def reset(raw, password) when is_binary(password) and byte_size(password) >= 12 and byte_size(password) <= 128 do
    with {:ok, t} <- consume(raw, "reset") do
      Repo.transaction(fn ->
        user = Repo.get!(User, t.user_id)
        Repo.update!(Ecto.Changeset.change(user, password_hash: Bcrypt.hash_pwd_salt(password)))
        Repo.delete_all(from s in Session, where: s.user_id == ^user.id)
        Repo.delete_all(from k in EmailToken, where: k.user_id == ^user.id)
      end)
      :ok
    end
  end
  def reset(_, _), do: {:error, "La password deve avere da 12 a 128 caratteri"}
end
