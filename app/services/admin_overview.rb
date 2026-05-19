class AdminOverview
  SKIP_DIRS = %w[.git log tmp storage vendor node_modules].freeze

  API_RISK_RULES = [
    {
      matcher: ->(route) { route[:verb] == "POST" && route[:path].include?("/api/users") },
      level: "High",
      tone: "risk",
      reason: "Signup public hai aur token issue karta hai. Rate limit, duplicate-flow tests aur abuse protection chahiye."
    },
    {
      matcher: ->(route) { route[:path].include?("/oauth/token") },
      level: "Medium",
      tone: "warn",
      reason: "Password grant enabled hai. Trusted first-party clients ke liye okay, public clients ke liye sensitive."
    },
    {
      matcher: ->(route) { route[:path].include?("/users/sign_in") || route[:path].include?("/users/password") },
      level: "Medium",
      tone: "warn",
      reason: "Devise default HTML routes exposed hain. API-only app mein JSON behavior aur UI exposure verify karo."
    }
  ].freeze

  GOOD_RULES = [
    {
      matcher: ->(route) { route[:path].include?("/admin/overview") },
      level: "Protected",
      tone: "good",
      reason: "Admin overview HTTP Basic auth ke peeche locked hai."
    },
    {
      matcher: ->(route) { route[:path].include?("/oauth/revoke") || route[:path].include?("/oauth/introspect") },
      level: "Good",
      tone: "good",
      reason: "OAuth token lifecycle ke support endpoints available hain."
    }
  ].freeze

  def call
    {
      generated_at: Time.current,
      app: app_summary,
      metrics: metrics,
      stack: stack,
      routes: route_summary,
      tests: test_summary,
      files: file_inventory,
      quality: file_quality,
      database: database_summary,
      scenarios: scenario_map,
      warnings: warnings,
      unused: unused_features
    }
  end

  private

  def app_summary
    {
      name: Rails.application.class.module_parent_name,
      environment: Rails.env,
      rails_version: Rails.version,
      ruby_version: RUBY_VERSION,
      database_adapter: ActiveRecord::Base.connection_db_config.adapter,
      api_only: Rails.application.config.api_only
    }
  end

  def metrics
    {
      files: project_files.count,
      app_files: project_files.count { |file| file.start_with?("app/") },
      controllers: Dir[Rails.root.join("app/controllers/**/*.rb")].count,
      models: Dir[Rails.root.join("app/models/**/*.rb")].count,
      services: Dir[Rails.root.join("app/services/**/*.rb")].count,
      routes: route_summary.count,
      risk_routes: route_summary.count { |route| route[:tone] == "risk" },
      warning_routes: route_summary.count { |route| route[:tone] == "warn" }
    }
  end

  def stack
    gems = Bundler.load.specs.map(&:name)

    [
      feature("Rails API", true, "API-only backend mode"),
      feature("Devise", gems.include?("devise"), "Password auth, registration, password recovery"),
      feature("Doorkeeper", gems.include?("doorkeeper"), "OAuth access token and refresh token provider"),
      feature("PostgreSQL", gems.include?("pg"), "Primary relational database"),
      feature("Solid Queue", gems.include?("solid_queue"), "Database-backed background jobs"),
      feature("Solid Cache", gems.include?("solid_cache"), "Database-backed cache store"),
      feature("Solid Cable", gems.include?("solid_cable"), "Database-backed Action Cable adapter"),
      feature("Docker", Rails.root.join("Dockerfile").exist?, "Production container build"),
      feature("Kamal", Rails.root.join("config/deploy.yml").exist?, "Container deploy configuration"),
      feature("Rack CORS", gems.include?("rack-cors"), "Cross-origin frontend API access")
    ]
  end

  def feature(name, enabled, purpose)
    { name: name, enabled: enabled, purpose: purpose }
  end

  def route_summary
    @route_summary ||= Rails.application.routes.routes.filter_map do |route|
      verb = route.verb.to_s.delete("^A-Z|")
      path = route.path.spec.to_s.sub("(.:format)", "")
      next if path.start_with?("/rails/")

      controller = route.defaults[:controller]
      action = route.defaults[:action]
      assessment = assess_route(verb, path)

      {
        verb: verb.presence || "ANY",
        path: path,
        target: [controller, action].compact.join("#"),
        level: assessment[:level],
        tone: assessment[:tone],
        reason: assessment[:reason]
      }
    end
  end

  def assess_route(verb, path)
    route = { verb: verb, path: path }
    match = API_RISK_RULES.find { |rule| rule[:matcher].call(route) }
    return match.except(:matcher) if match

    good = GOOD_RULES.find { |rule| rule[:matcher].call(route) }
    return good.except(:matcher) if good

    {
      level: "Normal",
      tone: "neutral",
      reason: "Known framework/app route. Specific issue detected nahi hua."
    }
  end

  def test_summary
    test_files = Dir[Rails.root.join("test/**/*_test.rb")]
    app_files = Dir[Rails.root.join("app/{controllers,models,services}/**/*.rb")]
    assertions = test_files.sum { |file| File.read(file).scan(/^\s*test\s+["']/).count }
    empty_tests = test_files.count { |file| File.read(file).scan(/^\s*test\s+["']/).empty? }
    missing = app_files.filter_map do |file|
      relative = relative_path(file)
      next if matching_test_file(file)

      { path: relative, type: bucket_for(relative), reason: "Matching test file nahi mila." }
    end

    {
      files: test_files.count,
      complete: assertions,
      pending: empty_tests + missing.count,
      empty_files: empty_tests,
      missing_files: missing.count,
      missing: missing,
      status: assertions.positive? ? "Some coverage present" : "No real test cases found"
    }
  end

  def matching_test_file(app_file)
    relative = Pathname.new(app_file).relative_path_from(Rails.root.join("app")).to_s
    base = relative.sub(".rb", "_test.rb")
    [
      Rails.root.join("test", base),
      Rails.root.join("test", base.sub("controllers/", "controllers/")),
      Rails.root.join("test", base.sub("models/", "models/")),
      Rails.root.join("test", base.sub("services/", "services/"))
    ].find(&:exist?)
  end

  def file_inventory
    project_files.map do |relative_path|
      path = Rails.root.join(relative_path)
      content = text_file?(path) ? File.read(path) : ""
      {
        path: relative_path,
        type: bucket_for(relative_path),
        extension: File.extname(relative_path).delete(".").presence || "none",
        lines: content.present? ? content.lines.count : 0,
        size: path.size,
        status: inventory_status(relative_path, content)
      }
    end.sort_by { |file| [file[:type], file[:path]] }
  end

  def project_files
    @project_files ||= Dir[Rails.root.join("**/*")]
      .select { |path| File.file?(path) }
      .map { |path| relative_path(path) }
      .reject { |path| SKIP_DIRS.any? { |dir| path == dir || path.start_with?("#{dir}/") } }
      .sort
  end

  def inventory_status(path, content)
    return "Needs docs" if path == "README.md" && content.include?("This README would normally")
    return "Sensitive config" if path == "config/database.yml" && content.include?("password: root")
    return "Empty test" if path.end_with?("_test.rb") && content.scan(/^\s*test\s+["']/).empty?
    return "Large generated config" if path.include?("doorkeeper.rb") && content.lines.count > 300

    "OK"
  end

  def file_quality
    file_inventory.map do |file|
      path = Rails.root.join(file[:path])
      content = text_file?(path) ? File.read(path) : ""
      score = score_file(file[:path], content, true)
      file.merge(score: score[:score], tone: score[:tone], label: score[:label], notes: score[:notes])
    end
  end

  def score_file(relative_path, content, exists)
    return { score: 0, tone: "risk", label: "Missing", notes: ["File missing hai."] } unless exists

    notes = []
    score = 82

    if relative_path == "README.md" && content.include?("This README would normally")
      score -= 35
      notes << "README abhi default placeholder hai."
    end

    if relative_path.include?("cors.rb") && content.exclude?("Rack::Cors do")
      score -= 25
      notes << "CORS middleware commented hai; frontend calls block ho sakti hain."
    end

    if relative_path.include?("database.yml") && content.include?("password: root")
      score -= 30
      notes << "Database password hardcoded hai."
    end

    if relative_path.include?("users_controller") && content.include?("skip_before_action")
      score -= 15
      notes << "Signup public hai; rate limiting aur request specs useful rahenge."
    end

    if relative_path.include?("application_controller") && content.include?("module Api") && relative_path.exclude?("api/")
      score -= 20
      notes << "Api::ApplicationController file path convention se mismatch hai."
    end

    if relative_path.include?("_test.rb") && content.scan(/^\s*test\s+["']/).empty?
      score -= 45
      notes << "Test file empty hai."
    end

    if content.lines.count > 300
      score -= 8
      notes << "File kaafi large hai; generated/comment-heavy config ho sakta hai."
    end

    notes << "Structure simple aur readable hai." if notes.empty?
    tone = score >= 75 ? "good" : score >= 50 ? "warn" : "risk"
    label = score >= 75 ? "Good" : score >= 50 ? "Needs work" : "Risky"

    { score: score.clamp(0, 100), tone: tone, label: label, notes: notes }
  end

  def database_summary
    ActiveRecord::Base.connection.tables.sort.map do |table|
      columns = ActiveRecord::Base.connection.columns(table)
      {
        name: table,
        columns: columns.count,
        important_columns: columns.map(&:name).grep(/email|password|token|secret|uid|owner|application/).join(", ").presence || "standard columns"
      }
    end
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
    []
  end

  def scenario_map
    [
      scenario("Signup abuse", "High", "POST /api/users spam, fake emails, token farming.", "Rate limiting, request specs, email confirmation ya CAPTCHA add karo."),
      scenario("Token leakage", "High", "Access/refresh tokens plain DB columns mein hain.", "Token hashing options evaluate karo aur logs mein token filter verify karo."),
      scenario("Frontend integration", "Medium", "Rack CORS installed/active nahi hai.", "Allowed frontend origins ke saath CORS enable karo."),
      scenario("Default Devise routes", "Medium", "API-only app mein HTML Devise routes exposed hain.", "Agar custom API auth use karna hai to unused Devise routes restrict karo."),
      scenario("Missing tests", "High", "Current suite 0 assertions run karti hai.", "Signup success/failure, invalid client, token issue aur model validation tests add karo."),
      scenario("Deployment secrets", "Medium", "DB password local config mein hardcoded hai.", "ENV based credentials use karo."),
      scenario("Background jobs", "Low", "Solid Queue installed hai but app jobs empty hain.", "Use nahi hai to okay; future async flows ke liye ready hai."),
      scenario("Documentation drift", "Medium", "README placeholder hai.", "Setup, seed, API examples aur admin dashboard credentials document karo.")
    ]
  end

  def scenario(name, severity, risk, action)
    tone = severity == "High" ? "risk" : severity == "Medium" ? "warn" : "neutral"
    { name: name, severity: severity, tone: tone, risk: risk, action: action }
  end

  def warnings
    items = []
    items << "Real test cases abhi nahi hain." if test_summary[:complete].zero?
    items << "CORS disabled/not installed hai; browser frontend se API call fail ho sakti hai." unless stack.find { |item| item[:name] == "Rack CORS" }[:enabled]
    items << "Database credentials config file mein hardcoded dikh rahe hain." if File.read(Rails.root.join("config/database.yml")).include?("password: root")
    items << "README setup/API documentation missing hai." if File.read(Rails.root.join("README.md")).include?("This README would normally")
    items
  end

  def unused_features
    [
      { name: "Active Storage", status: "Configured", note: "Gem/config present hai, but upload endpoint/model usage nahi mila." },
      { name: "Solid Queue", status: "Installed", note: "Queue adapter available hai, app jobs currently empty hain." },
      { name: "Action Cable", status: "Configured", note: "Cable config present hai, but channels/features nahi bane." },
      { name: "Mailers", status: "Base only", note: "ApplicationMailer exists, custom mail flows abhi nahi." },
      { name: "CORS", status: "Not active", note: "Initializer present hai, middleware commented out hai aur gem bhi commented hai." }
    ]
  end

  def bucket_for(path)
    return "Controller" if path.start_with?("app/controllers/")
    return "Model" if path.start_with?("app/models/")
    return "Service" if path.start_with?("app/services/")
    return "View" if path.start_with?("app/views/")
    return "Config" if path.start_with?("config/")
    return "Database" if path.start_with?("db/")
    return "Test" if path.start_with?("test/")
    return "Script" if path.start_with?("bin/")
    return "Documentation" if path.end_with?(".md")

    "Project"
  end

  def relative_path(path)
    Pathname.new(path).relative_path_from(Rails.root).to_s.tr("\\", "/")
  end

  def text_file?(path)
    return false unless path.exist?

    path.size < 600_000 && !%w[.enc .png .jpg .jpeg .gif .ico].include?(path.extname.downcase)
  end
end
