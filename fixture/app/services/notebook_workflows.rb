# Integration surfaces for a small notebook export client.
module NotebookWorkflows
  def self.sql_boolean(value)
    Note.connection.quote(value)
  end

  def self.elapsed_minutes(seconds)
    seconds.seconds.in_minutes
  end

  def self.advance_deadline(time, options)
    time.advance(options)
  end

  def self.author_name(attributes)
    attributes.with_indifferent_access.filter { |key, _| key == "name" }[:name]
  end

  def self.export_slug(title)
    title.parameterize(separator: nil)
  end

  def self.isolated_export(connection)
    connection.transaction(isolation: :read_uncommitted) do
      connection.select_value("SELECT COUNT(*) FROM notes")
      connection.transaction(isolation: :read_uncommitted) { connection.select_value("SELECT COUNT(*) FROM notes") }
    end
  end

  def self.export_timestamps
    result = Note.connection.select_all("SELECT created_at FROM notes ORDER BY id")
    result.cast_values
  end

  def self.cache_export(key, value)
    Rails.cache.write(key, value)
  end

  def self.expire_note_exports
    Rails.cache.delete_matched(%r{/notes/\d+\z})
  end

  def self.expire_exports(keys)
    Rails.cache.delete_multi(keys)
  end

  def self.write_event(sse)
    sse.write({ count: Note.count }, event: "notes", id: "latest")
  end

  def self.write_chunk(stream, buffer)
    stream.write(buffer)
  end

  def self.build_export(title, amount:, deadline:, locale: "en")
    job = ExportJob.new(title, amount, deadline)
    job.locale = locale
    job
  end
end
