require 'test_helper'

module Ekylibre
  class FirstRunTest < Ekylibre::Testing::ApplicationTestCase::WithFixtures
    teardown do
      Ekylibre::Tenant.switch!('test')
    end

    setup do
      Rails.application.load_tasks
    end

    test 'launch of default first run' do
      tenant = 'test_default'
      Ekylibre::Tenant.drop(tenant) if Ekylibre::Tenant.exist?(tenant)
      ::Rake::Task['first_run:default:generate'].invoke
      Ekylibre::FirstRun.launch(name: tenant, path: Ekylibre::FirstRun.path.join('default'), verbose: false)
    end

    # test "launch of test first run" do
    #   Ekylibre::FirstRun.launch(path: Rails.root.join("test", "fixtures", "files", "first_run"), name: :sekindov)
    # end
  end
end
