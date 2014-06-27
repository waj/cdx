require 'spec_helper'

describe ApiController do
  let(:device) {Device.make}
  let(:institution) {device.institution}
  let(:data) {Oj.dump result: :positive}

  def get_all_elasticsearch_events
    client = Elasticsearch::Client.new log: true
    client.indices.refresh index: institution.elasticsearch_index_name
    client.search(index: institution.elasticsearch_index_name)["hits"]["hits"].first["_source"]
  end

  context "Creation" do
    it "should create event in the database" do
      conn = post :create, data, device_uuid: device.secret_key
      conn.status.should eq(200)

      event = Event.first
      event.device_id.should eq(device.id)
      event.raw_data.should_not eq(data)
      event.decrypt.raw_data.should eq(data)
    end

    it "should create event in elasticsearch" do
      post :create, data, device_uuid: device.secret_key

      event = get_all_elasticsearch_events
      event["result"].should eq("positive")
      event["created_at"].should_not eq(nil)
      event["device_uuid"].should eq(device.secret_key)
      Event.first.uuid.should eq(event["uuid"])
    end
  end

  context "Manifest" do
    it "shouldn't store sensitive data in elasticsearch" do
      post :create, Oj.dump(result: :positive, patient_id: 1234), device_uuid: device.secret_key

      event = get_all_elasticsearch_events
      event["result"].should eq("positive")
      event["created_at"].should_not eq(nil)
      event["patient_id"].should eq(nil)
    end

    it "applies an existing manifest" do
      Manifest.create definition: %{{
        "metadata" : {
          "device_models" : ["#{device.device_model.name}"],
          "version" : 1
        },
        "field_mapping" : [{
            "target_field" : "assay_name",
            "selector" : "assay/name",
            "type" : "core"
          }]
      }}
      post :create, Oj.dump(assay: {name: "GX4002"}, patient_id: 1234), device_uuid: device.secret_key

      event = get_all_elasticsearch_events
      event["assay_name"].should eq("GX4002")
      event["created_at"].should_not eq(nil)
      event["patient_id"].should be(nil)
    end

    it "stores pii according to manifest" do
      Manifest.create definition: %{{
        "metadata" : {
          "device_models" : ["#{device.device_model.name}"],
          "version" : 1
        },
        "field_mapping" : [
          {
            "target_field": "assay_name",
            "selector" : "assay/name",
            "type" : "core"
          },
          {
            "target_field": "foo",
            "selector" : "patient_id",
            "type" : "custom",
            "pii": true
          }
        ]
      }}

      post :create, Oj.dump(assay: {name: "GX4002"}, patient_id: 1234), device_uuid: device.secret_key

      event = get_all_elasticsearch_events
      event["assay_name"].should eq("GX4002")
      event["patient_id"].should eq(nil)
      event["foo"].should be(nil)

      event = Event.first
      raw_data = event.sensitive_data
      event.decrypt.sensitive_data.should_not eq(raw_data)
      event.sensitive_data["patient_id"].should be(nil)
      event.sensitive_data["foo"].should eq(1234)
    end

    it "uses the last version of the manifest" do
      Manifest.create definition: %{{
        "metadata" : {
          "device_models" : ["#{device.device_model.name}"],
          "version" : 1
        },
        "field_mapping" : [
          {
            "target_field": "foo",
            "selector" : "assay/name",
            "type" : "core"
          }
        ]
      }}

      Manifest.create definition: %{{
        "metadata" : {
          "device_models" : ["#{device.device_model.name}"],
          "version" : 2
        },
        "field_mapping" : [
          {
            "target_field": "assay_name",
            "selector" : "assay/name",
            "type" : "core"
          }
        ]
      }}

      post :create, Oj.dump(assay: {name: "GX4002"}, patient_id: 1234), device_uuid: device.secret_key

      event = get_all_elasticsearch_events
      event["foo"].should be(nil)
      event["assay_name"].should eq("GX4002")
    end

    it "stores custom fields according to the manifest" do
      Manifest.create definition: %{{
        "metadata" : {
          "device_models" : ["#{device.device_model.name}"],
          "version" : 2
        },
        "field_mapping" : [
          {
            "target_field": "foo",
            "selector" : "some_field",
            "type" : "custom",
            "pii": false,
            "indexed": false
          }
        ]
      }}

      post :create, Oj.dump(some_field: 1234), device_uuid: device.secret_key

      event = get_all_elasticsearch_events
      event["foo"].should be(nil)

      event = Event.first.decrypt
      event.sensitive_data["some_field"].should be(nil)
      event.sensitive_data["foo"].should be(nil)
      event.custom_fields["foo"].should eq(1234)
    end
  end

  context "locations" do
    let(:root_location) {Location.make}
    let(:parent_location) {Location.make parent: root_location}
    let(:leaf_location1) {Location.make parent: parent_location}
    let(:leaf_location2) {Location.make parent: parent_location}
    let(:upper_leaf_location) {Location.make parent: root_location}
    let(:laboratory1) {Laboratory.make institution: institution, location: leaf_location1}
    let(:laboratory2) {Laboratory.make institution: institution, location: leaf_location2}
    let(:laboratory3) {Laboratory.make institution: institution, location: upper_leaf_location}

    it "should store the location id when the device is registered in only one laboratory" do
      device.laboratories = [laboratory1]
      device.save!
      post :create, data, device_uuid: device.secret_key

      event = get_all_elasticsearch_events
      event["location_id"].should eq(leaf_location1.id)
      event["laboratory_id"].should eq(laboratory1.id)
      event["parent_locations"].sort.should eq([leaf_location1.id, parent_location.id, root_location.id].sort)
    end

    it "should store the parent location id when the device is registered more than one laboratory" do
      device.laboratories = [laboratory2, laboratory3]
      device.save!

      post :create, data, device_uuid: device.secret_key

      event = get_all_elasticsearch_events
      event["location_id"].should eq(root_location.id)
      event["laboratory_id"].should be(nil)
      event["parent_locations"].should eq([root_location.id])
    end

    it "should store the parent location id when the device is registered more than one laboratory with another tree order" do
      device.laboratories = [laboratory3, laboratory2]
      device.save!

      post :create, data, device_uuid: device.secret_key

      event = get_all_elasticsearch_events
      event["location_id"].should eq(root_location.id)
      event["laboratory_id"].should be(nil)
      event["parent_locations"].should eq([root_location.id])
    end

    it "should store nil if no location was found" do
      device.laboratories = []
      device.save!

      post :create, data, device_uuid: device.secret_key

      event = get_all_elasticsearch_events
      event["location_id"].should be(nil)
      event["laboratory_id"].should be(nil)
      event["parent_locations"].should eq([])
    end
  end
end
