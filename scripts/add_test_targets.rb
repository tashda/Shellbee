#!/usr/bin/env ruby
# Adds ShellbeeTests (unit) and ShellbeeUITests (UI) targets to the Xcode project
# using PBXFileSystemSynchronizedRootGroup so that new test files are auto-discovered.
#
# Usage: ruby scripts/add_test_targets.rb

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../Shellbee.xcodeproj', __dir__)
ROOT         = File.expand_path('..', __dir__)

project = Xcodeproj::Project.open(PROJECT_PATH)

if project.targets.any? { |t| t.name == 'ShellbeeTests' }
  puts 'ShellbeeTests already exists — skipping.'
  exit 0
end

app_target = project.targets.find { |t| t.name == 'Shellbee' }
raise 'Could not find Shellbee target' unless app_target

# ── Shared build settings ─────────────────────────────────────────────────

COMMON = {
  'SWIFT_VERSION'                              => '6.0',
  'IPHONEOS_DEPLOYMENT_TARGET'                 => '26.0',
  'GENERATE_INFOPLIST_FILE'                    => 'YES',
  'SWIFT_APPROACHABLE_CONCURRENCY'             => 'YES',
  'SWIFT_DEFAULT_ACTOR_ISOLATION'              => 'MainActor',
  'SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY' => 'YES',
  'TARGETED_DEVICE_FAMILY'                     => '1,2',
  'CODE_SIGN_STYLE'                            => 'Automatic',
  'DEVELOPMENT_TEAM'                           => 'JQU2HR44D8',
}.freeze

# ── Helper: add a PBXFileSystemSynchronizedRootGroup ─────────────────────

def add_synced_group(project, folder_name)
  grp = project.new(Xcodeproj::Project::Object::PBXFileSystemSynchronizedRootGroup)
  grp.path         = folder_name
  grp.source_tree  = '<group>'
  project.main_group.children << grp
  grp
end

# ── ShellbeeTests (unit + integration) ───────────────────────────────────

unit_target = project.new_target(:unit_test_bundle, 'ShellbeeTests', :ios, '26.0')

unit_target.build_configurations.each do |cfg|
  cfg.build_settings.merge!(COMMON)
  cfg.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'dev.echodb.shellbee.tests'
  cfg.build_settings['TEST_HOST'] =
    '$(BUILT_PRODUCTS_DIR)/Shellbee.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Shellbee'
  cfg.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
end

unit_group = add_synced_group(project, 'ShellbeeTests')
unit_target.file_system_synchronized_groups << unit_group
unit_target.add_dependency(app_target)

# ── ShellbeeUITests ───────────────────────────────────────────────────────

ui_target = project.new_target(:ui_test_bundle, 'ShellbeeUITests', :ios, '26.0')

ui_target.build_configurations.each do |cfg|
  cfg.build_settings.merge!(COMMON)
  cfg.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'dev.echodb.shellbee.uitests'
  cfg.build_settings['TEST_TARGET_NAME']           = 'Shellbee'
end

ui_group = add_synced_group(project, 'ShellbeeUITests')
ui_target.file_system_synchronized_groups << ui_group
ui_target.add_dependency(app_target)

# ── Save ──────────────────────────────────────────────────────────────────

project.save
puts 'Done. Added ShellbeeTests and ShellbeeUITests targets.'
