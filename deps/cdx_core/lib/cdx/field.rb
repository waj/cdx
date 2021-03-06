class Cdx::Field
  attr_accessor :scope

  def self.for scope, name, definition
    definition = definition || {}
    field_class = case definition["type"]
      when "nested"
        NestedField
      when "multi_field"
        MultiField
      when "enum"
        EnumField
      when "dynamic"
        DynamicField
      when "duration"
        DurationField
      else
        Cdx::Field
      end
    field_class.new scope, name, definition
  end

  def initialize scope, name, definition
    @scope = scope
    @name = name
    @definition = (definition || {}).freeze
  end

  def type
    @definition["type"] || 'string'
  end

  def root_scope
    scope.root_scope
  end

  def name
    @name
  end

  def nested?
    false
  end

  def searchable?
    @definition["searchable"]
  end

  def scoped_name
    "#{scope.scoped_name}.#{name}"
  end

  def flatten
    self
  end

  def valid_values
    @definition["valid_values"]
  end

  def pii?
    @definition["pii"] || false
  end

  def humanize(value)
    value
  end

  class NestedField < self
    def initialize scope, name, definition
      if definition["sub_fields"]
        definition["sub_fields"] = definition["sub_fields"].map do |sub_name, sub_field|
          Cdx::Field.for(self, sub_name, sub_field)
        end
      end

      super
    end

    def nested?
      true
    end

    def searchable?
      sub_fields.any? &:searchable?
    end

    def flatten
      sub_fields.map(&:flatten)
    end

    def sub_fields
      @definition["sub_fields"]
    end
  end

  class MultiField < self
  end

  class EnumField < self
    def options
      @definition["options"]
    end
  end

  class DynamicField < self
  end

  class DurationField < self
    def humanize(value)
      if value.is_a?(Hash) && value.length == 1
        "#{value.values.first} #{value.keys.first}"
      else
        super
      end
    end
  end
end
