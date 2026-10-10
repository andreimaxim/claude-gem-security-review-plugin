# Correlate the selected request, tool acknowledgement and worker notification.
class ResearchTrace
  attr_reader :tools, :worker_id, :notification

  def initialize(request)
    @request = request
    @tools = {}
    @results = {}
    @notifications = {}
    @followup = false
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
    if event["subtype"] == "task_notification"
      @notifications[event["task_id"]] = event
    end
    @notification = @notifications[@worker_id] if @worker_id
    @followup ||= event["type"] == "result" && event.fetch("result_index", 0) > 0 && !event["is_error"]
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
    terminal? && @followup
  end

  def report
    return unless request_matches? && @notification && @notification["status"] == "completed"
    text = @notification["summary"]
    description = "Research #{@request.fetch('gem')} #{@request.fetch('currentVersion')} → #{@request.fetch('requestedVersion')}"
    return unless text.is_a?(String) && !text.strip.empty? && ![description, @worker_id].include?(text.strip)
    text
  end
end
