defmodule OrtovicinoWeb.Router do
  use Plug.Router
  import Ecto.Query
  alias Ortovicino.{Repo, User, Session, Product, Conversation, Message, Review, Auth, AccountSecurity, Report}

  plug Plug.Logger
  plug :match
  plug Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason
  plug :security_headers
  plug :dispatch

  get "/api/health" do
    json(conn, 200, %{ok: true})
  end

  post "/api/register" do
    with :ok <- throttle(conn, "register", 8), {:ok, user} <- Auth.register(conn.body_params) do
      case AccountSecurity.issue(user, "verify") do
        :ok -> json(conn, 201, %{ok: true, message: "Controlla la tua email per attivare l’account"})
        _ -> json(conn, 503, %{error: "Invio email non disponibile. Contatta l’amministratore."})
      end
    else
      {:error, reason} -> json(conn, 422, %{error: reason})
    end
  end

  post "/api/verify-email" do
    case AccountSecurity.verify(conn.body_params["token"]) do
      :ok -> json(conn, 200, %{ok: true})
      {:error, reason} -> json(conn, 422, %{error: reason})
    end
  end

  post "/api/forgot-password" do
    with :ok <- throttle(conn, "forgot", 5) do
      email = conn.body_params["email"]
      if is_binary(email) do
        case Repo.get_by(User, email: String.downcase(String.trim(email))) do
          nil -> :ok
          user -> AccountSecurity.issue(user, "reset")
        end
      end
      json(conn, 200, %{message: "Se l’indirizzo è registrato riceverai un’email."})
    else
      _ -> json(conn, 429, %{error: "Riprova più tardi"})
    end
  end

  post "/api/reset-password" do
    case AccountSecurity.reset(conn.body_params["token"], conn.body_params["password"]) do
      :ok -> json(conn, 200, %{ok: true, message: "Password aggiornata. Accedi di nuovo."})
      {:error, reason} -> json(conn, 422, %{error: reason})
    end
  end

  post "/api/login" do
    with :ok <- throttle(conn, "login", 10), {:ok, user} <- Auth.login(conn.body_params) do
      {token, csrf} = Auth.create_session(user)
      conn |> Auth.cookie(token) |> json(200, %{user: Auth.public_user(user), csrf: csrf})
    else
      {:error, reason} -> json(conn, 401, %{error: reason})
    end
  end

  get "/api/me" do
    case Auth.find_session(conn) do
      {session, user} ->
        csrf = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
        Repo.update!(Ecto.Changeset.change(session, csrf_hash: Auth.hash(csrf)))
        json(conn, 200, %{user: Auth.public_user(user), csrf: csrf})
      _ -> json(conn, 401, %{error: "Accedi per continuare"})
    end
  end

  post "/api/logout" do
    with {:ok, conn, {session, _}} <- protected(conn) do
      Repo.delete!(session)
      conn |> Plug.Conn.delete_resp_cookie("ov_session", path: "/api") |> json(200, %{ok: true})
    else
      {:error, conn, status, reason} -> json(conn, status, %{error: reason})
    end
  end

  get "/api/products" do
    products = Repo.all(from p in Product, order_by: [desc: p.inserted_at])
    json(conn, 200, Enum.map(products, &product_json/1))
  end

  post "/api/products" do
    with {:ok, conn, {_s, user}} <- protected(conn) do
      # IMPORTANT: identity comes from session, not user-submitted seller fields.
      # Private listing coordinates are rounded server-side, never publish exact GPS.
      attrs = Map.take(conn.body_params, ["name", "description", "category", "exchange", "price", "latitude", "longitude"])
      lat = number(attrs["latitude"], 43.9304)
      lon = number(attrs["longitude"], 11.0402)
      {lat, lon} = if user.kind == "privato", do: {Float.round(lat, 2), Float.round(lon, 2)}, else: {lat, lon}
      attrs = attrs |> Map.put("owner_id", user.id) |> Map.put("seller", user.name)
        |> Map.put("seller_type", user.kind) |> Map.put("latitude", lat) |> Map.put("longitude", lon)
      case %Product{} |> Product.changeset(attrs) |> Repo.insert() do
        {:ok, product} -> json(conn, 201, product_json(product))
        {:error, changeset} -> invalid(conn, changeset)
      end
    else
      {:error, conn, status, reason} -> json(conn, status, %{error: reason})
    end
  end

  get "/api/products/:id/reviews" do
    with {:ok, product} <- find_product(id) do
      list = Repo.all(from r in Review, join: u in User, on: r.author_id == u.id,
        where: r.product_id == ^product.id, order_by: [desc: r.id],
        select: %{id: r.id, author: u.name, rating: r.rating, body: r.body, inserted_at: r.inserted_at})
      json(conn, 200, list)
    else
      _ -> json(conn, 404, %{error: "Annuncio non trovato"})
    end
  end

  post "/api/products/:id/reviews" do
    with {:ok, conn, {_s, user}} <- protected(conn), {:ok, product} <- find_product(id),
         true <- product.owner_id != nil and product.owner_id != user.id do
      attrs = %{product_id: product.id, author_id: user.id, rating: conn.body_params["rating"], body: conn.body_params["body"]}
      case %Review{} |> Review.changeset(attrs) |> Repo.insert() do
        {:ok, review} -> json(conn, 201, %{id: review.id, author: user.name, rating: review.rating, body: review.body, inserted_at: review.inserted_at})
        {:error, _} -> json(conn, 422, %{error: "Recensione non valida o già inviata per questo annuncio"})
      end
    else
      {:error, conn, status, reason} -> json(conn, status, %{error: reason})
      _ -> json(conn, 403, %{error: "Non puoi recensire questo annuncio"})
    end
  end

  post "/api/products/:id/conversations" do
    with {:ok, conn, {_s, user}} <- protected(conn), {:ok, product} <- find_product(id),
         true <- product.owner_id != nil and product.owner_id != user.id do
      conversation = case Repo.get_by(Conversation, product_id: product.id, buyer_id: user.id) do
        nil -> case %Conversation{} |> Conversation.changeset(%{product_id: product.id, buyer_id: user.id}) |> Repo.insert() do
          {:ok, c} -> c
          _ -> Repo.get_by!(Conversation, product_id: product.id, buyer_id: user.id)
        end
        c -> c
      end
      json(conn, 200, conversation_json(conversation, product))
    else
      {:error, conn, status, reason} -> json(conn, status, %{error: reason})
      _ -> json(conn, 403, %{error: "Impossibile contattare questo venditore"})
    end
  end

  get "/api/conversations" do
    with {:ok, conn, {_s, user}} <- authenticated(conn) do
      list = Repo.all(from c in Conversation, join: p in Product, on: p.id == c.product_id,
        where: c.buyer_id == ^user.id or p.owner_id == ^user.id, order_by: [desc: c.updated_at],
        select: {c, p})
      json(conn, 200, Enum.map(list, fn {c, p} -> conversation_json(c, p) end))
    else
      {:error, conn, status, reason} -> json(conn, status, %{error: reason})
    end
  end

  get "/api/conversations/:id/messages" do
    with {:ok, conn, {_s, user}} <- authenticated(conn), {:ok, c, _p} <- authorized_conversation(id, user) do
      messages = Repo.all(from m in Message, where: m.conversation_id == ^c.id, order_by: [asc: m.id])
      json(conn, 200, Enum.map(messages, &message_json/1))
    else
      {:error, conn, status, reason} -> json(conn, status, %{error: reason})
      _ -> json(conn, 404, %{error: "Conversazione non disponibile"})
    end
  end

  post "/api/conversations/:id/messages" do
    with {:ok, conn, {_s, user}} <- protected(conn), {:ok, conversation, _p} <- authorized_conversation(id, user),
         :ok <- throttle(conn, "message:#{user.id}", 60) do
      case %Message{} |> Message.changeset(%{conversation_id: conversation.id, sender_id: user.id, body: conn.body_params["body"]}) |> Repo.insert() do
        {:ok, message} ->
          Registry.dispatch(Ortovicino.ChatRegistry, conversation.id, fn entries ->
            for {pid, _} <- entries, do: send(pid, {:message, message_json(message)})
          end)
          json(conn, 201, message_json(message))
        {:error, _} -> json(conn, 422, %{error: "Scrivi un messaggio valido (massimo 1000 caratteri)"})
      end
    else
      {:error, conn, status, reason} -> json(conn, status, %{error: reason})
      _ -> json(conn, 404, %{error: "Conversazione non disponibile"})
    end
  end

  # SSE: un canale aperto per ricevere i nuovi messaggi immediatamente.
  # EventSource usa il cookie HttpOnly; SOLO un partecipante può collegarsi.
  get "/api/conversations/:id/events" do
    with {:ok, conn, {_s, user}} <- authenticated(conn), {:ok, c, _p} <- authorized_conversation(id, user) do
      {:ok, conn} = conn |> Plug.Conn.put_resp_header("cache-control", "no-store")
        |> Plug.Conn.put_resp_header("x-accel-buffering", "no")
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_chunked(200)
      {:ok, _} = Registry.register(Ortovicino.ChatRegistry, c.id, true)
      {:ok, conn} = Plug.Conn.chunk(conn, ": connesso\n\n")
      stream(conn, 0)
    else
      {:error, conn, status, reason} -> json(conn, status, %{error: reason})
      _ -> json(conn, 404, %{error: "Conversazione non disponibile"})
    end
  end

  post "/api/reports" do
    with {:ok, conn, {_s, user}} <- protected(conn), :ok <- throttle(conn, "report:#{user.id}", 10) do
      attrs = Map.take(conn.body_params, ["kind", "target_id", "reason"]) |> Map.put("reporter_id", user.id)
      target = attrs["target_id"]
      valid = is_integer(target) and target > 0 and case attrs["kind"] do
        "annuncio" -> Repo.get(Product, target) != nil
        "recensione" -> Repo.get(Review, target) != nil
        "messaggio" -> case Repo.get(Message, target) do
          nil -> false
          m -> match?({:ok, _, _}, authorized_conversation(to_string(m.conversation_id), user))
        end
        _ -> false
      end
      if valid do
        case %Report{} |> Report.changeset(attrs) |> Repo.insert() do
          {:ok, _} -> json(conn, 201, %{ok: true, message: "Segnalazione inviata"})
          _ -> json(conn, 422, %{error: "Segnalazione non valida"})
        end
      else
        json(conn, 404, %{error: "Contenuto non disponibile"})
      end
    else
      {:error, conn, status, reason} -> json(conn, status, %{error: reason})
    end
  end

  get "/api/admin/reports" do
    with {:ok, conn, {_s, user}} <- authenticated(conn), true <- admin?(user) do
      reports = Repo.all(from r in Report, order_by: [desc: r.inserted_at], limit: 100)
      json(conn, 200, Enum.map(reports, &Map.take(&1, [:id, :kind, :target_id, :reason, :status, :inserted_at])))
    else
      _ -> json(conn, 403, %{error: "Accesso negato"})
    end
  end

  post "/api/admin/reports/:id/close" do
    with {:ok, conn, {_s, user}} <- protected(conn), true <- admin?(user), {n, ""} <- Integer.parse(id), %Report{} = report <- Repo.get(Report, n) do
      Repo.update!(Ecto.Changeset.change(report, status: "chiusa"))
      json(conn, 200, %{ok: true})
    else
      _ -> json(conn, 403, %{error: "Accesso negato o segnalazione non trovata"})
    end
  end

  post "/api/admin/users/:id/suspend" do
    with {:ok, conn, {_s, user}} <- protected(conn), true <- admin?(user), {n, ""} <- Integer.parse(id), %User{} = target <- Repo.get(User, n), true <- target.id != user.id do
      Repo.update!(Ecto.Changeset.change(target, suspended_at: DateTime.utc_now() |> DateTime.truncate(:second)))
      Repo.delete_all(from sess in Session, where: sess.user_id == ^target.id)
      json(conn, 200, %{ok: true})
    else
      _ -> json(conn, 403, %{error: "Operazione non autorizzata"})
    end
  end

  match _ do
    json(conn, 404, %{error: "Endpoint non trovato"})
  end

  defp stream(conn, n) when n < 360 do
    receive do
      {:message, data} ->
        case Plug.Conn.chunk(conn, "event: message\ndata: #{Jason.encode!(data)}\n\n") do
          {:ok, conn} -> stream(conn, n + 1)
          _ -> conn
        end
    after
      20_000 ->
        case Plug.Conn.chunk(conn, ": ping\n\n") do
          {:ok, conn} -> stream(conn, n + 1)
          _ -> conn
        end
    end
  end
  defp stream(conn, _), do: conn

  defp admin?(user) do
    admin_email = System.get_env("ADMIN_EMAIL", "") |> String.downcase()
    admin_email != "" and user.email == admin_email and user.verified_at != nil
  end
  defp security_headers(conn, _) do
    conn
    |> Plug.Conn.put_resp_header("x-content-type-options", "nosniff")
    |> Plug.Conn.put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> Plug.Conn.put_resp_header("x-frame-options", "DENY")
    |> Plug.Conn.put_resp_header("permissions-policy", "camera=(), microphone=(), geolocation=(self)")
    |> Plug.Conn.put_resp_header("content-security-policy", "default-src 'none'; frame-ancestors 'none'")
  end
  defp authenticated(conn) do
    case Auth.find_session(conn) do
      nil -> {:error, conn, 401, "Accedi per continuare"}
      pair -> {:ok, conn, pair}
    end
  end
  defp protected(conn) do
    with {:ok, conn, pair} <- authenticated(conn), true <- Auth.check_csrf(conn, pair) do
      {:ok, conn, pair}
    else
      false -> {:error, conn, 403, "Token di sicurezza non valido: aggiorna la pagina"}
      error -> error
    end
  end
  defp find_product(id) do
    with {n, ""} when n > 0 <- Integer.parse(id), %Product{} = p <- Repo.get(Product, n) do
      {:ok, p}
    else
      _ -> {:error, :not_found}
    end
  end
  defp authorized_conversation(id, user) do
    with {n, ""} when n > 0 <- Integer.parse(id), %Conversation{} = c <- Repo.get(Conversation, n),
         %Product{} = p <- Repo.get(Product, c.product_id),
         true <- c.buyer_id == user.id or p.owner_id == user.id do
      {:ok, c, p}
    else
      _ -> {:error, :not_found}
    end
  end
  defp throttle(conn, key, limit) do
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    bucket = div(System.system_time(:second), 900)
    k = {ip, key, bucket}
    table = :ortovicino_rate_limit
    count = :ets.update_counter(table, k, {2, 1}, {k, 0})
    if count <= limit, do: :ok, else: {:error, "Troppe richieste: riprova più tardi"}
  end
  defp number(value, _default) when is_number(value), do: value / 1
  defp number(_value, default), do: default
  defp json(conn, status, data), do: conn |> Plug.Conn.put_resp_header("cache-control", "no-store") |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(status, Jason.encode!(data))
  defp invalid(conn, _cs), do: json(conn, 422, %{error: "Controlla i dati dell'annuncio"})
  defp product_json(p) do
    # Defense in depth: legacy private listings are also rounded before leaving the API.
    p = if p.seller_type == "privato", do: %{p | latitude: Float.round(p.latitude, 2), longitude: Float.round(p.longitude, 2)}, else: p
    Map.take(p, [:id, :owner_id, :name, :description, :category, :exchange, :price, :seller, :seller_type, :latitude, :longitude, :inserted_at])
  end
  defp conversation_json(c, p), do: %{id: c.id, product_id: p.id, product_name: p.name, seller: p.seller, seller_id: p.owner_id, buyer_id: c.buyer_id}
  defp message_json(m), do: %{id: m.id, conversation_id: m.conversation_id, sender_id: m.sender_id, body: m.body, inserted_at: m.inserted_at}
end
