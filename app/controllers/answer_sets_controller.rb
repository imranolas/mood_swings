class AnswerSetsController < ApplicationController
  load_and_authorize_resource

  # GET /answer_sets
  # GET /answer_sets.json
  def index
    if current_user.admin?
      @answer_sets = AnswerSet.scoped
    else
      @answer_sets = current_user.answer_sets
    end

    if params[:from_date].present?
      @answer_sets = @answer_sets.where("created_at >= ?", params[:from_date])
    end
    if params[:to_date].present?
      @answer_sets = @answer_sets.where("created_at <= ?", params[:to_date])
    end


    # setup the core query of the answer_set data
    @answer_sets = @answer_sets.select('avg(answers.value) as value').joins(:answers)


    # set the granularity of the data as required
    @answer_sets = case params[:granularity].to_s.downcase
      when 'person'
        # remove the granularity of seeing the individual metric - instead, show each user's average for the set
        @answer_sets.select('answer_sets.user_id as metric_id, answer_sets.user_id as user_id').group('answer_sets.user_id')

      when 'class'
        authorize! :granularity_by_class, AnswerSet
        @answer_sets.select("'class' as metric_id, 'class' as user_id")

      else
        # default to grouping as finely-grained as possible - right down to the individual metric
        @answer_sets.select('answers.metric_id as metric_id, answer_sets.user_id as user_id').group('answers.metric_id, answer_sets.user_id')
    end


    # group the data into days/weeks if required
    @answer_sets = case params[:group].to_s.downcase
      when 'day'
        @xlabels = 'day'
        @answer_sets.select('DATE(answer_sets.created_at) as created_at').group('DATE(answer_sets.created_at)')

      when 'week'
        @xlabels = 'day'
        @answer_sets.select('EXTRACT(YEAR FROM answer_sets.created_at)::text || EXTRACT(WEEK FROM answer_sets.created_at)::text as created_at').group('EXTRACT(YEAR FROM answer_sets.created_at)::text || EXTRACT(WEEK FROM answer_sets.created_at)::text')

      else
        @answer_sets.select('answer_sets.created_at as created_at').group('answer_sets.created_at')
    end


    @data = chart_data(@answer_sets)
    @keys = chart_data_keys(@answer_sets)

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @answer_sets }
    end
  end

  # GET /answer_sets/1
  # GET /answer_sets/1.json
  def show
    @answer_set = AnswerSet.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @answer_set }
    end
  end

  # GET /answer_sets/new
  # GET /answer_sets/new.json
  def new
    @answer_set = AnswerSet.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @answer_set }
    end
  end

  # GET /answer_sets/1/edit
  def edit
    @answer_set = AnswerSet.find(params[:id])
  end

  # POST /answer_sets
  # POST /answer_sets.json
  def create
    @answer_set = AnswerSet.new(params[:answer_set])
    @answer_set.user = current_user
    
    respond_to do |format|
      if @answer_set.save
        format.html { redirect_to home_path, notice: 'Answer set was successfully created.' }
        format.json { render json: @answer_set, status: :created, location: @answer_set }
      else
        format.html { render "pages/home" }
        format.json { render json: @answer_set.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /answer_sets/1
  # PUT /answer_sets/1.json
  def update
    @answer_set = AnswerSet.find(params[:id])

    respond_to do |format|
      if @answer_set.update_attributes(params[:answer_set])
        format.html { redirect_to @answer_set, notice: 'Answer set was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @answer_set.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /answer_sets/1
  # DELETE /answer_sets/1.json
  def destroy
    @answer_set = AnswerSet.find(params[:id])
    @answer_set.destroy

    respond_to do |format|
      format.html { redirect_to answer_sets_url }
      format.json { head :no_content }
    end
  end


  private
  def chart_data(data)
    data.map do |datum|
      { 
        :timestamp => datum.created_at.strftime('%Y-%m-%d %H:%M:%S'),
        "#{datum.user_id}##{datum.metric_id}" => datum.value
      }
    end
  end

  private
  def chart_data_keys(data)
    data.map do |datum|
      datum.user_id.to_s + '#' + datum.metric_id.to_s
    end
  end




end
