require "spec_helper"

require "rack/test"

RSpec.describe "login API endpoint" do
  include Rack::Test::Methods

  describe "POST /login" do
    context "invalid credentials" do
      before do
        post "/login", JSON.generate({user: "foo", password: "bar"})
      end

      it "returns 401 Unauthorized" do
        expect(last_status).to eq 401
      end
    end

    context "valid user credentials" do
      before do
        post "/login", JSON.generate({user: "user", password: "user123"})
      end

      it "returns 200 Ok" do
        expect(last_status).to eq 200
      end

      it "returns a JSON object containing the role of the user" do
        expect(json_response["role"]).to eq "user"
      end
    end

    context "valid admin credentials" do
      before do
        post "/login", JSON.generate({user: "admin", password: "admin123"})
      end

      it "returns 200 Ok" do
        expect(last_status).to eq 200
      end

      it "returns a JSON object containing the role of the user" do
        expect(json_response["role"]).to eq "admin"
      end
    end
  end
end
