defmodule AcheBusaoBackofficeWeb.ChangesetJSON do
  # credo:disable-for-this-file
  defp traverse_errors(changeset) do
    # When encoded, the changeset returns its errors
    # as a JSON object. So we just pass it forward.
    %{errors: Ecto.Changeset.traverse_errors(changeset, &(&1))}
  end

  def render("error.json", %{changeset: changeset}) do
    # When the changeset has been actioned, we can
    # show the errors.
    traverse_errors(changeset)
  end
end
