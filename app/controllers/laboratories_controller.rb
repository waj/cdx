class LaboratoriesController < ApplicationController
  set_institution_tab :laboratories
  before_filter :load_institutions

  def index
    @laboratories = check_access(Laboratory, READ_LABORATORY)
    @institutions = check_access(Institution, READ_INSTITUTION)
    @can_create = has_access?(@institutions, CREATE_INSTITUTION_LABORATORY)

    if (institution_id = params[:institution].presence)
      @laboratories = @laboratories.where(institution_id: institution_id.to_i)
    end

    @labs_to_edit = check_access(@laboratories, UPDATE_LABORATORY).pluck(:id)
  end

  def new
    @main_column_width = 6
    @laboratory = Laboratory.new
    prepare_for_institution_and_authorize(@laboratory, CREATE_INSTITUTION_LABORATORY)
  end

  # POST /laboratories
  # POST /laboratories.json
  def create
    @main_column_width = 6
    @institution = Institution.find params[:laboratory][:institution_id]
    return unless authorize_resource(@institution, CREATE_INSTITUTION_LABORATORY)

    @laboratory = @institution.laboratories.new(laboratory_params)

    respond_to do |format|
      if @laboratory.save
        format.html { redirect_to laboratories_path, notice: 'Laboratory was successfully created.' }
        format.json { render action: 'show', status: :created, location: @laboratory }
      else
        format.html { render action: 'new' }
        format.json { render json: @laboratory.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @main_column_width = 6
    @laboratory = Laboratory.find(params[:id])
    return unless authorize_resource(@laboratory, UPDATE_LABORATORY)

    @can_delete = has_access?(@laboratory, DELETE_LABORATORY)
  end

  # PATCH/PUT /laboratories/1
  # PATCH/PUT /laboratories/1.json
  def update
    @main_column_width = 6
    @laboratory = Laboratory.find params[:id]
    return unless authorize_resource(@laboratory, UPDATE_LABORATORY)

    respond_to do |format|
      if @laboratory.update(laboratory_params)
        format.html { redirect_to laboratories_path, notice: 'Laboratory was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @laboratory.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /laboratories/1
  # DELETE /laboratories/1.json
  def destroy
    @laboratory = Laboratory.find params[:id]
    return unless authorize_resource(@laboratory, DELETE_LABORATORY)

    @laboratory.destroy

    respond_to do |format|
      format.html { redirect_to laboratories_path, notice: 'Laboratory was successfully deleted.' }
      format.json { head :no_content }
    end
  end

  private

  def load_institutions
    @institutions = check_access(Institution, CREATE_INSTITUTION_LABORATORY)
  end

  def laboratory_params
    params.require(:laboratory).permit(:name, :address, :city, :state, :zip_code, :country, :region, :lat, :lng, :location_geoid)
  end
end
