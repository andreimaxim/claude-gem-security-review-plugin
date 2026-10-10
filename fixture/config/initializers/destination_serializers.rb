require Rails.root.join("app/jobs/export_destination")
ActiveJob::Serializers.add_serializers(LegacyDestinationSerializer, CurrentDestinationSerializer)
