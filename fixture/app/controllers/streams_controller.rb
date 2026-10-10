class StreamsController < ActionController::API
  include ActionController::Live

  def show
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Last-Modified"] = Time.now.httpdate
    sse = ActionController::Live::SSE.new(response.stream, event: "notes")
    NotebookWorkflows.write_event(sse)
  ensure
    sse&.close
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end
end
