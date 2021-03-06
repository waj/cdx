class CSVMessageParser
  DEFAULT_SEPARATOR = ";"

  def initialize(separator=DEFAULT_SEPARATOR)
    @separator = separator
  end

  def lookup(path, data, root = data)
    if path.split(Manifest::PATH_SPLIT_TOKEN).size > 1
      raise "path nesting is unsupported for CSV Messages"
    else
      data[path]
    end
  end

  def load(data, root_path = nil)
    csv = CSV.new(data, col_sep: @separator)
    headers = csv.shift
    csv.map do |row|
      result = {}
      headers.each_with_index do |header, index|
        result[header] = row[index]
      end
      result
    end
  end
end
