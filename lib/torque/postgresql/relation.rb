# frozen_string_literal: true

module Torque
  module PostgreSQL
    module Relation
      extend ActiveSupport::Concern

      SINGLE_VALUE_METHODS = []
      MULTI_VALUE_METHODS = []
      VALUE_METHODS = SINGLE_VALUE_METHODS + MULTI_VALUE_METHODS

      ARColumn = ::ActiveRecord::ConnectionAdapters::PostgreSQL::Column

      # Resolve column name when calculating models, allowing the column name to
      # be more complex while keeping the query selection quality
      def calculate(operation, column_name)
        column_name = resolve_column(column_name).first if column_name.is_a?(Hash)
        super(operation, column_name)
      end

      # Resolve column definition up to second value.
      # For example, based on Post model:
      #
      #   resolve_column(['name', :title])
      #   # Returns ['name', '"posts"."title"']
      #
      #   resolve_column([:title, {authors: :name}])
      #   # Returns ['"posts"."title"', '"authors"."name"']
      #
      #   resolve_column([{authors: [:name, :age]}])
      #   # Returns ['"authors"."name"', '"authors"."age"']
      def resolve_column(list, base = false)
        base = resolve_base_table(base)

        Array.wrap(list).map do |item|
          case item
          when String
            ::Arel.sql(klass.send(:sanitize_sql, item.to_s))
          when Symbol
            base ? base.arel_table[item] : klass.arel_table[item]
          when Array
            resolve_column(item, base)
          when Hash
            raise ArgumentError, 'Unsupported Hash for attributes on third level' if base
            item.map { |key, other_list| resolve_column(other_list, key) }
          else
            raise ArgumentError, "Unsupported argument type: #{value} (#{value.class})"
          end
        end.flatten
      end

      # Get the TableMetadata from a relation
      def resolve_base_table(relation)
        return unless relation

        # Rails 8.1 renamed +TableMetadata#associated_with?+, so check the
        # reflection directly, which is exactly what that method did
        table = predicate_builder.send(:table)
        if klass._reflect_on_association(relation.to_s)
          table.associated_table(relation.to_s).send(:klass)
        else
          raise ArgumentError, "Relation for #{relation} not found on #{klass}"
        end
      end

      # Serialize the given value so it can be used in a condition tha involves
      # the given column
      def cast_for_condition(column, value)
        column = columns_hash[column.to_s] unless column.is_a?(ARColumn)

        # Rails 8.1 removed +lookup_cast_type_from_column+ from the adapter, so
        # rely on the public attribute type, the same one +where+ uses
        value = klass.type_for_attribute(column.name).serialize(value)

        if klass.respond_to?(:with_connection)
          klass.with_connection { |conn| conn.type_cast(value) }
        else
          connection.type_cast(value)
        end
      end

      private

        # Compatibility method with 5.0
        unless ActiveRecord::Relation.method_defined?(:get_value)
          def get_value(name)
            @values[name] || ActiveRecord::QueryMethods::FROZEN_EMPTY_ARRAY
          end
        end

        # Compatibility method with 5.0
        unless ActiveRecord::Relation.method_defined?(:set_value)
          def set_value(name, value)
            assert_mutability! if respond_to?(:assert_mutability!)
            @values[name] = value
          end
        end

      # When a relation is created, force the attributes to be defined,
      # because the type mapper may add new methods to the model. This happens
      # for the given model Klass and its inheritances
      module Initializer
        def initialize(klass, *, **)
          super

          klass.superclass.send(:relation) if klass.define_attribute_methods &&
            klass.superclass != ActiveRecord::Base && !klass.superclass.abstract_class?
        end
      end
    end

    # Include the methos here provided and then change the constants to ensure
    # the operation of ActiveRecord Relation
    ActiveRecord::Relation.include Relation
    ActiveRecord::Relation.prepend Relation::Initializer
  end
end
