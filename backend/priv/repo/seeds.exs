alias Ortovicino.{Repo, Product, User, Auth}
# Public demo listings have no owner and cannot receive private messages/reviews.
if Repo.aggregate(Product, :count) == 0 do
  for item <- [
    %{name: "Pomodori freschi", category: "Verdura", exchange: "Vendo", price: "2,50 € / kg", seller: "Azienda demo", seller_type: "professionista", latitude: 43.9301, longitude: 11.0378},
    %{name: "Zucchine in regalo", category: "Verdura", exchange: "Regalo", price: "Gratis", seller: "Orto demo", seller_type: "privato", latitude: 43.93, longitude: 11.04}
  ] do
    %Product{} |> Product.changeset(Map.put(item, :owner_id, nil)) |> Repo.insert!()
  end
end
IO.puts("Dati demo inseriti. Crea due account e pubblica un annuncio per testare la chat privata.")
