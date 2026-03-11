#!/usr/bin/env ruby
#
# ByteHide Shield iOS — Xcode project setup
#
# Automatically configures an Xcode project for Shield iOS:
#   1. Detects .xcodeproj
#   2. Asks for projectToken
#   3. Creates shield-ios.json
#   4. Adds shield-ios.json to the Xcode project (file ref + Copy Bundle Resources)
#   5. Adds post-archive action to the scheme
#   6. Shows summary
#
require 'json'
require 'fileutils'

# ── Colors ──────────────────────────────────────────────────────────────────
module Colors
  RED    = "\e[0;31m"
  GREEN  = "\e[0;32m"
  YELLOW = "\e[1;33m"
  CYAN   = "\e[0;36m"
  BOLD   = "\e[1m"
  NC     = "\e[0m"
end

def info(msg);    puts "#{Colors::CYAN}[info]#{Colors::NC}  #{msg}"; end
def success(msg); puts "#{Colors::GREEN}[ok]#{Colors::NC}    #{msg}"; end
def warn(msg);    puts "#{Colors::YELLOW}[warn]#{Colors::NC}  #{msg}"; end

def error(msg)
  puts "#{Colors::RED}[error]#{Colors::NC} #{msg}"
  exit 1
end

# ── 1. Detect .xcodeproj ───────────────────────────────────────────────────
xcodeproj_path = Dir.glob('*.xcodeproj').first
error 'No .xcodeproj found in current directory.' unless xcodeproj_path

project_name = File.basename(xcodeproj_path, '.xcodeproj')
info "Project: #{project_name}"

# ── 2. Ask for projectToken ────────────────────────────────────────────────
puts ''
puts "#{Colors::BOLD}Enter your ByteHide project token#{Colors::NC}"
puts "  Get one at: https://app.bytehide.com"
puts ''
print "  projectToken: "
project_token = $stdin.gets&.strip || ''

if project_token.empty?
  warn 'No token entered. You can add it later in shield-ios.json'
end

# ── 3. Create shield-ios.json ──────────────────────────────────────────────
config_path = 'shield-ios.json'
write_config = true

if File.exist?(config_path)
  warn "#{config_path} already exists."
  print '  Overwrite? (y/N): '
  answer = $stdin.gets&.strip || ''
  if answer.downcase == 'y'
    write_config = true
  else
    write_config = false
    info 'Keeping existing config.'
  end
end

if write_config
  default_config = {
    'projectToken' => project_token.empty? ? 'YOUR_PROJECT_TOKEN' : project_token,
    'protections' => {
      'anti_debug' => true,
      'anti_jailbreak' => {
        'enabled' => true,
        'sensitivity' => 1,
        'exit_on_detect' => true
      },
      'string_encryption' => true,
      'symbol_renaming' => {
        'enabled' => true,
        'prefix' => 'a'
      },
      'swift_stripping' => true,
      'control_flow' => 'light',
      'class_encryption' => true,
      'resource_encryption' => true
    },
    'code_signing' => {
      'skip_if_not_macos' => true
    },
    'build_integration' => {
      'skip_debug' => true,
      'skip_simulator' => true,
      'verbose' => false
    },
    'output' => {
      'suffix' => '_protected'
    }
  }

  File.write(config_path, JSON.pretty_generate(default_config) + "\n")
  success "Created #{config_path}"
end

# ── 4. Add shield-ios.json to Xcode project ────────────────────────────────
info 'Adding shield-ios.json to Xcode project...'

begin
  require 'xcodeproj'

  project = Xcodeproj::Project.open(xcodeproj_path)

  # Find the main app target (first native target that is an application)
  app_target = project.targets.find { |t| t.product_type == 'com.apple.product-type.application' }
  error 'No application target found in project.' unless app_target

  info "Target: #{app_target.name}"

  # Check if file is already referenced
  existing_ref = project.files.find { |f| f.path == 'shield-ios.json' }

  unless existing_ref
    # Add file reference to the main group
    file_ref = project.main_group.new_reference('shield-ios.json')
    file_ref.last_known_file_type = 'text.json'

    # Add to Copy Bundle Resources build phase
    resources_phase = app_target.resources_build_phase
    resources_phase.add_file_reference(file_ref)

    project.save
    success 'Added shield-ios.json to project and Copy Bundle Resources'
  else
    success 'shield-ios.json already in project'
  end
rescue LoadError
  warn 'xcodeproj gem not available — skipping pbxproj modification.'
  warn 'Add shield-ios.json to your project manually in Xcode.'
end

# ── 5. Add post-archive action to scheme ────────────────────────────────────
info 'Configuring post-archive action...'

require 'rexml/document'

# Find shared schemes
shared_schemes_dir = File.join(xcodeproj_path, 'xcshareddata', 'xcschemes')
user_schemes_dir = File.join(xcodeproj_path, 'xcuserdata', "#{ENV['USER']}.xcuserdatad", 'xcschemes')

scheme_path = nil

# Prefer scheme matching the project name, search shared first then user
[shared_schemes_dir, user_schemes_dir].each do |dir|
  next unless File.directory?(dir)

  # First try exact project name match
  candidate = File.join(dir, "#{project_name}.xcscheme")
  if File.exist?(candidate)
    scheme_path = candidate
    break
  end

  # Then try app target name
  if defined?(app_target) && app_target
    candidate = File.join(dir, "#{app_target.name}.xcscheme")
    if File.exist?(candidate)
      scheme_path = candidate
      break
    end
  end

  # Fallback: first .xcscheme found
  first = Dir.glob(File.join(dir, '*.xcscheme')).first
  if first
    scheme_path = first
    break
  end
end

# If no scheme found, create the shared schemes directory and a basic scheme
if scheme_path.nil?
  warn 'No .xcscheme found. Open your project in Xcode first to generate the scheme, then re-run this script.'
  # Try to auto-generate schemes via xcodeproj gem
  begin
    require 'xcodeproj'
    project = Xcodeproj::Project.open(xcodeproj_path) unless defined?(project)
    FileUtils.mkdir_p(shared_schemes_dir)
    project.recreate_user_schemes
    # Check again
    scheme_path = Dir.glob(File.join(shared_schemes_dir, '*.xcscheme')).first
    scheme_path ||= Dir.glob(File.join(user_schemes_dir, '*.xcscheme')).first
    error 'Could not find or create a scheme.' unless scheme_path
    success 'Auto-generated shared scheme'
  rescue LoadError, StandardError => e
    error "No scheme found and cannot auto-create: #{e.message}"
  end
end

info "Scheme: #{File.basename(scheme_path, '.xcscheme')}"

# Parse the scheme XML
scheme_xml = File.read(scheme_path)
doc = REXML::Document.new(scheme_xml)

# Find or create ArchiveAction
archive_action = doc.root.elements['ArchiveAction']
unless archive_action
  archive_action = REXML::Element.new('ArchiveAction')
  archive_action.add_attribute('buildConfiguration', 'Release')
  archive_action.add_attribute('revealArchiveInOrganizer', 'YES')
  doc.root.add_element(archive_action)
end

# Find or create PostActions
post_actions = archive_action.elements['PostActions']
unless post_actions
  post_actions = REXML::Element.new('PostActions')
  archive_action.add_element(post_actions)
end

# Check if our action already exists
shield_action_exists = false
post_actions.each_element('ExecutionAction') do |ea|
  content = ea.elements['ActionContent']
  if content && content.attributes['title'] == 'ByteHide Shield iOS'
    shield_action_exists = true
    break
  end
end

unless shield_action_exists
  # Build the script text
  script_text = 'export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"' + "\n" +
    'shield-ios protect "$ARCHIVE_PATH" -o "$ARCHIVE_PATH" --config "${PROJECT_DIR}/shield-ios.json" --no-sign'

  # Build the BuildableReference from the scheme's BuildAction
  # We need container, identifier, name, and blueprint identifier
  buildable_ref_source = nil
  doc.root.elements.each('BuildAction/BuildActionEntries/BuildActionEntry/BuildableReference') do |br|
    buildable_ref_source = br
    break
  end

  # Create the ExecutionAction element
  exec_action = REXML::Element.new('ExecutionAction')
  exec_action.add_attribute('ActionType',
    'Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction')

  action_content = REXML::Element.new('ActionContent')
  action_content.add_attribute('title', 'ByteHide Shield iOS')
  action_content.add_attribute('scriptText', script_text)
  exec_action.add_element(action_content)

  if buildable_ref_source
    env_buildable = REXML::Element.new('EnvironmentBuildable')
    # Clone the BuildableReference
    br_clone = buildable_ref_source.deep_clone
    env_buildable.add_element(br_clone)
    action_content.add_element(env_buildable)
  end

  post_actions.add_element(exec_action)

  # Write back — use a formatter that preserves Xcode-style XML
  output = String.new
  formatter = REXML::Formatters::Pretty.new(3)
  formatter.compact = true
  formatter.write(doc, output)

  # Ensure XML declaration is present
  unless output.start_with?('<?xml')
    output = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" + output
  end

  File.write(scheme_path, output)

  # Make scheme shared (ensure it's in xcshareddata)
  if scheme_path.include?('xcuserdata')
    FileUtils.mkdir_p(shared_schemes_dir)
    shared_path = File.join(shared_schemes_dir, File.basename(scheme_path))
    FileUtils.cp(scheme_path, shared_path)
    scheme_path = shared_path
    info 'Copied scheme to shared schemes'
  end

  success 'Added post-archive action: "ByteHide Shield iOS"'
else
  success 'Post-archive action already configured'
end

# ── 6. Summary ──────────────────────────────────────────────────────────────
puts ''
puts "#{Colors::BOLD}╔══════════════════════════════════════╗#{Colors::NC}"
puts "#{Colors::BOLD}║   Setup complete!                    ║#{Colors::NC}"
puts "#{Colors::BOLD}╚══════════════════════════════════════╝#{Colors::NC}"
puts ''
puts "  #{Colors::GREEN}✓#{Colors::NC} shield-ios.json created"
puts "  #{Colors::GREEN}✓#{Colors::NC} Added to Xcode project"
puts "  #{Colors::GREEN}✓#{Colors::NC} Post-archive action configured"
puts ''
puts '  Next steps:'
puts ''
if project_token.empty? || project_token == 'YOUR_PROJECT_TOKEN'
  puts "  1. Edit #{Colors::BOLD}shield-ios.json#{Colors::NC} and set your projectToken"
  puts '  2. Customize protections as needed'
  puts "  3. Archive your app (#{Colors::BOLD}Product > Archive#{Colors::NC}) — Shield runs automatically"
else
  puts "  1. Customize protections in #{Colors::BOLD}shield-ios.json#{Colors::NC} as needed"
  puts "  2. Archive your app (#{Colors::BOLD}Product > Archive#{Colors::NC}) — Shield runs automatically"
end
puts ''
puts "  Verify: #{Colors::BOLD}Edit Scheme > Archive > Post-actions#{Colors::NC}"
puts "  Docs:   https://docs.bytehide.com/platforms/ios/products/shield"
puts ''
