class InstitutionsController < ApplicationController
  layout "institutions", except: [:index, :new]
  layout "application", only: [:index, :new]

  add_breadcrumb 'Institutions', :institutions_path

  expose(:institutions) { current_user.visible_institutions }
  expose(:institution, attributes: :institution_params)

  before_action :check_institution_admin, only: [:update, :destroy]

  def index
  end

  def new
    set_institution_tab :new
  end

  def show
    add_breadcrumb institution.name, institution
    add_breadcrumb 'Overview'
    set_institution_tab :overview
  end

  def edit
    add_breadcrumb institution.name, institution
    add_breadcrumb 'Settings'
    set_institution_tab :settings
  end

  def create
    respond_to do |format|
      if current_user.create(institution)
        format.html { redirect_to institution, notice: 'Institution was successfully created.' }
        format.json { render action: 'show', status: :created, location: institution }
      else
        format.html { render action: 'new' }
        format.json { render json: institution.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if institution.update(institution_params)
        format.html { redirect_to institution, notice: 'Institution was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: institution.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    institution.destroy
    respond_to do |format|
      format.html { redirect_to institutions_url }
      format.json { head :no_content }
    end
  end

  private

  def institution_params
    params.require(:institution).permit(:name)
  end
end
