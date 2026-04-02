defmodule App.Release do
  @app :app

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def seed do
    load_app()
    email = "admin@wcore.com"
    pass = "ErlangIsCool"

    {:ok, _, _} =
      Ecto.Migrator.with_repo(App.Repo, fn repo ->
        case repo.get_by(App.Accounts.User, email: email) do
          nil ->
            {:ok, user} =
              App.Accounts.register_user(%{
                email: email
              })

            {:ok, {user, _}} =
              App.Accounts.update_user_password(user, %{
                password: pass
              })

            user
            |> Ecto.Changeset.change(
              confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
            )
            |> repo.update!()

            IO.puts("==> Usuário seed criado: \nemail: #{email}\npassword: #{pass}")

          _ ->
            IO.puts("==> Usuário seed já existe, pulando.")
        end
      end)
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
