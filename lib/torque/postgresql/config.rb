# frozen_string_literal: true

module Torque
  module PostgreSQL
    # Stores a version check for compatibility purposes
    AR710 = (ActiveRecord.gem_version >= Gem::Version.new('7.1.0'))
    AR720 = (ActiveRecord.gem_version >= Gem::Version.new('7.2.0'))

    # Use the same logger as the Active Record one
    def self.logger
      ActiveRecord::Base.logger
    end

    # Holds the configuration. It used to come from +ActiveSupport::Configurable+,
    # which is deprecated on Rails 8.1 and removed on Rails 8.2
    def self.config
      @config ||= ActiveSupport::OrderedOptions.new
    end

    # Yields the configuration so it can be changed in a block
    def self.configure
      yield config
    end

    # Allow nested configurations
    config.define_singleton_method(:nested) do |name, &block|
      klass = ActiveSupport::OrderedOptions.new
      block.call(klass) if block
      send("#{name}=", klass)
    end

    # Set if any information that requires querying and searching or collecting
    # information should be eager loaded. This automatically changes when rails
    # same configuration is set to true
    config.eager_load = false

    # Set a list of irregular model name when associated with table names
    config.irregular_models = {}
    def config.irregular_models=(hash)
      PostgreSQL.config[:irregular_models] = hash.map do |(table, model)|
        [table.to_s, model.to_s]
      end.to_h
    end

    # Configure associations features
    config.nested(:associations) do |assoc|

      # Define if +belongs_to_many+ associations are marked as required by
      # default. False means that no validation will be performed
      assoc.belongs_to_many_required_by_default = false

    end
  end
end
