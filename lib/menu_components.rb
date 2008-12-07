module MenuComponents
  def self.included(base_class)
    base_class.class_eval do
      base_class.send(:extend, MenuComponentsClassMethods)
      base_class.send(:class_inheritable_accessor, :menu_controller, :menu_components)
      base_class.send(:menu_components=, [])
    end
  end
  
  module MenuComponentsClassMethods
    def clear_menu_components!
      menu_components.clear
    end
    
    def add_menu_components(*args)
      options = (args.last.is_a?(Hash) ? args.pop : {})
      
      add_layout_components(args, options)
    end
  
    def add_updater_menu_components(*args)
      options = (args.last.is_a?(Hash) ? args.pop : {})
      update_interval = (args.last.is_a?(Fixnum) ? args.pop : 30)
    
      add_layout_components(args, options.merge(:update_interval => update_interval))
    end

    def remove_menu_components(*components)
      self.menu_components.reject! do |component|
        components.include?(component[:action])
      end
    end
    
    def menu(menu_controller)
      self.menu_controller = menu_controller

      # Extend menu_controller with the module menu_controller::MenuComponents.  For each instance method
      # in said module, create an instance method on menu_controller with the same name.  Each of these
      # instance methods will call the class method to retrieve the locals needed to render the
      # corresponding partial.
      unless(menu_controller.extended_by.include?(menu_controller::MenuComponents))
        menu_controller.extend(menu_controller::MenuComponents)

        menu_controller::MenuComponents.instance_methods.each do |method|
          RAILS_DEFAULT_LOGGER.debug("Adding #{method} action to MenuController")
          menu_controller.send(:define_method, method) do
            locals = self.class.send(method)
            render(:partial => method, :locals => locals)
          end
        end
      end
    end
    
    private
      def add_layout_components(components, options)
        position = options.delete(:position) || self.menu_components.size
        
        if (options[:before])
          position = component_index(options.delete(:before))
        elsif (options[:after])
          position = component_index(options.delete(:after)) + 1
        end
        
        components.each do |component|
          self.menu_components.insert(position, options.merge(:action => component))
          position += 1
        end
      end
      
      def component_index(component)
        self.menu_components.each_index do |index|
          return index if (self.menu_components[index][:action] == component)
        end

        raise "Menu component '#{component}' not found."
      end
  end
  
  module MenuHelper
    def render_menu_components
      return nil unless (controller.class.respond_to?(:menu_components))
      menu_controller_path = controller.class.menu_controller.controller_path

      html = ""
      controller.class.menu_components.each do |component|
        div_id = "#{component[:action]}-menu-component"
        html += "<div id='#{div_id}'>"

        unless (component[:update_interval] && component[:after_load])
          action = component[:action]

          begin
            locals = MenuController.send(action)
          rescue NoMethodError
            locals = { }
          end

          html += render(:partial => "/#{menu_controller_path}/#{action}", :locals => locals);
        end

        html += "</div>"

        if (component[:update_interval])
          options = {
              :url => url_for(:controller => "/#{menu_controller_path}",
              :action => component[:action]),
              :update => "#{div_id}",
              :method => 'get'
          }

          html += javascript_tag(<<-JS)
            Event.observe(window, 'load', function() {
              var update = function() { #{remote_function(options)} }
              update();
              new PeriodicalExecuter(update, #{component[:update_interval]});
            });            
          JS
        end
      end

      return html
    end
  end
end