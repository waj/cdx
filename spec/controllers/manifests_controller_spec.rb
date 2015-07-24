require 'spec_helper'

describe ManifestsController do
  let(:user) {User.make}
  before(:each) {sign_in user}

  context "Creation" do

    it "shouldn't create if JSON is not valid" do
      json = {"definition" => %{
        { , , }
      } }
      Manifest.count.should eq(0)
      post :create, manifest: json
      Manifest.count.should eq(0)
    end

    it "should create if is a valid manifest" do
      json = {"definition" => %{{
        "metadata": {
          "version" : "1.0.0",
          "api_version" : "#{Manifest::CURRENT_VERSION}",
          "device_models" : ["GX4001"],
          "conditions": ["MTB"],
          "source" : { "type" : "json" }
        },
        "field_mapping": {
          "test.assay_name" : {"lookup" : "Test.assay_name"},
          "test.type" : {
            "mapping" : [
              {"lookup" : "Test.test_type"},
              [
                {"match" : "*QC*", "output" : "qc"},
                {"match" : "*Specimen*", "output" : "specimen"}
              ]
            ]
          }
        }
      }}}
      Manifest.count.should eq(0)
      post :create, manifest: json
      Manifest.count.should eq(1)
    end
  end
end


