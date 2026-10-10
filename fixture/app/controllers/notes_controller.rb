class NotesController < ActionController::API
  include ActionView::Rendering
  include ActionController::Helpers
  include ActionController::ImplicitRender
  include ActionController::MimeResponds

  def health
    render json: { status: "ok" }
  end

  def catalog
    render json: { url: catalog_path(locale: params[:locale], id: params[:id]) }
  end

  def freshness
    render json: { status: "updated" } if stale?(last_modified: Time.utc(1994, 11, 6, 8, 49, 37))
  end

  def index
    @notes = Note.order(:id)
    render :index
  end

  def show
    @note = Note.find(params[:id])
    render json: { caption: @note.caption, metadata: @note.metadata }
  end

  def create
    note = Note.create!(params.require(:note).permit(:title))
    redirect_to note_url(note)
  end

  def export
    render json: Note.exportable(params.fetch(:limit, "10")).pluck(:id)
  end

  def preview
    @notes = Note.order(:id)
    render :index
    head :ok
  end

  def cache_status
    first = Rails.cache.read("live-status")
    Thread.new { Rails.cache.write("live-status", "new") }.join
    render json: [first, Rails.cache.read("live-status")]
  end
end
