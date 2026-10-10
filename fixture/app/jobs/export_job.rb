class ExportJob < ActiveJob::Base
  retry_on IOError, wait: :polynomially_longer, attempts: 2

  def perform(title, amount = nil, deadline = nil)
    raise IOError, "export destination unavailable" if title == "offline"
    Note.find_or_create_by!(title: title) do |note|
      note.metadata = { amount: amount&.to_s, deadline: deadline&.iso8601 }
    end
  end
end
