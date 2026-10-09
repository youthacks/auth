module ApplicationHelper
  INPUT_CLASSES = "mt-1 w-full rounded-lg border border-neutral-300 px-4 py-2 transition focus:border-red-500 focus:outline-none focus:ring-2 focus:ring-red-500/20".freeze
  PRIMARY_BUTTON_CLASSES = "w-full rounded-lg bg-red-800 py-3 font-semibold text-white transition hover:bg-red-900 disabled:opacity-60".freeze
  SECONDARY_BUTTON_CLASSES = "w-full rounded-lg border border-neutral-300 py-3 font-semibold text-neutral-700 transition hover:bg-neutral-50 disabled:opacity-60".freeze

  def input_classes(extra = nil)
    [ INPUT_CLASSES, extra ].compact.join(" ")
  end

  def primary_button_classes(extra = nil)
    [ PRIMARY_BUTTON_CLASSES, extra ].compact.join(" ")
  end

  def secondary_button_classes(extra = nil)
    [ SECONDARY_BUTTON_CLASSES, extra ].compact.join(" ")
  end

  def page_title(title = nil)
    title.present? ? "#{title} | Youthacks Auth" : "Youthacks Auth"
  end

  def redirect_uris_for(client)
    client.redirect_uri.to_s.split(/\r?\n|\s+/).map(&:strip).reject(&:blank?)
  end
end
