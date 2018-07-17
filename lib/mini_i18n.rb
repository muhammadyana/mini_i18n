require "yaml"
require "mini_i18n/version"
require "mini_i18n/utils"

module MiniI18n
  class << self
    DEFAULT_LOCALE = :en
    SEPARATOR = '.'

    attr_accessor :fallbacks

    def default_locale
      @@default_locale ||= DEFAULT_LOCALE
    end

    def default_locale=(new_locale)
      @@default_locale = valid_locale?(new_locale) || default_locale
    end

    def default_available_locales
      @@default_available_locales ||= translations.keys
    end

    def available_locales
      @@available_locales ||= default_available_locales
    end

    def available_locales=(new_locales)
      @@available_locales = new_locales.map(&:to_s)
    end

    def translations
      @@translations ||= {}
    end

    def locale
      Thread.current[:mini_i18n_locale] ||= default_locale
    end

    def locale=(new_locale)
      set_locale(new_locale)
    end

    def configure
      yield(self) if block_given?
    end

    def load_translations(path)
      Dir[path].each do |file|
        _translations = YAML.load_file(file)
        _translations.each do |locale, values|
          locale = locale.to_s
          @@available_locales << locale unless available_locale?(locale)

          if translations[locale]
            translations[locale] = Utils.deep_merge(translations[locale], values)
          else
            translations[locale] = values
          end
        end
      end
    end

    def translate(key, options = {})
      return if key.empty? || translations.empty?

      _locale = available_locale?(options[:locale]) || locale
      scope = options[:scope]

      keys = [_locale.to_s]
      keys << scope.to_s.split(SEPARATOR) if scope
      keys << key.to_s.split(SEPARATOR)
      keys = keys.flatten

      result = translations.dig(*keys)

      if fallbacks && result.empty?
        keys = Utils.replace_with(keys, _locale, default_locale.to_s)
        result = translations.dig(*keys)
      end

      if result.respond_to?(:match) && result.match(/%{\w+}/)
        result = Utils.interpolate(result, options)
      end

      result || options[:default]
    end
    alias t translate

    private

    def set_locale(new_locale)
      new_locale = new_locale.to_s
      if available_locale?(new_locale)
        Thread.current[:mini_i18n_locale] = new_locale
      end
      locale
    end

    def available_locale?(new_locale)
      new_locale = new_locale.to_s
      available_locales.include?(new_locale) && new_locale
    end
  end
end