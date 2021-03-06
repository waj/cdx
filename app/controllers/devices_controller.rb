class DevicesController < ApplicationController
  require 'barby'
  require 'barby/barcode/code_93'
  require 'barby/outputter/html_outputter'

  before_filter :load_institutions, only: [:new, :create, :edit]
  before_filter :load_sites, only: [:new, :create, :edit, :update]
  before_filter :load_institution, only: :create
  before_filter :load_filter_resources, only: :index

  before_filter do
    @main_column_width = 6 unless params[:action] == 'index'
  end

  def index
    return head :forbidden unless can_index_devices?

    @devices = check_access(Device, READ_DEVICE)

    @devices = @devices.where(institution_id: params[:institution].to_i) if params[:institution].presence
    @devices = @devices.where(site_id:  params[:site].to_i)  if params[:site].presence

    @can_create = has_access?(Institution, REGISTER_INSTITUTION_DEVICE)
    @devices_to_read = check_access(Device, READ_DEVICE).pluck(:id)
  end

  def new
    @device = Device.new
    return unless prepare_for_institution_and_authorize(@device, REGISTER_INSTITUTION_DEVICE)
  end

  def create
    return unless authorize_resource(@institution, REGISTER_INSTITUTION_DEVICE)

    @device = @institution.devices.new(device_params)

    # TODO: check valid sites

    respond_to do |format|
      if @device.save
        format.html { redirect_to setup_device_path(@device), notice: 'Device was successfully created.' }
        format.json { render action: 'show', status: :created, location: @device }
      else
        format.html do
          @institutions = check_access(Institution, REGISTER_INSTITUTION_DEVICE)
          render action: 'new'
        end
        format.json { render json: @device.errors, status: :unprocessable_entity }
      end
    end
  end

  def show
    @device = Device.find(params[:id])
    return unless authorize_resource(@device, READ_DEVICE)
    redirect_to setup_device_path(@device) unless @device.activated?
  end

  def setup
    @device = Device.find(params[:id])
    return unless authorize_resource(@device, UPDATE_DEVICE)

    unless @device.secret_key_hash?
      # This is the first time the setup page is displayed (after create)
      # Create a secret key to be shown to the user
      @device.set_key
      @device.new_activation_token
      @device.save!
    end
  end


  def edit
    @device = Device.find(params[:id])
    return unless authorize_resource(@device, UPDATE_DEVICE)

    @uuid_barcode = Barby::Code93.new(@device.uuid)
    @uuid_barcode_for_html = Barby::HtmlOutputter.new(@uuid_barcode)
    # TODO: check valid sites
    @can_regenerate_key = has_access?(@device, REGENERATE_DEVICE_KEY)
    @can_generate_activation_token = has_access?(@device, GENERATE_ACTIVATION_TOKEN)
    @can_delete = has_access?(@device, DELETE_DEVICE)
    @can_support = has_access?(@device, SUPPORT_DEVICE)
  end

  def update
    @device = Device.find(params[:id])
    return unless authorize_resource(@device, UPDATE_DEVICE)

    respond_to do |format|
      if @device.update(device_params)
        format.html { redirect_to devices_path, notice: 'Device was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @device.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @device = Device.find(params[:id])
    return unless authorize_resource(@device, DELETE_DEVICE)

    @device.destroy

    respond_to do |format|
      format.html { redirect_to devices_path, notice: 'Device was successfully deleted.' }
      format.json { head :no_content }
    end
  end

  def regenerate_key
    @device = Device.find(params[:id])
    return unless authorize_resource(@device, REGENERATE_DEVICE_KEY)

    @device.set_key

    respond_to do |format|
      if @device.save
        format.js
        format.json { render json: {secret_key: @device.plain_secret_key }.to_json}
      else
        format.js
        format.json { render json: @device.errors, status: :unprocessable_entity }
      end
    end
  end

  def generate_activation_token
    @device = Device.find(params[:id])
    return unless authorize_resource(@device, GENERATE_ACTIVATION_TOKEN)

    @token = @device.new_activation_token
    respond_to do |format|
      if @token.save
        format.js
        format.json { render action: 'show', location: @device }
      else
        format.js
        format.json { render json: @token.errors, status: :unprocessable_entity }
      end
    end
  end

  def request_client_logs
    @device = Device.find(params[:id])
    return unless authorize_resource(@device, SUPPORT_DEVICE)

    @device.request_client_logs

    redirect_to devices_path, notice: "Client logs requested"
  end

  def custom_mappings
    if params[:device_model_id].blank?
      return render html: ""
    end

    if params[:device_id].present?
      @device = Device.find(params[:device_id])
      return unless authorize_resource(@device, UPDATE_DEVICE)
    else
      @device = Device.new
    end

    @device.device_model = DeviceModel.find(params[:device_model_id])

    render partial: 'custom_mappings'
  end

  private

  def load_institution
    @institution = Institution.find params[:device][:institution_id]
    authorize_resource(@institution, READ_INSTITUTION)
  end

  def load_institutions
    @institutions = check_access(Institution, REGISTER_INSTITUTION_DEVICE)
  end

  def load_sites
    @sites = check_access(Site, ASSIGN_DEVICE_SITE)
    @sites ||= []
  end

  def load_filter_resources
    @institutions, @sites = Policy.condition_resources_for(READ_DEVICE, Device, current_user).values
  end

  def device_params
    params.require(:device).permit(:name, :serial_number, :device_model_id, :time_zone, :site_id).tap do |whitelisted|
      if custom_mappings = params[:device][:custom_mappings]
        whitelisted[:custom_mappings] = custom_mappings.select { |k, v| v.present? }
      end
    end
  end
end
