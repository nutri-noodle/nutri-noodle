module Searchable
  def self.included(base)
    base.extend Search
    base.extend VectorSearch

    # to alter specific options per model use #define_matching_vectors class method to add options
    # defines a vector search method for postgres db.  Calling Model.matching_vector(search) expects
    # a vector column defined on the model.  by default the query is espected to use "model.vector @@ plainto_tsquery('english', :search)"
    # where :search is a comma seperated string.

    base.define_singleton_method :matching_vector do |search|
      match_terms_using_vector(search)
    end

    # like the matching_vector method, this has the same defaults but matches based on queries that do not equal :search
    base.define_singleton_method :non_matching_vector do |search|
      match_terms_using_vector(search, :without => true)
    end
  end

  module Search
    def search_filter(search = '')
      #search is coming from params, so it should be handled as a string
      search.respond_to?(:to_s) ? search = search.to_s : return
      # yield the scope if search term is valid.  Define validation in define_search_filter within class
      if !default_search_filter(search)
        yield
      else
        all
      end
    end

    def filtered_terms
      @filtered_terms ||= []
    end

    def been_filtered?(search)
      filtered_terms.include?(search.to_s)
    end

    def default_search_filter(search = '')
      search.nil? || search.strip.empty?
    end

    def simple_search(search, query)
      if query.respond_to?(:keys) # Hash or ActionController::Parameters
        search_filter(search) {where(query)}
      else
        search_filter(search) {where(query + ActiveRecord::Base.connection.quote("%#{search.to_s.strip}%"))}
      end
    end

    def searchable_by_id(search, query = nil)
      search_filter(search) do
        query ||= "#{table_name}.id = :search"
        search.to_s =~ /\A\s*\d+\s*\Z/ ? where(query, :search => search.to_i) : where("1=0")
      end
    end

    def matching_searchable(search, id_search = :searchable_by_id, text_search = :text_searches)
      return unless respond_to?(id_search) && respond_to?(text_search)
      search_filter(search) do
        if search.to_s =~ /\A\s*\d+\s*\Z/
          send(id_search, search)
        else
          send(text_search, search)
        end
      end
    end

    def widened_search(search, query, search_scope = self)
      return unless search.map(&:class).uniq.one?
      case search.first
      when String
        search_scope.simple_search(search, query)
      when Numeric, self
        search = search.map(&:id) if search.is_a?(self)
        search_scope.searchable_by_id(search)
      else
        none
      end
    end
  end


  module VectorSearch
    MATCHING_VECTOR = :matching_vector
    NON_MATCHING_VECTOR = :non_matching_vector
    def define_matching_vector(*args)
      options = args.extract_options!
      name = vector_method_name(MATCHING_VECTOR, args.first)
      define_singleton_method name do |search|
        match_terms_using_vector(search, options)
      end
    end

    def define_non_matching_vector(*args)
      options = args.extract_options!
      name = vector_method_name(NON_MATCHING_VECTOR, args.first)
      define_singleton_method name do |search|
        match_terms_using_vector(search, options.merge(:without => true))
      end
    end

    def define_matching_vectors(*args)
      options = args.extract_options!
      define_matching_vector(vector_method_name(MATCHING_VECTOR, args.first), options)
      define_non_matching_vector(vector_method_name(NON_MATCHING_VECTOR, "non_#{args.first.to_s}"), options)
    end

    private
    #valid options [:without, :tsvector, :column, :name]

    def vector_method_name(default_name, name)
      name && name.to_s != default_name.to_s ? name : default_name
    end

    def match_terms_using_vector(search, options = {})
      without = options[:without]
      search_array = []
      term_hash = {}
      options[:column] ||= self.model_name.plural + ".vector"
      Array.wrap(options[:column]).each do |vector_column|
        search_array += search.to_s.split(",").reject(&:blank?).map.with_index do |term,index|
          term_key = "search#{index}"
          term_hash[term_key.to_sym] ||= term.to_s.strip
          vector_query(vector_column, term_key, without, join_tsquery(options[:tsvector]))
        end
      end
      where(search_array.join(without ? " and " : " or "), term_hash)
    end

    def join_tsquery(array)
      if array.blank? || (array.respond_to?(:size) && array.size != 2)
        "plainto_tsquery('english'"
      else
        "#{array.first}('#{array.last}'"
      end
    end

    def vector_query(table_and_column, term_key, without, tsvector_choice)
      prefix = without ? "not " : ""
      "#{prefix}#{table_and_column} @@ #{tsvector_choice}, :#{term_key})"
    end
  end
end
