defmodule AcheBusaoBackofficeWeb.FallbackController do
  use AcheBusaoBackofficeWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: AcheBusaoBackofficeWeb.ChangesetJSON)
    |> render("error.json", changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(html: AcheBusaoBackofficeWeb.ErrorHTML, json: AcheBusaoBackofficeWeb.ErrorJSON)
    |> render(:"404")
  end
end
