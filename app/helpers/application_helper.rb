module ApplicationHelper
  def has_access?(resource, action)
    Policy.can? action, resource, current_user, @current_user_policies
  end

  def check_access(resource, action)
    Policy.authorize action, resource, current_user, @current_user_policies
  end

  def flash_message
    res = nil

    keys = { :notice => 'flash_notice', :error => 'flash_error', :alert => 'flash_error' }

    keys.each do |key, value|
      if flash[key]
        html_option = { :class => "flash #{value}" }
        html_option[:'data-hide-timeout'] = 3000 if key == :notice
        res = content_tag :div, html_option do
          content_tag :div do
            flash[key]
          end
        end
      end
    end

    res
  end

  define_component :card, sections: [:top, :actions, :bottom], attributes: [:image]
  define_component :cdx_table, sections: [:thead, :tbody], attributes: [:title]

  define_component :cdx_tabs do |c|
    c.section :headers, multiple: true, component: :cdx_tabs_header
    c.section :contents, multiple: true
  end
  define_component :cdx_tabs_header, attributes: [:title]
  ViewComponents::ComponentsBuilder::Component.classes[:cdx_tabs].class_eval do
    def tab(options, &block)
      self.header options
      if block_given?
        self.content &block
      else
        self.content do
        end
      end
    end
  end

  def test_results_table(attributes)
    options = { filter: {} }
    options[:filter]['site.uuid'] = attributes[:filter][:site].uuid if attributes[:filter][:site]

    react_component('TestResultsTable', filter: options[:filter])
  end
end
