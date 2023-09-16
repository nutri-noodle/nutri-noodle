module PagedQueryHelper
  extend ActiveSupport::Concern
  PAGE_LENGTH=20

  included do
    helper_method :page_length, :page, :more_pages_count, :show_next?
  end

  def page_length
    [(params[:page_length].presence || PagedQueryHelper::PAGE_LENGTH).to_i, 100].min
  end

  def offset
    [( page - 1) * page_length, 0].max
  end

  def page
    (params[:page].presence || 1).to_i
  end

  def limit
    page_length
  end

  def more_pages_count
    offset + page_length
  end

  def show_next?
    @show_next ||= begin
      if @count
        (more_pages_count || 0) < @count
      else
        true
      end
    end
  end
end
