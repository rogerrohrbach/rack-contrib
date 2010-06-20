require 'i18n' unless defined? I18n

module Rack
  class Locale
    def initialize(app)
      @app = app
    end


    def call(env)
      old_locale = I18n.locale
      locale = nil

      if lang = env["HTTP_ACCEPT_LANGUAGE"]
        locale = locale_from_accept_language(lang)
      else
        locale = I18n.default_locale
      end

      locale = env['rack.locale'] = I18n.locale = locale.to_s
      status, headers, body = @app.call(env)
      headers['Content-Language'] = locale
      I18n.locale = old_locale
      [status, headers, body]
    end


    def locale_from_accept_language(field)

      match = rank_preferred_languages(field).detect do |l|
        I18n.available_locales.include?(l) || l == :*
      end

      (match.nil? || match == :*) ? I18n.default_locale : match
    end


    private
    def rank_preferred_languages(accept_language)

      # http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.10
      primary_tag = subtag = '[A-Za-z]{1,8}'
      language_tag = "#{primary_tag}(-#{subtag})*"

      # http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.4
      language_range = "#{language_tag}|\\*"
      quality_factor = ';q=(0(\.\d+)*|1)'

      languages = {}

      accept_language.split(/, */).each do |e|
        if lr = /\A#{language_range}/.match(e)
        then
          # also match as prefix
          lp = /\A#{primary_tag}/.match(lr.to_s) unless lr.to_s == '*'

          lr = lr.to_s
          lp = lp.to_s

          if q = /#{quality_factor}\z/.match(e).to_a[1]
          then
            languages[lr] = q.to_f
            languages[lp] = q.to_f if lp != lr
          else
            languages[lr] = 1
            languages[lp] = 1 if lp != lr
          end
        end
      end

      languages.sort { |a,b| b[1 ]<=> a[1] }.collect{ |k, v| k.to_sym }
    end

  end
end
