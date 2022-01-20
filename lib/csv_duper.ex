defmodule CsvDuper do
  @moduledoc """
  Documentation for `CsvDuper`.
  """

  NimbleCSV.define(CsvParser, [])

  @doc """
  Removes duplicate rows from csv file if duplicates exist in columns passed.
  If column passed does not exist, error will be returned.
  """
  @spec remove_duplicates(
          Path.t(),
          [String.t()],
          (Path.t() -> [String.t()] | no_return()),
          (Path.t(), [String.t()] -> :ok | {:error, any()})
        ) :: :ok | {:error, any()}
  def remove_duplicates(
        csv_path,
        columns_to_check,
        file_reader \\ &read_file_to_list/1,
        write_file \\ &File.write/2
      ) do
    with {:ok, {header, rows}} <- parse_csv(csv_path, file_reader),
         {:ok, remaining_rows} <- remove_duplicates_for_columns(columns_to_check, rows) do
      csv_rows = rows_to_csv_string(remaining_rows, header)
      write_file.(csv_path, _csv_body = [list_to_csv_string(header) | csv_rows])
    else
      {_, reason} ->
        {:error, reason}
    end
  end

  defp parse_csv(csv_path, file_reader) do
    case file_reader.(csv_path) do
      [] ->
        {:error, "Empty CSV File."}

      [_head | []] ->
        {:error, "Only header in CSV File."}

      rows ->
        {:ok,
         rows
         |> CsvParser.parse_enumerable(skip_headers: false)
         |> csv_rows_to_map()}
    end
  end

  defp read_file_to_list(path) do
    path
    |> File.stream!()
    |> Enum.to_list()
  end

  defp csv_rows_to_map([]) do
    raise "Empty CSV file."
  end

  defp csv_rows_to_map([header | rows]) do
    mapped_rows =
      rows
      |> Enum.map(&Enum.zip(header, &1))
      |> Enum.map(&Map.new(&1))

    {header, mapped_rows}
  end

  defp rows_to_csv_string(rows, header) do
    Enum.map(rows, fn row ->
      for column <- header do
        row[column]
      end
      |> list_to_csv_string()
    end)
  end

  defp list_to_csv_string(list) do
    csv_string = Enum.join(list, ",")
    csv_string <> "\n"
  end

  defp remove_duplicates_for_columns(columns_to_check, rows) do
    Enum.reduce(columns_to_check, {:ok, rows}, &remove_duplicates_column/2)
  end

  defp remove_duplicates_column(column, {:ok, [head | _tail] = _rows})
       when not is_map_key(head, column) do
    {:halt, "Column does not exist in CSV."}
  end

  defp remove_duplicates_column(column, {:ok, rows}) do
    {:ok, do_remove_duplicates_column(column, rows, [], MapSet.new())}
  end

  defp do_remove_duplicates_column(_column, [], rows_to_keep, _duplicates),
    do: Enum.reverse(rows_to_keep)

  defp do_remove_duplicates_column(
         column,
         [row | tail] = _remaining_rows,
         rows_to_keep,
         duplicates
       ) do
    {new_rows_to_keep, new_duplicates} =
      if MapSet.member?(duplicates, row[column]) do
        {rows_to_keep, duplicates}
      else
        {[row | rows_to_keep], MapSet.put(duplicates, row[column])}
      end

    do_remove_duplicates_column(column, tail, new_rows_to_keep, new_duplicates)
  end
end
