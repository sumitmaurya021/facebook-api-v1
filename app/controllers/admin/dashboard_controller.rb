module Admin
  class DashboardController < ActionController::Base
    helper_method :render_inline_search_controls, :render_inline_pager

    http_basic_authenticate_with(
      name: ENV.fetch("ADMIN_DASHBOARD_USER", "admin"),
      password: ENV.fetch("ADMIN_DASHBOARD_PASSWORD", "admin123")
    )

    def show
      @overview = AdminOverview.new.call
      render layout: false
    end

    private

    def render_inline_search_controls(id, placeholder)
      helpers.tag.div(class: "toolbar") do
        helpers.safe_join(
          [
            helpers.tag.input(id: id, class: "search", type: "search", placeholder: placeholder, data: { search: true }),
            helpers.tag.select(class: "select", data: { page_size_select: true }) do
              helpers.safe_join(
                [6, 8, 12, 20, 50].map do |size|
                  helpers.tag.option("#{size} per page", value: size)
                end
              )
            end
          ]
        )
      end
    end

    def render_inline_pager
      helpers.tag.div(class: "pager") do
        helpers.safe_join(
          [
            helpers.tag.div("0 items", class: "hint", data: { page_info: true }),
            helpers.tag.div(class: "pager-actions") do
              helpers.safe_join(
                [
                  helpers.tag.button("Previous", type: "button", data: { prev: true }),
                  helpers.tag.button("Next", type: "button", data: { next: true })
                ]
              )
            end
          ]
        )
      end
    end
  end
end
