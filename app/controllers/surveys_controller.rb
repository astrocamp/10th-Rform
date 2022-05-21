# frozen_string_literal: true

class SurveysController < ApplicationController
  before_action :find_survey, except: %i[index new create tag]

  def index
    @surveys = current_user.surveys
  end

  def show; end

  def new
    @survey = Survey.new
  end

  def edit
    question = @survey.questions.order(:position)
  end

  def create
    @survey = current_user.surveys.new(survey_params)

    if @survey.save
      render :edit
    else
      render :new
    end
  end

  def update
    @survey.update(survey_params)
  end

  def destroy
    @survey.destroy
    redirect_to surveys_path, notice: '問卷已刪除'
  end

  def duplicate_survey
    dup = @survey.deep_clone include: {questions: :answers }
    dup.title.insert(-1, " - 副本")
    if dup.save
      redirect_to surveys_path, notice: '問卷已複製成功'
    end
  end

  def duplicate_question
    if params[:question_id] != ''
      question = @survey.questions.find(params[:question_id]).deep_clone include: :answers
    else
      question = @survey.questions.find_by(timestamp: params[:question_timestamp]).deep_clone include: :answers
    end
    question.update(title: question.title.insert(-1," - 副本"),position: (question.position)+1)
    question.save
    new_question = @survey.questions.last
    result = [ new_question, new_question.answers]
    render json:  result
  end
  
  def stats
    questions_count = @survey.questions.count
    question_index = 0
    question_ids = []
    question_titles = []
    question_types = []
    answer_index = 0
    max_answers_count = 0
    answer_ids = []
    answer_titles = []
    answer_question_ids = []
    question_answer_data = []
    response_answer_data = []
    response_answer_ids = []
    answers_counts = [0]

  
    # combine question and answers
    @survey.questions.each do |question|
      question_ids[question_index] = question.id
      question_titles[question_index] = question.title
      question_types[question_index] = question.question_type

      answers_count = 0
      question.answers.each do |answer|
        answer_ids[answer_index] = answer.id
        answer_titles[answer_index] = answer.title
        answer_question_ids[answer_index] = answer.question_id
        if answer_question_ids[answer_index] == question_ids[question_index]
          answers_count += 1
        end
        answer_index += 1
      end
      question_index += 1
      answers_counts.push(answers_count)
    end
    max_answers_count = answer_index
  
    # deal with responses  
    responses_count = @survey.responses.count
    response_index = 0
    response_json = []
    response_id = []
    response_answers = []

    @survey.responses.all.each do |response|
      response_json[response_index] = response.as_json(only: [:id, :answers])
      response_id[response_index] = response_json[response_index]['id']
      response_answers[response_index] = response_json[response_index]['answers']

      question_index = 0
      while question_index < questions_count
        question_id_string = question_ids[question_index].to_s
        current_response_answers = response_answers[response_index][question_id_string]

        # 改switch case
        if question_types[question_index] == 'multiple_choice'
          current_response_answers.delete('0')
          current_response_answers.each do |current_response_answer|
            answer_index = 0
            while answer_index < max_answers_count
              if current_response_answer == answer_ids[answer_index].to_s
                response_answer_data.push(answer_titles[answer_index])
                response_answer_ids.push(answer_ids[answer_index])
              end
              answer_index += 1
            end
          end
        end
        if question_types[question_index] == 'single_choice'
          answer_index = 0
          while answer_index < max_answers_count
            if current_response_answers == answer_ids[answer_index].to_s
              response_answer_data.push(answer_titles[answer_index])
            end
            answer_index += 1
          end
        end
        if question_types[question_index] == 'long_answer'
          response_answer_data.push(current_response_answers)
        end

        question_index += 1
      end

      response_answer_data.push('===========================')
    end

    sum_of_response_answer_ids = []

    answer_ids.each do |answer_id|
      sum_of_response_answer_ids.push(response_answer_ids.count(answer_id))
    end

    @responsesCount = responses_count
    @responseAnswerDatas = response_answer_data

    # create charts
    chart_index = 0
    slice_from = 0
    chart_types = []
    chart_datas = []
    chart_options = []
    @survey.questions.each do |question|
      slice_from += answers_counts[chart_index]
      slice_length = answers_counts[chart_index+1]  

      chart_types[chart_index] = 'bar'
      chart_datas[chart_index] = {
        labels: answer_titles.slice(slice_from, slice_length),
        datasets: [{
          label: question.title,
          backgroundColor: '#3B82F6',
          borderColor: '#3B82F6',
          data: sum_of_response_answer_ids.slice(slice_from, slice_length)
        }]
      }

      chart_options[chart_index] = {
        layout: {
          padding: 200
        }
      }   
      
      chart_index += 1
    end
    @chart_types = chart_types
    @chart_datas = chart_datas
    @chart_options = chart_options
  end

  def tag
    @survey = current_user.surveys.find(params[:survey_id])
    @survey.update(tag: params[:survey][:tag])
    redirect_to surveys_path(survey)
  end

  def sort
    @survey.insert_at(params[:newIndex].to_i)
  end

  def question_sort
    @question = @survey.questions.find(params[:question_id])
    @question.insert_at(params[:newIndex].to_i)
  end

  def survey_title
    @survey.update(title: params[:survey_title])
  end

  def survey_description
    @survey.update(description: params[:survey_description])
  end

  def add_question
    if params[:timestamp]
      if @survey.questions.find_by(timestamp: params[:timestamp])
        @question = @survey.questions.find_by(timestamp: params[:timestamp])
        @question.update(title: params[:question_value])
      else
        @question = @survey.questions.create
        @question.update(timestamp: params[:timestamp],title: params[:question_value])
      end
    else 
      @question = @survey.questions.find(params[:question_id])
      @question.update(title: params[:question_value])
    end
  end

  def save_checkbox
    if params[:timestamp]
      if @survey.questions.find_by(timestamp: params[:timestamp])
        @question = @survey.questions.find_by(timestamp: params[:timestamp])
        @question.update(required: !@question.required)
      else
        @question = @survey.questions.create
        @question.update(timestamp: params[:timestamp],required: !@question.required)
      end
    else 
      @question = @survey.questions.find(params[:question_id])
      @question.update(required: !@question.required)
    end
  end

  def add_answer
    if params[:timestamp]
      if @survey.questions.find_by(timestamp: params[:timestamp])
        @question = @survey.questions.find_by(timestamp: params[:timestamp])
        answer = @question.answers.create(title: params[:answer_value]) 
      else
        @question = @survey.questions.create
        @question.update(timestamp: params[:timestamp])
        answer = @question.answers.create(title: params[:answer_value]) 
      end
    elsif params[:question_id]
      @question = @survey.questions.find(params[:question_id])
      if params[:answer_timestamp]
        answer = @question.answers.create
        answer.update(timestamp: params[:answer_timestamp],title: params[:answer_value])
      elsif params[:answer_id]
        answer = @question.answers.find(params[:answer_id])
        answer.update(title: params[:answer_value])
      end
    end
  end

  def update_select
    if params[:timestamp]
      if @survey.questions.find_by(timestamp: params[:timestamp])
        @question = @survey.questions.find_by(timestamp: params[:timestamp])
        @question.update(question_type: params[:select])
      else
        @question = @survey.questions.create
        @question.update(timestamp: params[:timestamp],question_type: params[:select])
      end
    else 
      @question = @survey.questions.find(params[:question_id])
      @question.update(question_type: params[:select])
    end
  end

  def remove_question
    if params[:timestamp]
      @question = @survey.questions.find_by(timestamp: params[:timestamp])
      @question.destroy
    else 
      @question = @survey.questions.find(params[:question_id])
      @question.destroy
    end
  end

  def remove_answer
    if params[:question_id]
      @question = @survey.questions.find(params[:question_id])
      if params[:answer_id]
        answer = @question.answers.find(params[:answer_id])
        answer.destroy
      end
    end
  end

  def font_style
    @survey.update(font_style: params[:font_style])
  end
  
  private
  def find_survey
    @survey = current_user.surveys.find(params[:id])
  end

  def survey_params
    params.require(:survey).permit(
      :title,
      :description,
      :position,
      :font_style,
      :theme,
      questions_attributes: [
        :_destroy,
        :id,
        :question_type,
        :title,
        :required,
        :position,
        { answers_attributes: %i[
          _destroy
          id
          title
        ] }
      ]
    )
  end
end
