# Correlate the selected request, tool acknowledgement and worker notification.
class ResearchTrace
  attr_reader :tools, :worker_id, :notification, :handoff_result

  def initialize(request)
    @request = request
    @tools = {}
    @results = {}
    @notifications = {}
    @turn_results = []
  end

  def observe(event)
    Array(event.dig("message", "content")).each do |block|
      @tools[block["id"]] = block if block["type"] == "tool_use"
      @results[block["tool_use_id"]] = block if block["type"] == "tool_result"
    end
    calls = research_calls
    if calls.one? && calls.first["input"] == @request
      result = @results[calls.first["id"]]
      if result && !result["is_error"]
        text = result["content"]
        text = text.map { |part| part["text"] }.compact.join("\n") if text.is_a?(Array)
        @worker_id = text.to_s[/Research started for .* \(agent ([^)]+)\)\./, 1]
      end
    end
    if event["type"] == "system" && event["subtype"] == "task_notification"
      @notifications[event["task_id"]] = event
    end
    @turn_results << event if event["type"] == "result"
    @notification = @notifications[@worker_id] if @worker_id
    @handoff_result = nil
    if report
      payload = "Research #{@request.fetch('gem')} #{@request.fetch('currentVersion')} → #{@request.fetch('requestedVersion')} (agent #{@worker_id}) completed.\n\n#{report}"
      @handoff_result = @turn_results.find do |result|
        origin = result["origin"]
        next false unless result["subtype"] == "success" && result["is_error"] == false &&
          origin.is_a?(Hash) && origin["kind"] == "task-notification" && result["result"] == payload
        !origin.key?("runId") || (origin["runId"].is_a?(String) && !origin["runId"].empty? &&
          origin["runId"] == @notification["run_id"])
      end
    end
  end

  def research_calls
    @tools.values.select { |block| block["name"] == "mcp__gem-upgrade__research" }
  end

  def request_matches?
    research_calls.one? && research_calls.first["input"] == @request && !@worker_id.nil?
  end

  def terminal?
    request_matches? && @notification && %w[completed failed stopped killed].include?(@notification["status"])
  end

  def handoff?
    terminal? && !@handoff_result.nil?
  end

  def report
    return unless request_matches? && @notification && @notification["status"] == "completed"
    text = @notification["summary"]
    description = "Research #{@request.fetch('gem')} #{@request.fetch('currentVersion')} → #{@request.fetch('requestedVersion')}"
    return unless text.is_a?(String) && !text.strip.empty? && ![description, @worker_id].include?(text.strip)
    text
  end
end
