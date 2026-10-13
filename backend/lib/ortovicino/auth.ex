defmodule Ortovicino.Auth do
  import Ecto.Query
  alias Ortovicino.{Repo, User, Session}
  @ttl 60 * 60 * 24 * 7
  def hash(value), do: :crypto.hash(:sha256, value)
  def register(params) do
    email = String.downcase(String.trim(to_string(params["email"] || "")))
    password = params["password"] || ""
    cond do
      not is_binary(password) or byte_size(password) < 12 or byte_size(password) > 128 -> {:error, "La password deve avere da 12 a 128 caratteri"}
      true ->
        cs = User.changeset(%User{}, %{"email" => email, "name" => params["name"], "kind" => params["kind"] || "privato"})
        cs = Ecto.Changeset.put_change(cs, :password_hash, Bcrypt.hash_pwd_salt(password))
        case Repo.insert(cs) do
          {:ok, user} -> {:ok, user}
          _ -> {:error, "Dati non validi o email già utilizzata"}
        end
    end
  end
  def login(params) do
    email = String.downcase(String.trim(to_string(params["email"] || "")))
    user = Repo.get_by(User, email: email)
    password = params["password"]
    valid = if is_binary(password) do
      if user, do: Bcrypt.verify_pass(password, user.password_hash), else: Bcrypt.no_user_verify()
    else
      false
    end
    cond do
      not valid -> {:error, "Email o password non corretti"}
      user.suspended_at != nil -> {:error, "Account sospeso: contatta il supporto"}
      user.verified_at == nil -> {:error, "Conferma la tua email prima di accedere"}
      true -> {:ok, user}
    end
  end
  def create_session(user) do
    token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    csrf = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    exp = DateTime.add(DateTime.utc_now(), @ttl, :second) |> DateTime.truncate(:second)
    %Session{} |> Session.changeset(%{user_id: user.id, token_hash: hash(token), csrf_hash: hash(csrf), expires_at: exp}) |> Repo.insert!()
    {token, csrf}
  end
  def find_session(conn) do
    conn = Plug.Conn.fetch_cookies(conn)
    case conn.req_cookies["ov_session"] do
      nil -> nil
      token ->
        now = DateTime.utc_now()
        case Repo.one(from s in Session, join: u in User, on: s.user_id == u.id,
          where: s.token_hash == ^hash(token) and s.expires_at > ^now,
          where: not is_nil(u.verified_at) and is_nil(u.suspended_at),
          select: {s, u}) do
          nil -> nil
          pair -> pair
        end
    end
  end
  def check_csrf(conn, {_session, _user} = pair) do
    {session, _} = pair
    case Plug.Conn.get_req_header(conn, "x-csrf-token") do
      [value] when is_binary(value) -> :crypto.hash_equals(session.csrf_hash, hash(value))
      _ -> false
    end
  end
  def csrf_for(_session), do: nil
  def cookie(conn, token) do
    Plug.Conn.put_resp_cookie(conn, "ov_session", token,
      http_only: true, same_site: "Lax", secure: System.get_env("COOKIE_SECURE", "false") == "true",
      path: "/api", max_age: @ttl)
  end
  def public_user(user), do: Map.take(user, [:id, :name, :kind])
end
