require 'spec_helper'

# Override the API with test API
require_relative '../services/plan_service/api/api'

describe CurrentMarketplaceAppender do
  let(:app) { ->(env) {['200', {'Content-Type' => 'text/plain'}, [env.to_json]]} }
  let(:request) { Rack::MockRequest.new(CurrentMarketplaceAppender.new(app))}

  describe "current_marketplace" do
    it 'gets the right community by subdomain' do
      c1 = FactoryGirl.create(:community, :ident => 'test23')
      c2 = FactoryGirl.create(:community, :domain => 'test23.custom.org')
      r = request.get 'https://test23.lvh.me', {'HTTP_HOST' => 'test23.lvh.me'}
      expect(JSON.parse(r.body)["current_marketplace"]["id"]).to eq(c1.id)
    end

    it 'gets the right community by full domain even when matching subdomain exists' do
      c1 = FactoryGirl.create(:community, :ident => 'market')
      c2 = FactoryGirl.create(:community, :domain => 'market.custom.org')
      r = request.get 'https://market.custom.org', {'HTTP_HOST' => 'market.custom.org'}
      expect(JSON.parse(r.body)["current_marketplace"]["id"]).to eq(c2.id)
    end
  end

  describe "current_plan" do
    before(:each) {
      PlanService::API::Api.reset!
    }

    let(:plans_api) {
      PlanService::API::Api.set_environment(active: true)
      PlanService::API::Api.plans
    }

    it 'it adds the right plan' do
      com = FactoryGirl.create(:community, :domain => 'market.custom.org')

      plans_api.create_initial_trial(
        community_id: com.id, plan: {
          status: :trial,
          expires_at: 1.month.from_now
        })

      r = request.get 'https://market.custom.org', {'HTTP_HOST' => 'market.custom.org'}
      expect(JSON.parse(r.body)["current_plan"])
        .to include(
              "community_id" => com.id,
              "status" => "trial",
            )
    end

    it "leaves current_plan nil if the marketplace doesn't exist" do
      com = FactoryGirl.create(:community, :domain => 'market.custom.org')

      plans_api.create_initial_trial(
        community_id: com.id, plan: {
          status: :trial,
          expires_at: 1.month.from_now
        })

      r = request.get 'https://non-existing-market.custom.org', {'HTTP_HOST' => 'non-existing-market.custom.org'}
      expect(JSON.parse(r.body)["current_plan"]).to eq(nil)
    end
  end

  describe "no_marketplaces" do
    before(:each) {
      Community.destroy_all
    }

    it "sets no_marketplaces to true, if there are no marketplaces" do
      r = request.get 'https://non-existing-market.custom.org', {'HTTP_HOST' => 'non-existing-market.custom.org'}
      expect(JSON.parse(r.body)["no_marketplaces"]).to eq(true)
    end

    it "sets no_marketplaces to false, if marketplaces do exist" do
      com = FactoryGirl.create(:community, :domain => 'market.custom.org')

      r = request.get 'https://non-existing-market.custom.org', {'HTTP_HOST' => 'non-existing-market.custom.org'}
      expect(JSON.parse(r.body)["no_marketplaces"]).to eq(false)
    end
  end

end
