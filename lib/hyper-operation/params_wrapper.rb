class HyperOperation
  class ParamsWrapper

    def initialize(inputs)
      @inputs = inputs
    end

    def lock
      @lock = true
      self
    end

    def to_h
      @inputs.with_indifferent_access
    end

    def to_s
      to_h.to_s
    end

    class << self

      def keys_klass
        @keys_klass ||= begin
          keys = (hash_filter.optional_keys + hash_filter.required_keys)
          Class.new(String) do
            keys.each { |key| define_method(:"#{key}?") { self == key } }
          end
        end
      end

      def combine_arg_array(args)
        hash = args.inject({}.with_indifferent_access) do |h, arg|
          raise ArgumentError.new("All arguments must be hashes") unless arg.is_a?(Hash)
          h.merge!(arg)
        end
      end

      def process_params(args)
        raw_inputs = combine_arg_array(args)
        inputs, errors = hash_filter.filter(raw_inputs)
        [raw_inputs, new(inputs), errors]
      end

      def add_param(*args, &block)
        type_method, name, opts, block = translate_args(*args, block)
        if opts.key? :default
          hash_filter.optional { send(type_method, name, opts, &block) }
        else
          hash_filter.required { send(type_method, name, opts, &block) }
        end

        # don't forget specially handling for procs
        define_method(name) do
          @inputs[name]
        end
        define_method(:"#{name}=") do |x|
          method_missing(:"#{name}=", x) if @locked
          @inputs[name] = x
        end
      end

      def dispatch_params(params, hashes)
        params = params.dup
        hashes.each { |hash| hash.each { |k, v| params.send(:"#{k}=", v) } }
        params.lock
      end

      def hash_filter
        @hash_filter ||= Mutations::HashFilter.new
      end

      def translate_args(*args, block)
        name, opts = get_name_and_opts(*args)
        if opts.key?(:type)
          type_method = opts.delete(:type)
          if type_method.is_a?(Array)
            opts[:class] = type_method.first if type_method.count > 0
            type_method = Array
          elsif type_method.is_a?(Hash) || type_method == Hash
            type_method = Hash
            block ||= proc { duck :* }
          end
          type_method = type_method.to_s.underscore
        else
          type_method = :duck
        end
        [type_method, name, opts, block || proc {}]
      end

      def get_name_and_opts(*args)
        if args[0].is_a? Hash
          opts = args[0]
          name = opts.first.first
          opts[:default] = opts.first.last
          opts.delete(name)
        else
          name = args[0]
          opts = args[1] || {}
        end
        [name, opts]
      end
    end
  end

  class << self
    def param(*args, &block)
      _params_wrapper.add_param(*args)
    end

    def outbound(*keys)
      keys.each { |key| _params_wrapper.add_param(key => nil, :type => :outbound) }
    end

    def _params_wrapper
      @_params_wrapper ||= begin
        if HyperOperation == superclass
          Class.new(ParamsWrapper)
        else
          superclass._params_wrapper.dup
        end
      end
    end
  end
end
