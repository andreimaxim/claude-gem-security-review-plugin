class Note < ActiveRecord::Base
  enum :status, { draft: 0, published: 1 }
  serialize :metadata, coder: JSON
  alias_attribute :caption, :title

  def title
    "Note: #{super}"
  end

  def self.exportable(limit)
    where(archived: false).limit(limit)
  end

  def self.average_title_length
    distinct.average(Arel.sql("LENGTH(title)"))
  end

  def self.archive_group(id)
    group(:id).having("id = ?", id).update_all(archived: true)
  end

  def self.publish_unique
    distinct.update_all(status: 1)
  end
end
