def gen_submodule_render(template_dir)
  Module.new do
    class_variable_set(:@@template_dir, template_dir)

    def self.included(base)
      base.extend @@ClassMethods
    end

    @@ClassMethods = Module.new do
      def render(renderer, template_filename, locals = {})
        template = File.read(File.join(class_variable_get(:@@template_dir), template_filename))
        renderer.call(template, :layout => false, :locals => locals)
      end
    end
  end
end

def gen_submodule_public(public_dir, route)
  Module.new do
    class_variable_set(:@@route, route)
    class_variable_set(:@@public_dir, public_dir)

    def self.included(base)
      base.extend @@ClassMethods
    end

    @@ClassMethods = Module.new do
      def serve_submodule_public_folder(app)
        public_dir = class_variable_get(:@@public_dir)
        route_prefix = class_variable_get(:@@route)
        app.get "#{route_prefix}/:file" do
          path = File.join(public_dir, params[:file])
          return unless File.file?(path)
          send_file(path)
        end
      end

      def singleton_method_added(name)
        return if name != :registered
        overwrite_registered
      end

      def overwrite_registered
        class_eval do
          class << self
            unless method_defined?(:custom_registered)
              define_method(:custom_registered) do |app|
                serve_submodule_public_folder(app)
                original_registered(app)
              end
            end

            if !method_defined?(:registered)
              alias_method :registered, :custom_registered
            elsif instance_method(:registered) != instance_method(:custom_registered)
              alias_method :original_registered, :registered
              alias_method :registered, :custom_registered
            end
          end
        end
      end
    end
  end
end

# require all submodules found in the /submodules directory
# (filename must match submodule directory name)
Dir.foreach(File.join(File.dirname(__FILE__),'submodules/')) do |name|
  next if name == '.' or name == '..'
  next if !File.directory?(File.expand_path("submodules/#{name}/", File.dirname(__FILE__)))
  path = File.expand_path("submodules/#{name}/#{name}", File.dirname(__FILE__))
  require path if File.exists?(path + ".rb")
end
