module ActiveExchanger
  class Base
    cattr_accessor :exchangers

    @@exchangers = {}

    CATEGORIES = %i[accountancy animal_farming human_resources none plant_farming purchases sales settings stocks].freeze
    VENDORS = %i[acom agro_systemes agrigest agroedi bordeaux_sciences_agro bovins_croissance caj charentes_alliance ebp ekylibre fiea isagri lely_milk_robot lilco listo logicall milklic none odicom planete_vegetal process_to_wine socleo quadra sage square synel synest telepac upra vivescia].freeze

    class << self
      def inherited(subclass)
        ActiveExchanger::Base.register_exchanger(subclass)
        super
      end

      attr_accessor :deprecated do
        false
      end

      # @param [Symbol] value
      # @return [Symbol]
      def category(value = nil)
        if value.nil?
          @category || :none
        else
          raise ArgumentError.new("Invalid category #{value} for #{exchanger_name} exchanger, please provide one among #{CATEGORIES.join(', ')}") unless CATEGORIES.include?(value)

          @category = value
        end
      end

      # @param [Symbol] value
      # @return [Symbol]
      def vendor(value = nil)
        if value.nil?
          @vendor || :none
        else
          raise ArgumentError.new("Invalid vendor #{value} for #{exchanger_name} exchanger, please provide one among #{VENDORS.join(', ')}") unless VENDORS.include?(value)

          @vendor = value
        end
      end

      def deprecated?
        deprecated
      end

      def exchanger_name
        name.to_s.underscore.gsub(/_exchanger$/, '').tr('/', '_').to_sym
      end

      def human_name
        "exchangers.#{exchanger_name}".t
      end

      def register_exchanger(klass)
        @@exchangers[klass.exchanger_name] = klass
      end

      def importers
        @@exchangers.select { |_, v| v.method_defined?(:import) }
      end

      def importers_selection(options = {})
        list = importers
        list = list.reject { |_, v| v.deprecated? } unless options[:with_deprecated]
        list.collect { |i, e| [e.human_name, i] }.sort_by { |a| a.first.lower_ascii }
      end

      def exporters
        @@exchangers.select { |_k, v| v.method_defined?(:export) }
      end

      def find_and_import(nature, file, options = {}, &block)
        ActiveSupport::Deprecation.warn "ActiveExchanger::Base.find_and_import is deprecated, use ActiveExchanger::Base::run instead"
        find(nature).import(file, options, &block)
      end

      # Import file without check
      def import!(file, options = {}, &block)
        ActiveSupport::Deprecation.warn "ActiveExchanger::Base::import! is deprecated, use ActiveExchanger::Base.run instead"

        build(file, options, &block).import
      end

      def run(nature, file, check: true, options: {}, &block)
        find(nature).build(file, options: options, &block).run(check: check)
      end

      # Import file with check if possible
      def import(file, options = {}, &block)
        ActiveSupport::Deprecation.warn "ActiveExchanger::Base.import is deprecated, use ActiveExchanger::Base::build and .run instead"
        build(file, options: options, &block).run.success?
      end

      def export(file, options = {}, &block)
        build(file, options, &block).export
      end

      def check(file, options = {}, &block)
        exchanger = build(file, supervisor_mode: :check, options: options, &block)
        valid = false
        ActiveRecord::Base.transaction do
          if exchanger.respond_to? :check
            exchanger.check
          else
            exchanger.import
          end
          valid = true
          raise ActiveRecord::Rollback
        end
        GC.start
        valid
      rescue
        false
      end

      def build(file, supervisor_mode: :normal, options: {}, &block)
        supervisor = Supervisor.new(supervisor_mode, &block)
        new(file, supervisor, options)
      end

      def find(nature)
        klass = @@exchangers[nature.to_sym]
        unless klass
          raise "Unable to find exchanger #{nature.inspect}. (#{@@exchangers.keys.to_sentence(locale: :eng)})"
        end

        klass
      end

      def find_by(nature)
        find nature
      rescue
        nil
      end

      # This method check file by default by trying a run and
      # and if no exception raise, it's fine so changes are rolled back.
      def check_by_default
        ActiveSupport::Deprecation.warn "ActiveExchanger::Base.check_by_default is deprecated, use ActiveExchanger::Base::run instead"

        define_method :check do
          import
        end
      end

      # @param [String] exchange_name
      # @param [String] locale
      # @return [Maybe<String>] If exchanger template file exists, return Some(file_path), else return None
      def template_file_for(exchanger_name, locale)
        Maybe(Dir[Rails.root.join("config/locales/#{locale}/exchangers/#{exchanger_name}.*")].first)
      end
    end

    attr_reader :file, :supervisor, :options

    def initialize(file, supervisor, **options)
      @file = Pathname.new(file)
      @supervisor = supervisor
      @options = options
    end

    alias w supervisor

    def run(check: true)
      result = Result.failed("Somethong is wrong, the import didn't run")

      ApplicationRecord.transaction do
        if !check || (result = safe_check).success?
          result = safe_import
        end

        raise ActiveRecord::Rollback if result.error?
      end

      result
    rescue StandardError => e
      Result.failed("Server error", exception: e)
    end

    private

      def safe_check
        if !respond_to?(:check) || check
          Result.success
        else
          Result.aborted("Invalid file provided " + supervisor.errors.join(', '))
        end
      rescue StandardError => e
        Result.aborted(exception: e)
      end

      def safe_import
        if !!import
          Result.success
        else
          Result.failed('The import reported an error ' + supervisor.errors.join(', '))
        end
      rescue StandardError => e
        Result.failed(exception: e)
      end
  end
end
