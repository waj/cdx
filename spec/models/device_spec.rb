require 'spec_helper'

describe Device do
  it { is_expected.to validate_presence_of :device_model }
  it { is_expected.to validate_presence_of :name }
  it { is_expected.to validate_presence_of :institution }

  context 'secret key' do
    let(:device) { Device.new }

    before(:each) do
      expect(MessageEncryption).to receive(:secure_random).and_return('abc')
    end

    it 'should tell plain secret key' do
      device.set_key

      expect(device.plain_secret_key).to eq('abc')
    end

    it 'should store hashed secret key' do
      device.set_key

      expect(device.secret_key_hash).to eq(MessageEncryption.hash 'abc')
    end
  end

  context 'commands' do
    let(:device) { Device.make }

    it "doesn't have pending log requests" do
      expect(device.has_pending_log_requests?).to be(false)
    end

    it "has pending log requests" do
      device.request_client_logs
      expect(device.has_pending_log_requests?).to be(true)

      commands = device.device_commands.all
      expect(commands.count).to eq(1)
      expect(commands[0].name).to eq("send_logs")
      expect(commands[0].command).to be_nil
    end
  end
end
