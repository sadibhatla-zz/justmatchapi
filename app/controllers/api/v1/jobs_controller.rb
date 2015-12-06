class Api::V1::JobsController < ApplicationController
  before_action :set_job, only: [:show, :edit, :update, :destroy, :matching_users]

  api :GET, '/jobs', 'List jobs'
  description 'Returns a list of jobs.'
  formats ['json']
  def index
    @jobs = Job.all
    render json: @jobs
  end

  api :GET, '/jobs/:id', 'Show job'
  description 'Return job.'
  formats ['json']
  def show
    render json: @job
  end

  api :POST, '/jobs/', 'Create new job'
  description 'Creates and returns new job.'
  formats ['json']
  param :job, Hash, desc: 'Job attributes', required: true do
    param :skills, Array, of: Integer, desc: 'List of skill ids', required: true
    param :max_rate, Integer, desc: 'Max rate', required: true
    param :name, String, desc: 'Name', required: true
    param :description, String, desc: 'Description', required: true
    param :job_date, String, desc: 'Job date', required: true
    param :performed, [true, false], desc: 'Performed'
    param :owner_user_id, Integer, desc: 'User id for the job owner', required: true
  end
  def create
    @job = Job.new(job_params)
    @job.owner_user_id = current_user.id

    if @job.save
      @job.skills = Skill.where(id: params[:job][:skills])

      owner = @job.owner
      User.matches_job(@job).each do |user|
        UserJobMatchNotifier.call(user: user, job: @job, owner: owner)
      end

      render json: @job, include: ['skills'], status: :created
    else
      render json: @job.errors, status: :unprocessable_entity
    end
  end

  api :PATCH, '/jobs/:id', 'Update job'
  description 'Updates and returns the updated job.'
  formats ['json']
  param :job, Hash, desc: 'Job attributes', required: true do
    param :max_rate, Integer, desc: 'Max rate'
    param :name, String, desc: 'Name'
    param :description, String, desc: 'Description'
    param :job_date, String, desc: 'Job date'
    param :performed, [true, false], desc: 'Performed'
    param :owner_user_id, Integer, desc: 'User id for the job owner'
  end
  def update
    unless @job.owner == current_user
      render json: { error: 'Not authed.' }, status: 401
      return
    end

    @job.assign_attributes(job_params)

    should_notify = @job.send_performed_notice?

    if @job.save
      JobPerformedNotifier.call(job: @job) if should_notify
      render json: @job, status: :ok
    else
      render json: @job.errors, status: :unprocessable_entity
    end
  end

  api :DELETE, '/jobs/:id', 'Delete job'
  description 'Deletes job if the user is allowed to.'
  formats ['json']
  def destroy
    unless @job.owner == current_user
      render json: { error: 'Not authed.' }, status: 401
      return
    end

    @job.destroy

    head :no_content
  end

  api :GET, '/jobs/:job_id/matching_users', 'Show matching users for job'
  description 'Returns matching users for job if user is allowed to.'
  formats ['json']
  def matching_users
    unless @job.owner == current_user
      render json: { error: 'Not authed.' }, status: 401
      return
    end

    render json: User.matches_job(@job)
  end

  private

    def set_job
      @job = Job.find(params[:job_id])
    end

    def job_params
      params.require(:job).permit(:max_rate, :description, :job_date, :performed, :address, :name)
    end
end
