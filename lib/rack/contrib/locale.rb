require 'i18n' unless defined? I18n


module Rack
  class Locale
    # customize for the length of your top-level domain
    @@tld_length = 1

    def self.tld_length
      @@tld_length
    end


    def self.tld_length=(n)
      @@tld_length = n
    end


    def initialize(app)
      @app = app
    end


    def call(env)
      request = Request.new(env)

      old_locale = I18n.locale
      
      if localized? request
        unless locale = get_locale_from_subdomain(request)
          return Response.new(
            "Not found (unsupported locale).\n",
            404,
            {'Content-Type' => 'text/plain'}
          ).finish
        end
      else
        # choose the most appropriate locale
        if header = env["HTTP_ACCEPT_LANGUAGE"]
          locale = locale_from_accept_language(header)
        else
          locale = I18n.default_locale
        end
      end

      if ((locale == I18n.default_locale &&
           request.url == default_locale_url(request)) ||
          (request.url == localized_url(request, locale)))

        # set the locale to match the request URI
        locale = env['rack.locale'] = I18n.locale = locale.to_s
        status, headers, body = @app.call(env)
        headers['Content-Language'] = locale
        I18n.locale = old_locale
        [status, headers, body]
      else
        # redirect to the appropriate URL
        Response.new(
          "Redirecting for language #{locale.to_s}...\n",
          302,
          {
            'Content-Type' => 'text/plain',
            'Location' =>
              (locale == I18n.default_locale) ?
                default_locale_url(request) :
                localized_url(request, locale)
          }
        ).finish
      end
    end


    private

    def localized?(request)
      s = request.host.split('.').first
      iso_639_1_code?(s) || I18n.available_locales.include?(s.to_sym)
    end


    def get_locale_from_subdomain(request)
      sym = request.host.split('.').first.to_sym
      (I18n.available_locales.include? sym) ? sym : nil
    end


    def default_locale_url(request)
      host_components = request.host.split('.')

      if (request.host.split('.')[0..-(self.class.tld_length + 2)]).length > 0
        if iso_639_1_code? host_components.first
          host_components.shift
        end

        new_url = "#{request.scheme}://#{host_components.join('.')}"

        unless ((request.scheme == 'http' && request.port == 80) ||
                (request.scheme == 'https' && request.port == 443))
          new_url << ":#{request.port}"
        end

        new_url << request.fullpath
      else
        request.url
      end
    end


    def localized_url(request, locale)
      host_components = request.host.split('.')

      if (host_components.first == 'www' ||
          I18n.available_locales.include?(host_components.first.to_sym))

        host_components.shift
      end

      host_components.unshift locale.to_s

      new_url = "#{request.scheme}://#{host_components.join('.')}"

      unless ((request.scheme == 'http' && request.port == 80) ||
              (request.scheme == 'https' && request.port == 443))
        new_url << ":#{request.port}"
      end

      new_url << request.fullpath
    end


    def locale_from_accept_language(field)

      match = rank_preferred_languages(field).detect do |l|
        I18n.available_locales.include?(l) || l == :*
      end

      (match.nil? || match == :*) ? I18n.default_locale : match
    end


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


    def iso_639_1_code?(string)
      %W(
        aa ab ae af ak am an ar as av ay az ba be bg bh bi bm bn bo
        br bs ca ce ch co cr cs cu cv cy da de dv dz ee el en eo es
        et eu fa ff fi fj fo fr fy ga gd gl gn gu gv ha he hi ho hr
        ht hu hy hz ia id ie ig ii ik io is it iu ja jv ka kg ki kj
        kk kl km kn ko kr ks ku kv kw ky la lb lg li ln lo lt lu lv
        mg mh mi mk ml mn mr ms mt my na nb nd ne ng nl nn no nr nv
        ny oc oj om or os pa pi pl ps pt qu rm rn ro ru rw sa sc sd
        se sg si sk sl sm sn so sq sr ss st su sv sw ta te tg th ti
        tk tl tn to tr ts tt tw ty ug uk ur uz ve vi vo wa wo xh yi
        yo za zh zu
      ).include? string
    end
  end
end
