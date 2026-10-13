defmodule Ortovicino.Mailer do
  require Logger
  # Uses Resend REST API in production. Never log tokens in production.
  # Development-only links are printed to local terminal to make testing possible.
  def deliver(email, subject, link) do
    key = System.get_env("RESEND_API_KEY")
    sender = System.get_env("MAIL_FROM")
    if is_binary(key) and key != "" and is_binary(sender) and sender != "" do
      :inets.start()
      :ssl.start()
      payload = Jason.encode!(%{from: sender, to: [email], subject: subject,
        text: "OrtoVicino\n\nApri questo collegamento (scade presto):\n#{link}\n\nSe non hai richiesto questa operazione, ignora questa email."})
      headers = [{'authorization', 'Bearer ' ++ String.to_charlist(key)}, {'content-type', 'application/json'}]
      case :httpc.request(:post, {'https://api.resend.com/emails', headers, 'application/json', String.to_charlist(payload)}, [{:timeout, 8_000}], []) do
        {:ok, {{_, status, _}, _, _}} when status in 200..299 -> :ok
        other -> Logger.error("Invio email fallito: #{inspect(other, limit: 2)}"); {:error, :email}
      end
    else
      if System.get_env("DEV_EMAIL_LINKS") == "true" and System.get_env("MIX_ENV", "dev") != "prod" do
        Logger.warning("SOLO SVILUPPO - email per #{email}: #{link}")
        :ok
      else
        {:error, :email_not_configured}
      end
    end
  end
end
