# Two integrations accept the same destination value. Registration order matters
# to clients that consume the serialized job payload outside Rails.
ExportDestination = Struct.new(:name)

class LegacyDestinationSerializer < ActiveJob::Serializers::ObjectSerializer
  def serialize(destination)
    super("name" => destination.name, "format" => "legacy")
  end

  def deserialize(hash)
    ExportDestination.new(hash.fetch("name"))
  end

  def klass
    ExportDestination
  end
end

class CurrentDestinationSerializer < LegacyDestinationSerializer
  def serialize(destination)
    super.merge("format" => "current")
  end
end
