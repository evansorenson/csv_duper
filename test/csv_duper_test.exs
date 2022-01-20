defmodule CsvDuperTest do
  use ExUnit.Case
  doctest CsvDuper

  @header "FirstName,LastName,Phone,Email\n"
  @csv_input_path "./test/helpers/input.csv"
  @csv_output_path "./test/helpers/output.csv"

  defp mock_reader(csv_rows), do: csv_rows
  defp mock_writer(_path, csv_rows), do: csv_rows

  defp actual_file_reader(path) do
    csv_rows =
      path
      |> Path.expand()
      |> File.stream!()
      |> Enum.to_list()

    csv_rows
  end

  defp actual_file_writer(_path, body) do
    File.rm(@csv_output_path)
    File.write!(@csv_output_path, body)
  end

  test "reading and writing csv to file system" do
    :ok =
      CsvDuper.remove_duplicates(
        @csv_input_path,
        ["Phone", "Email"],
        &actual_file_reader/1,
        &actual_file_writer/2
      )

    assert File.exists?(@csv_output_path)

    assert File.stream!(@csv_output_path) |> Enum.to_list() == [
             @header,
             "Jane,Doe,123-344-3473,something@blank.com\n",
             "Jane,Doe,000-000-0000,unique@blank.com\n"
           ]
  end

  test "empty file" do
    assert {:error, "Empty CSV File."} ==
             CsvDuper.remove_duplicates([], ["Phone"], &mock_reader/1, &mock_writer/2)
  end

  test "only header row" do
    assert {:error, "Only header in CSV File."} ==
             CsvDuper.remove_duplicates([@header], ["Phone"], &mock_reader/1, &mock_writer/2)
  end

  test "column passed does not exist in file" do
    assert {:error, "Column does not exist in CSV."} ==
             CsvDuper.remove_duplicates(
               [
                 @header,
                 "Jane,Doe,818-848-3884,something@blank.com\n"
               ],
               ["Nope"],
               &mock_reader/1,
               &mock_writer/2
             )
  end

  test "one row" do
    new_csv =
      CsvDuper.remove_duplicates(
        [
          @header,
          "Jane,Doe,818-848-3884,something@blank.com\n"
        ],
        ["Phone"],
        &mock_reader/1,
        &mock_writer/2
      )

    assert new_csv == [
             @header,
             "Jane,Doe,818-848-3884,something@blank.com\n"
           ]
  end

  test "handles missing values" do
    new_csv =
      CsvDuper.remove_duplicates(
        [
          @header,
          "Jane,Doe,818-848-3884,something@blank.com\n",
          ",,,",
          ",,,"
        ],
        ["Phone"],
        &mock_reader/1,
        &mock_writer/2
      )

    assert new_csv == [
             @header,
             "Jane,Doe,818-848-3884,something@blank.com\n",
             ",,,\n"
           ]
  end

  test "phone duplicate removed" do
    new_csv =
      CsvDuper.remove_duplicates(
        [
          @header,
          "Jane,Doe,818-848-3884,something@blank.com\n",
          "Jim,Smith,123-456-7890,something@blank.com\n",
          "Jane,Doe,818-848-3884,something@blank.com\n"
        ],
        ["Phone"],
        &mock_reader/1,
        &mock_writer/2
      )

    assert new_csv == [
             @header,
             "Jane,Doe,818-848-3884,something@blank.com\n",
             "Jim,Smith,123-456-7890,something@blank.com\n"
           ]
  end

  test "email duplicates removed" do
    new_csv =
      CsvDuper.remove_duplicates(
        [
          @header,
          "Jane,Doe,123-344-3473,something@blank.com\n",
          "Jim,Smith,123-456-7890,something@blank.com\n",
          "Jane,Doe,123-344-3473,nothing@blank.com\n"
        ],
        ["Email"],
        &mock_reader/1,
        &mock_writer/2
      )

    assert new_csv == [
             @header,
             "Jane,Doe,123-344-3473,something@blank.com\n",
             "Jane,Doe,123-344-3473,nothing@blank.com\n"
           ]
  end

  test "email or phone duplicates removed" do
    new_csv =
      CsvDuper.remove_duplicates(
        [
          @header,
          "Jane,Doe,123-344-3473,something@blank.com\n",
          "Jane,Doe,000-000-0000,unique@blank.com\n",
          "Jane,Doe,123-344-3473,unique@blank.com\n",
          "Jim,Smith,123-456-7890,something@blank.com\n",
          "Jane,Doe,000-000-0000,veryunique@blank.com\n"
        ],
        ["Email", "Phone"],
        &mock_reader/1,
        &mock_writer/2
      )

    assert new_csv == [
             @header,
             "Jane,Doe,123-344-3473,something@blank.com\n",
             "Jane,Doe,000-000-0000,unique@blank.com\n"
           ]
  end
end
